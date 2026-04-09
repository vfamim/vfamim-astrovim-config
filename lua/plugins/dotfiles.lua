return {
  -- Telescope pickers scoped to dotfiles
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      {
        "<leader>fd",
        function()
          require("telescope.builtin").find_files({
            prompt_title = "  Dotfiles",
            hidden       = true,
            follow       = true,
            search_dirs  = {
              "~/.config/nvim",
              "~/.config/fish",
              "~/dotfiles",
            },
          })
        end,
        desc = "Dotfiles: Find file",
      },
      {
        "<leader>gd",
        function()
          vim.cmd("LazyGit --git-dir=$HOME/.dotfiles --work-tree=$HOME")
        end,
        desc = "Dotfiles: LazyGit",
      },
    },
  },

  -- LazyGit integration
  {
    "kdheepak/lazygit.nvim",
    keys = {
      { "<leader>gg", "<cmd>LazyGit<CR>", desc = "Git: LazyGit" },
    },
    dependencies = { "nvim-lua/plenary.nvim" },
  },
}
