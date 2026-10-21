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
-- buffers. The server fences the shell in — the project is read-only
-- for it — so the shell may be offered, as long as the platform can
-- fence it in at all.
--
-- The plugin's own file runs the user's own configuration first: the
-- plugin adds to what the user configured, it does not replace it.
--
-- @param cfg table: the configuration
-- @return string|nil: the script, or nil when there is nothing to say
function M.init_script(cfg)
  local allow = cfg.allow_shell
  if allow == true then
    -- The user says the shell is fine: there is nothing to write, and
    -- the user's own configuration is left alone.
    return nil
  end

  local lines = {}
  local user_init = vim.env.XIA_INIT
  if user_init ~= nil and user_init ~= "" then
    lines[#lines + 1] = "-- The user's own configuration runs first."
    lines[#lines + 1] = ("local f = io.open(%q, 'r')"):format(user_init)
    lines[#lines + 1] = "if f then"
    lines[#lines + 1] = "  f:close()"
    lines[#lines + 1] = ("  dofile(%q)"):format(user_init)
    lines[#lines + 1] = "end"
    lines[#lines + 1] = ""
  end

  lines[#lines + 1] = "-- Written by dual.nvim."
  lines[#lines + 1] = "-- The shell writes to the disk; the file tools work on the buffers."
  if allow == false then
    lines[#lines + 1] = "-- The user asked for no shell."
    lines[#lines + 1] = 'xia.hide_tool("bash")'
  else
    lines[#lines + 1] = "-- The shell is only offered when the platform can fence it in."
    lines[#lines + 1] = 'if xia.sandbox() == "none" then'
    lines[#lines + 1] = '  xia.hide_tool("bash")'
    lines[#lines + 1] = "end"
  end
  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
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
