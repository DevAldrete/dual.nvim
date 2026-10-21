-- The server: how the plugin runs xia.
--
-- The plugin owns the process, so it owns its configuration too. The
-- environment the server gets is the user's, plus one file: the plugin's
-- own xia configuration, which keeps the shell away from the model.

local M = {}

--- The command that starts the server.
function M.command(cfg)
  local cmd = { cfg.server.cmd }
  for _, a in ipairs(cfg.server.args or {}) do
    table.insert(cmd, a)
  end
  if cfg.server.model ~= nil and cfg.server.model ~= "" then
    table.insert(cmd, "-m")
    table.insert(cmd, cfg.server.model)
  end
  return cmd
end

--- The xia configuration the plugin wants: no shell.
--
-- The agent's shell runs on the disk, while the file tools work on the
-- buffers. A shell that writes to the disk changes files the user never
-- accepted, so it stays away from the model unless the user says so.
function M.init_script(cfg)
  if cfg.allow_shell then
    return nil
  end
  return table.concat({
    "-- Written by dual.nvim.",
    "-- The shell sees the disk; the file tools see the buffers.",
    '-- A shell that writes to the disk changes files nobody accepted.',
    'xia.hide_tool("bash")',
    "",
  }, "\n")
end

--- The environment of the server: the user's, plus the plugin's own
--- configuration of it.
function M.environment(cfg, files)
  local env = {}
  for k, v in pairs(vim.fn.environ()) do
    env[k] = v
  end
  for k, v in pairs(cfg.server.env or {}) do
    env[k] = v
  end

  local script = M.init_script(cfg)
  if script ~= nil then
    local path = vim.fn.tempname() .. ".lua"
    local f = io.open(path, "w")
    if f ~= nil then
      f:write(script)
      f:close()
      table.insert(files or {}, path)
      env["XIA_INIT"] = path
    end
  end
  return env
end

--- The working directory of the server: the project root.
function M.cwd(cfg)
  if cfg.server.cwd ~= nil and cfg.server.cwd ~= "" then
    return cfg.server.cwd
  end
  return vim.fn.getcwd()
end

return M
