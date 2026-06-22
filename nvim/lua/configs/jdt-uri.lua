-- Handle jdt:// URIs returned by jdtls for go-to-definition on external
-- library classes (JDK types, Maven/Gradle dependencies, etc.).
--
-- jdtls signals support via initializationOptions.extendedClientCapabilities
-- .classFileContentsSupport = true. The client must then resolve jdt://
-- URIs by sending a custom `java/classFileContents` request and rendering
-- the returned source into the buffer.
--
-- The decompiled source is also written to disk under
-- stdpath('cache')/jdt-sources/<library>/<package as dirs>/<Class>.java so
-- nvim-tree can show the surrounding library, similar to GOMODCACHE
-- browsing for Go modules.

local M = {}

M.cache_root = vim.fn.stdpath "cache" .. "/jdt-sources"
vim.fn.mkdir(M.cache_root, "p")

-- ---------------------------------------------------------------------------
-- URI parsing
-- ---------------------------------------------------------------------------

--- Parse a jdt:// URI into { library, package, class_name }.
--- Examples:
---   jdt://contents/java.base/java.lang/String.class?=...
---     -> { library = "java.base", package = "java.lang", class_name = "String" }
---   jdt://contents/spring-core/org.springframework.core/Ordered.class?=...
---     -> { library = "spring-core", package = "org.springframework.core",
---          class_name = "Ordered" }
function M.parse_uri(uri)
  if type(uri) ~= "string" or not uri:match "^jdt://" then
    return nil
  end
  local without_query = uri:gsub("%?.*$", "")
  local rest = without_query:match "^jdt://contents/(.+)$"
  if not rest then
    return nil
  end
  local library, pkg, class_with_ext = rest:match "^([^/]+)/([^/]*)/([^/]+)$"
  if not (library and class_with_ext) then
    return nil
  end
  local class_name = class_with_ext:gsub("%.class$", "")
  return {
    library = library,
    package = pkg or "",
    class_name = class_name,
  }
end

function M.cache_path_for_uri(uri)
  local parts = M.parse_uri(uri)
  if not parts then
    return nil
  end
  local pkg_path = ""
  if parts.package ~= "" then
    pkg_path = parts.package:gsub("%.", "/") .. "/"
  end
  return string.format("%s/%s/%s%s.java", M.cache_root, parts.library, pkg_path, parts.class_name)
end

function M.library_dir_for_uri(uri)
  local parts = M.parse_uri(uri)
  if not parts then
    return nil
  end
  return M.cache_root .. "/" .. parts.library
end

function M.is_cache_path(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  local abs = vim.fn.fnamemodify(path, ":p")
  return abs:sub(1, #M.cache_root) == M.cache_root
end

function M.library_dir_for_path(path)
  if not M.is_cache_path(path) then
    return nil
  end
  local abs = vim.fn.fnamemodify(path, ":p")
  local rel = abs:sub(#M.cache_root + 2)
  local lib = rel:match "^([^/]+)"
  if not lib then
    return nil
  end
  return M.cache_root .. "/" .. lib
end

-- ---------------------------------------------------------------------------
-- Package population (sibling files)
-- ---------------------------------------------------------------------------

local function jdk_src_zip()
  local candidates = {}
  local java_home = os.getenv "JAVA_HOME"
  if java_home and java_home ~= "" then
    table.insert(candidates, java_home .. "/lib/src.zip")
  end
  -- Resolve `java` symlink -> JDK home
  if vim.fn.executable "java" == 1 then
    local java_path = vim.fn.exepath "java"
    if java_path ~= "" then
      local resolved = vim.fn.systemlist { "readlink", "-f", java_path }
      if resolved[1] and resolved[1] ~= "" then
        local jdk = vim.fn.fnamemodify(resolved[1], ":h:h")
        table.insert(candidates, jdk .. "/lib/src.zip")
      end
    end
  end
  -- Common Linux JVM locations
  for _, p in ipairs(vim.fn.glob("/usr/lib/jvm/*/lib/src.zip", true, true)) do
    table.insert(candidates, p)
  end
  for _, p in ipairs(candidates) do
    if vim.fn.filereadable(p) == 1 then
      return p
    end
  end
  return nil
end

-- Cache: library name -> { binary = path, sources = path }
local jar_search_cache = {}

local function find_library_jars(library)
  if jar_search_cache[library] ~= nil then
    return jar_search_cache[library]
  end
  local result = {}
  local base = library:gsub("%.jar$", "")
  local roots = {
    vim.fn.expand "~/.m2/repository",
    vim.fn.expand "~/.gradle/caches/modules-2/files-2.1",
  }
  for _, root in ipairs(roots) do
    if vim.fn.isdirectory(root) == 1 then
      local cmd = {
        "find",
        root,
        "-type",
        "f",
        "(",
        "-name",
        base .. ".jar",
        "-o",
        "-name",
        base .. "-sources.jar",
        ")",
      }
      local out = vim.fn.systemlist(cmd)
      if vim.v.shell_error == 0 then
        for _, line in ipairs(out) do
          if line:match "%-sources%.jar$" then
            result.sources = result.sources or line
          else
            result.binary = result.binary or line
          end
        end
      end
    end
  end
  jar_search_cache[library] = result
  return result
end

local function zip_has_prefix(zip, prefix)
  local out = vim.fn.systemlist { "unzip", "-l", zip, prefix .. "/*" }
  if vim.v.shell_error ~= 0 then
    return false
  end
  for _, line in ipairs(out) do
    if line:match(prefix:gsub("([%-%.%+%(%)%[%]%?%*])", "%%%1")) then
      return true
    end
  end
  return false
end

local function async(cmd, on_exit)
  if type(vim.system) == "function" then
    vim.system(cmd, { text = true }, function(res)
      vim.schedule(function()
        on_exit(res.code == 0)
      end)
    end)
  else
    vim.fn.jobstart(cmd, {
      on_exit = function(_, code)
        on_exit(code == 0)
      end,
    })
  end
end

local function notify_populated(library, package_path)
  vim.schedule(function()
    pcall(vim.api.nvim_exec_autocmds, "User", {
      pattern = "JdtPackagePopulated",
      data = { library = library, package = package_path },
    })
  end)
end

-- In-flight markers so concurrent gd's don't all race to populate the same dir.
local in_flight = {}

--- Populate sibling files of the same package on disk (async, idempotent).
function M.populate_package(uri)
  local parts = M.parse_uri(uri)
  if not parts or parts.package == "" then
    return
  end
  local cache_file = M.cache_path_for_uri(uri)
  if not cache_file then
    return
  end
  local dest_dir = vim.fn.fnamemodify(cache_file, ":h")
  local marker = dest_dir .. "/.populated"
  if vim.fn.filereadable(marker) == 1 or in_flight[dest_dir] then
    return
  end
  in_flight[dest_dir] = true
  vim.fn.mkdir(dest_dir, "p")

  local pkg_path = parts.package:gsub("%.", "/")

  local function finish(ok)
    in_flight[dest_dir] = nil
    if ok then
      pcall(vim.fn.writefile, { "" }, marker)
      notify_populated(parts.library, pkg_path)
    end
  end

  -- 1. JDK modules: extract from src.zip
  if not parts.library:match "%.jar$" then
    local src_zip = jdk_src_zip()
    if src_zip then
      local prefix = parts.library .. "/" .. pkg_path
      if zip_has_prefix(src_zip, prefix) then
        async({ "unzip", "-j", "-o", "-q", src_zip, prefix .. "/*.java", "-d", dest_dir }, finish)
        return
      end
    end
  end

  -- 2. Library: look for a sources jar in Maven/Gradle caches
  local jars = find_library_jars(parts.library)
  if jars.sources then
    async({ "unzip", "-j", "-o", "-q", jars.sources, pkg_path .. "/*.java", "-d", dest_dir }, finish)
    return
  end

  -- 3. Fallback: decompile sibling .class files from the binary jar
  if jars.binary and vim.fn.executable "vineflower" == 1 then
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    async({ "unzip", "-j", "-o", "-q", jars.binary, pkg_path .. "/*.class", "-d", tmp }, function(ok)
      if not ok then
        vim.fn.delete(tmp, "rf")
        finish(false)
        return
      end
      async({ "vineflower", "--silent", tmp, dest_dir }, function(ok2)
        vim.fn.delete(tmp, "rf")
        finish(ok2)
      end)
    end)
    return
  end

  in_flight[dest_dir] = nil
end

-- ---------------------------------------------------------------------------
-- LSP plumbing
-- ---------------------------------------------------------------------------

local function find_jdtls_client(bufnr)
  local clients = vim.lsp.get_clients { name = "jdtls", bufnr = bufnr }
  if #clients > 0 then
    return clients[1]
  end
  -- Fallback: any active jdtls client (the buffer may not be attached yet).
  clients = vim.lsp.get_clients { name = "jdtls" }
  return clients[1]
end

local function attach_client_if_needed(client, bufnr)
  if not client then
    return
  end
  local attached = false
  for _, buf in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
    if buf == bufnr then
      attached = true
      break
    end
  end
  if not attached then
    pcall(vim.lsp.buf_attach_client, bufnr, client.id)
  end
end

local function set_buf_content(bufnr, content)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false
  local normalized = (content or ""):gsub("\r\n", "\n")
  local lines = vim.split(normalized, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "java"
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].modified = false
end

local function write_cache(uri, content)
  local cache_path = M.cache_path_for_uri(uri)
  if not cache_path or type(content) ~= "string" or content == "" then
    return nil
  end
  local dir = vim.fn.fnamemodify(cache_path, ":h")
  vim.fn.mkdir(dir, "p")
  local lines = vim.split(content:gsub("\r\n", "\n"), "\n", { plain = true })
  local ok = pcall(vim.fn.writefile, lines, cache_path)
  if not ok then
    return nil
  end
  return cache_path
end

--- Resolve a jdt:// URI by asking jdtls for its decompiled source and
--- writing the result into `bufnr`. Blocks until the response arrives (or
--- a short timeout fires) so the LSP can place the cursor on the correct
--- line *after* the buffer has content. Also mirrors the source to a
--- stable on-disk cache for nvim-tree integration.
function M.open(bufnr, uri)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  -- Wait up to 30s for a jdtls client to come up (initial indexing can be slow).
  local client = find_jdtls_client(bufnr)
  if not client then
    vim.wait(30000, function()
      client = find_jdtls_client(bufnr)
      return client ~= nil
    end, 200)
  end
  if not client then
    set_buf_content(bufnr, "// jdtls client not available; cannot resolve " .. uri)
    return
  end
  attach_client_if_needed(client, bufnr)

  local done = false
  local function handler(err, result)
    done = true
    if err or not result or result == "" then
      local msg = err and err.message or "no content returned"
      set_buf_content(bufnr, "// failed to resolve " .. uri .. ": " .. msg)
      return
    end
    set_buf_content(bufnr, result)
    write_cache(uri, result)
  end

  -- Newer vim.lsp.Client exposes :request; older API exposes vim.lsp.buf_request.
  local sent = false
  if type(client.request) == "function" then
    sent = pcall(function()
      client:request("java/classFileContents", { uri = uri }, handler, bufnr)
    end)
  end
  if not sent then
    sent = pcall(vim.lsp.buf_request, bufnr, "java/classFileContents", { uri = uri }, handler)
  end
  if not sent then
    set_buf_content(bufnr, "// failed to send java/classFileContents for " .. uri)
    return
  end

  -- Block the BufReadCmd until content lands. Without this, vim.lsp positions
  -- the cursor on an empty buffer and gets clamped to line 1.
  vim.wait(10000, function()
    return done
  end, 10)

  -- Kick off async population of sibling files in the same package so the
  -- nvim-tree view of an external library looks like a real source folder.
  M.populate_package(uri)
end

local did_setup = false

function M.setup()
  if did_setup then
    return
  end
  did_setup = true

  local group = vim.api.nvim_create_augroup("JdtUri", { clear = true })

  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = { "jdt://*" },
    callback = function(args)
      local uri = args.match or vim.api.nvim_buf_get_name(args.buf)
      M.open(args.buf, uri)
    end,
  })

  -- Mark on-disk cache files read-only when opened directly (e.g. via
  -- nvim-tree). They mirror jdtls output; editing them has no effect.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    pattern = M.cache_root .. "/*",
    callback = function(args)
      if not vim.api.nvim_buf_is_valid(args.buf) then
        return
      end
      vim.bo[args.buf].readonly = true
      vim.bo[args.buf].modifiable = false
    end,
  })
end

return M
