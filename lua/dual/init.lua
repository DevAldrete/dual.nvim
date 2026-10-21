-- dual.nvim: the Neovim front-end of xia.
--
-- The plugin owns the editor experience: the chat, the quick ask, the
-- buffers, the diffs. It owns no provider and no agent loop: those are
-- the runtime's business, and the plugin talks to it over the serve
-- protocol.

local M = {}

M.config = require("dual.config")
M.client = require("dual.client")
M.server = require("dual.server")
M.session = require("dual.session")
M.transport = require("dual.transport.stdio")

-- The state of the plugin: the client, the session, and the files the
-- server was started with.
M.state = {
  client = nil,
  session = nil,
  transport = nil,
  files = {},
  starting = false,
}

--- Sets the plugin up.
-- @param opts table: the configuration; see dual.config
function M.setup(opts)
  local cfg = M.config.setup(opts)
  M.state.cfg = cfg

  M.setup_commands(cfg)
  M.setup_keymaps(cfg)
  return M
end

--- The commands of the plugin.
function M.setup_commands(cfg)
  local commands = cfg.commands or {}
  if commands.health ~= nil then
    vim.api.nvim_create_user_command(commands.health, function()
      require("dual.health").report()
    end, { desc = "Check that the agent is there" })
  end
end

--- The keymaps of the plugin. An empty key means no keymap.
function M.setup_keymaps(cfg)
  local keys = cfg.keys or {}
  local actions = {
    chat = function()
      require("dual.ui.chat").toggle()
    end,
    ask = function()
      require("dual.ops.ask").run()
    end,
    change = function()
      require("dual.ops.change").run()
    end,
    insert = function()
      require("dual.ops.insert").run()
    end,
    cancel = function()
      require("dual").cancel()
    end,
    steer = function()
      require("dual.ops.steer").run()
    end,
  }
  for name, fn in pairs(actions) do
    local key = keys[name]
    if key ~= nil and key ~= "" then
      vim.keymap.set("n", key, fn, { desc = "dual: " .. name })
    end
  end
end

--- Starts the server, if it is not running yet.
-- @param on_ready function: called with the session when it is ready
function M.start(on_ready)
  local st = M.state
  if st.client ~= nil and st.client.ready then
    if on_ready then
      on_ready(st.session)
    end
    return true
  end
  if st.starting then
    return false
  end
  st.starting = true

  local cfg = st.cfg or M.config.values
  local transport = M.transport.new({
    cmd = cfg.server.cmd,
    args = cfg.server.args,
    cwd = M.server.cwd(cfg),
    env = M.server.environment(cfg, st.files),
  })
  st.transport = transport

  local client = M.client.new({ transport = transport })
  st.client = client

  client:start(function(c)
    st.starting = false
    st.session = M.session.new(c)
    if on_ready then
      on_ready(st.session)
    end
  end, function(err)
    st.starting = false
    M.notify("dual: " .. tostring(err), vim.log.levels.ERROR)
  end)
  return true
end

--- Runs a turn.
function M.send(text, on_ready)
  M.start(function(session)
    session:send(text)
    if on_ready then
      on_ready(session)
    end
  end)
end

--- Guides the turn that is running.
function M.steer(text)
  if M.state.session == nil then
    return
  end
  M.state.session:steer(text)
end

--- Stops the run.
function M.cancel()
  if M.state.session == nil then
    return
  end
  M.state.session:cancel()
end

--- Stops the server.
function M.stop()
  if M.state.client ~= nil then
    M.state.client:stop()
  end
  M.state.client = nil
  M.state.session = nil
  M.state.transport = nil
end

--- Says something in the chat.
function M.notify(text, level)
  vim.notify(text, level or vim.log.levels.INFO, { title = "dual" })
end

return M
