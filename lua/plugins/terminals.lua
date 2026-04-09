local ipython_profiles = { "default", "databricks" }
local ipython_profile = "default"
local databricks_cluster_id = nil   -- nil = ainda não selecionado

local SHELL_ID   = 1
local IPYTHON_ID = 7
local CLAUDE_ID  = 8

local function ipython_cmd()
  local function has_file(name)
    local path = vim.fn.getcwd()
    while path ~= "/" do
      if vim.fn.filereadable(path .. "/" .. name) == 1 then return true end
      path = vim.fn.fnamemodify(path, ":h")
    end
  end
  local flag = ipython_profile ~= "default" and (" --profile=" .. ipython_profile) or ""
  if has_file("uv.lock")     then return "uv run ipython" .. flag end
  if has_file("poetry.lock") then return "poetry run ipython" .. flag end
  return "ipython" .. flag
end

local function shutdown_ipython()
  local t = require("toggleterm.terminal").get(IPYTHON_ID)
  if t then t:shutdown() end
end

-- Busca clusters via databricks CLI e exibe picker.
-- callback(cluster_id) é chamado com o ID selecionado (ou nil se cancelado).
local function pick_cluster(callback)
  vim.notify("Buscando clusters Databricks...", vim.log.levels.INFO)
  vim.system(
    { "databricks", "clusters", "list", "--output", "json" },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 or not result.stdout or result.stdout == "" then
          vim.notify("Erro ao listar clusters: " .. (result.stderr or ""), vim.log.levels.ERROR)
          callback(nil)
          return
        end
        local ok, clusters = pcall(vim.json.decode, result.stdout)
        if not ok or type(clusters) ~= "table" then
          vim.notify("Resposta inesperada do CLI Databricks", vim.log.levels.ERROR)
          callback(nil)
          return
        end
        -- Filtra apenas clusters que estão RUNNING
        local running = vim.tbl_filter(function(c)
          return c.state == "RUNNING" or c.state == "RESIZING"
        end, clusters)
        if #running == 0 then
          vim.notify("Nenhum cluster ativo encontrado", vim.log.levels.WARN)
          callback(nil)
          return
        end
        vim.ui.select(running, {
          prompt = "Selecione o cluster Databricks:",
          format_item = function(c)
            return string.format("[%s] %s", c.state, c.cluster_name or c.cluster_id)
          end,
        }, function(choice)
          callback(choice and choice.cluster_id or nil)
        end)
      end)
    end
  )
end

-- Fecha todos os terminais gerenciados exceto `except_id`.
local function close_others(except_id)
  local terms = require("toggleterm.terminal")
  for _, id in ipairs({ SHELL_ID, IPYTHON_ID, CLAUDE_ID }) do
    if id ~= except_id then
      local t = terms.get(id)
      if t and t:is_open() then t:close() end
    end
  end
end

local function toggle_shell()
  local terms = require("toggleterm.terminal")
  close_others(SHELL_ID)
  local t = terms.get(SHELL_ID) or terms.Terminal:new({
    id            = SHELL_ID,
    direction     = "horizontal",
    close_on_exit = false,
    dir           = "git_dir",
  })
  t:toggle()
end

-- Busca terminal pelo ID no registro do toggleterm; cria se não existir.
local function open_ipython()
  local terms = require("toggleterm.terminal")
  local env = {}
  if ipython_profile == "databricks" and databricks_cluster_id then
    env.DATABRICKS_CLUSTER_ID = databricks_cluster_id
  end
  close_others(IPYTHON_ID)
  local t = terms.get(IPYTHON_ID) or terms.Terminal:new({
    id            = IPYTHON_ID,
    cmd           = ipython_cmd(),
    direction     = "horizontal",
    close_on_exit = false,
    dir           = "git_or_cwd",
    env           = next(env) and env or nil,
  })
  t:toggle()
end

local function toggle_ipython()
  -- Perfil databricks sem cluster: pede seleção antes de abrir
  if ipython_profile == "databricks" and not databricks_cluster_id then
    pick_cluster(function(cluster_id)
      if not cluster_id then return end
      databricks_cluster_id = cluster_id
      open_ipython()
    end)
  else
    open_ipython()
  end
end

local function toggle_claude()
  local terms = require("toggleterm.terminal")
  close_others(CLAUDE_ID)
  local t = terms.get(CLAUDE_ID) or terms.Terminal:new({
    id = CLAUDE_ID, cmd = "claude", direction = "horizontal", close_on_exit = false, dir = "git_dir",
  })
  t:toggle()
end

local function select_ipython_profile()
  vim.ui.select(ipython_profiles, { prompt = "IPython profile:" }, function(choice)
    if not choice then return end
    ipython_profile = choice
    databricks_cluster_id = nil  -- limpa cluster ao trocar perfil
    shutdown_ipython()
    vim.notify("IPython profile: " .. choice, vim.log.levels.INFO)
  end)
end

-- Permite trocar o cluster sem mudar o perfil
local function select_cluster()
  pick_cluster(function(cluster_id)
    if not cluster_id then return end
    databricks_cluster_id = cluster_id
    shutdown_ipython()
    vim.notify("Cluster selecionado: " .. cluster_id, vim.log.levels.INFO)
  end)
end

return {
  {
    "akinsho/toggleterm.nvim",
    keys = {
      { "<F7>",  toggle_shell, mode = { "n", "t" }, desc = "Terminal: shell abaixo" },
      { "<F8>",  toggle_ipython, mode = { "n", "t" }, desc = "Terminal: IPython" },
      { "<F12>", toggle_claude,  mode = { "n", "t" }, desc = "Terminal: Claude Code" },

      { "<leader>tp", select_ipython_profile, mode = "n", desc = "Terminal: IPython profile" },
      { "<leader>tc", select_cluster,         mode = "n", desc = "Terminal: selecionar cluster Databricks" },

      -- <leader>is: enviar seleção visual ao IPython
      { "<leader>is",
        function()
          local terms = require("toggleterm.terminal")
          local t = terms.get(IPYTHON_ID) or terms.Terminal:new({
            id = IPYTHON_ID, cmd = ipython_cmd(), direction = "horizontal", close_on_exit = false, dir = "git_dir",
          })
          if not t:is_open() then t:open() end
          vim.cmd("ToggleTermSendVisualLines " .. IPYTHON_ID)
        end,
        mode = "v", desc = "IPython: enviar seleção" },

      -- <leader>ir: rodar arquivo completo no IPython via %run
      { "<leader>ir",
        function()
          local file = vim.fn.expand("%:p")
          if file == "" then vim.notify("Salve o arquivo primeiro", vim.log.levels.WARN) return end
          local terms = require("toggleterm.terminal")
          local t = terms.get(IPYTHON_ID) or terms.Terminal:new({
            id = IPYTHON_ID, cmd = ipython_cmd(), direction = "horizontal", close_on_exit = false, dir = "git_dir",
          })
          if not t:is_open() then t:open() end
          t:send("%run " .. file)
        end,
        mode = "n", desc = "IPython: rodar arquivo" },
    },
  },
}
