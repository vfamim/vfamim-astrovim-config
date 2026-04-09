-- Patch para Neovim 0.12+: TSNode:start() e :end_() foram removidos.
-- aerial.nvim ainda usa a API antiga. O patch substitui range_from_nodes
-- por uma versão que usa TSNode:range() (compatível com todas as versões).
-- Pode ser removido quando aerial.nvim corrigir upstream.
return {
  {
    "stevearc/aerial.nvim",
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyDone",
        once = true,
        callback = function()
          local ok, helpers = pcall(require, "aerial.backends.treesitter.helpers")
          if not ok then return end
          helpers.range_from_nodes = function(start_node, end_node)
            local row, col = start_node:range()
            local _, _, end_row, end_col = end_node:range()
            return { lnum = row + 1, end_lnum = end_row + 1, col = col, end_col = end_col }
          end
        end,
      })
    end,
  },
}
