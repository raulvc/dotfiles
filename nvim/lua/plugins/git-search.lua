return {
    {
        "aaronhallaert/advanced-git-search.nvim",
        cmd = { "AdvancedGitSearch" },
        config = function()
            require("telescope").load_extension "advanced_git_search"
        end,
        dependencies = {
            --- See dependencies
            {
                "nvim-telescope/telescope.nvim",
                -- to show diff splits and open commits in browser
                "tpope/vim-fugitive",
                -- to open commits in browser with fugitive
                "tpope/vim-rhubarb",
                -- optional: to replace the diff from fugitive with diffview.nvim
                -- (fugitive is still needed to open in browser)
                -- "sindrets/diffview.nvim",
            },
        },
    },
}
