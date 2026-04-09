return {
  "toggleterm.nvim",
  version = "*",
  opts = {
    direction = "horizontal",
    dir = "git_dir",
    size = function(term)
      if term.direction == "horizontal" then return 15  -- linhas de altura
      elseif term.direction == "vertical" then return math.floor(vim.o.columns * 0.4)
      end
    end,
  },
}
