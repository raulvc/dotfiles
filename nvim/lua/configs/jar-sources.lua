-- Browse and decompile JVM jar contents (used for kotlin_lsp / jdtls external
-- sources that return jar://... URIs pointing at .class entries).
--
-- Strategy:
--   * Extract the whole jar once into stdpath('cache')/jar-sources/<name>-<hash>/
--   * Decompile individual .class files on demand with Vineflower
--   * Cache the produced .java next to the .class for subsequent opens

local M = {}

M.cache_root = vim.fn.stdpath "cache" .. "/jar-sources"
vim.fn.mkdir(M.cache_root, "p")

local function jar_cache_dir(jar_path)
  local hash = vim.fn.sha256(jar_path):sub(1, 16)
  local name = vim.fn.fnamemodify(jar_path, ":t:r")
  return M.cache_root .. "/" .. name .. "-" .. hash
end

--- Parse a jar:///abs/path.jar!/inner/path.class URI.
function M.parse_uri(uri)
  if type(uri) ~= "string" then
    return nil, nil
  end
  local path = uri:gsub("^jar://", "")
  local jar, inner = path:match "^(.-)!/(.+)$"
  return jar, inner
end

--- Extract the whole jar into a stable cache directory (idempotent).
function M.ensure_extracted(jar_path)
  if vim.fn.filereadable(jar_path) == 0 then
    return nil, "jar not readable: " .. jar_path
  end
  local dir = jar_cache_dir(jar_path)
  local marker = dir .. "/.extracted"
  if vim.fn.filereadable(marker) == 1 then
    return dir
  end
  vim.fn.mkdir(dir, "p")
  local out = vim.fn.system { "unzip", "-o", "-q", jar_path, "-d", dir }
  if vim.v.shell_error ~= 0 then
    return nil, "unzip failed: " .. out
  end
  vim.fn.writefile({ "" }, marker)
  return dir
end

--- Decompile one .class file; caches the .java next to it.
function M.decompile_class(class_file)
  if vim.fn.filereadable(class_file) == 0 then
    return nil, "class file not readable: " .. class_file
  end
  local java_file = class_file:gsub("%.class$", ".java")
  if vim.fn.filereadable(java_file) == 1 then
    return vim.fn.readfile(java_file)
  end
  if vim.fn.executable "vineflower" ~= 1 then
    return nil, "vineflower not found in PATH"
  end
  local outdir = vim.fn.fnamemodify(class_file, ":h")
  local out = vim.fn.system { "vineflower", class_file, outdir }
  if vim.v.shell_error ~= 0 then
    return nil, "vineflower failed: " .. out
  end
  if vim.fn.filereadable(java_file) == 1 then
    return vim.fn.readfile(java_file)
  end
  local basename = vim.fn.fnamemodify(class_file, ":t:r")
  local candidate = outdir .. "/" .. basename .. ".java"
  if vim.fn.filereadable(candidate) == 1 then
    return vim.fn.readfile(candidate)
  end
  return nil, "no .java output produced"
end

--- Fill a buffer with decompiled Java source for a .class file.
function M.load_into_buffer(bufnr, class_file)
  local lines, err = M.decompile_class(class_file)
  if not lines then
    vim.notify(err or "unknown error", vim.log.levels.ERROR)
    return false
  end
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "java"
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].modified = false
  return true
end

--- Resolve a jar:// URI: extract the jar and return (cache_dir, class_file).
function M.open_jar_uri(uri)
  local jar, inner = M.parse_uri(uri)
  if not jar or not inner then
    return nil, nil, "invalid jar URI: " .. tostring(uri)
  end
  local dir, err = M.ensure_extracted(jar)
  if not dir then
    return nil, nil, err
  end
  return dir, dir .. "/" .. inner
end

--- Is this path inside our jar cache tree?
function M.is_cache_path(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  return path:sub(1, #M.cache_root) == M.cache_root
end

local did_setup = false

--- Register BufReadCmd autocmds for jar:// URIs and cached .class files.
function M.setup()
  if did_setup then
    return
  end
  did_setup = true

  local group = vim.api.nvim_create_augroup("JarSources", { clear = true })

  -- jar:// URI -> extract whole jar, decompile the requested entry into the buffer.
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = { "jar://*" },
    callback = function(args)
      local bufnr = args.buf
      local uri = vim.api.nvim_buf_get_name(bufnr)
      local _, class_file, err = M.open_jar_uri(uri)
      if not class_file then
        vim.notify(err or "failed to open jar URI", vim.log.levels.ERROR)
        return
      end
      M.load_into_buffer(bufnr, class_file)
      vim.bo[bufnr].buftype = "nofile"
      vim.bo[bufnr].bufhidden = "hide"
      -- Rename the buffer to the on-disk extracted path so nvim-tree's
      -- update_focused_file can highlight it. Keep buftype=nofile so it
      -- remains read-only and isn't written back.
      pcall(vim.api.nvim_buf_set_name, bufnr, class_file)
    end,
  })

  -- .class file opened directly (e.g. via nvim-tree) inside our cache dir.
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = group,
    pattern = M.cache_root .. "/*.class",
    callback = function(args)
      M.load_into_buffer(args.buf, vim.api.nvim_buf_get_name(args.buf))
    end,
  })
end

return M