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
  -- The scope of the turn that is running: the range the user pointed
  -- at, if the request was a scoped one.
  scope = nil,
}

-- The hooks: the surfaces that want to know when the session is there.
M.hooks = {
  session = {},
}

--- Runs a function when the session is ready. If it already is, the
--- function runs at once.
function M.on_session(fn)
  if M.state.session ~= nil then
    fn(M.state.session)
    return
  end
  table.insert(M.hooks.session, fn)
end

--- Tells the surfaces the session is there.
function M.announce(session)
  M.state.session = session
  require("dual.buffers").listen(session.client)
  require("dual.quickfix").listen(session.client)
  session.client:on("run_end", function()
    -- The scope was for that turn only.
    M.state.scope = nil
  end)
  for _, fn in ipairs(M.hooks.session) do
    pcall(fn, session)
  end
end

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
  if commands.chat ~= nil then
    vim.api.nvim_create_user_command(commands.chat, function()
      require("dual.ui.chat").toggle()
    end, { desc = "The chat" })
  end
  if commands.ask ~= nil then
    vim.api.nvim_create_user_command(commands.ask, function()
      require("dual.ops.ask").run()
    end, { desc = "Ask about the selection" })
  end
  if commands.change ~= nil then
    vim.api.nvim_create_user_command(commands.change, function()
      require("dual.ops.change").run()
    end, { desc = "Change the selection" })
  end
  if commands.insert ~= nil then
    vim.api.nvim_create_user_command(commands.insert, function()
      require("dual.ops.change").insert()
    end, { desc = "Insert code at the cursor" })
  end
  if commands.review ~= nil then
    vim.api.nvim_create_user_command(commands.review, function()
      local paths = require("dual.review").paths()
      if #paths == 0 then
        M.notify("dual: there is nothing to review")
        return
      end
      require("dual.ui.review").open(paths[1])
    end, { desc = "Review what the agent changed" })
  end
  if commands.model ~= nil then
    vim.api.nvim_create_user_command(commands.model, function()
      require("dual.ops.model").run()
    end, { desc = "Pick the model" })
  end
  if commands.sessions ~= nil then
    vim.api.nvim_create_user_command(commands.sessions, function()
      require("dual.ops.sessions").run()
    end, { desc = "Pick a session" })
  end
  if commands.auth ~= nil then
    vim.api.nvim_create_user_command(commands.auth, function()
      require("dual.ops.auth").run()
    end, { desc = "Set the key of a provider" })
  end
  if commands.health ~= nil then
    vim.api.nvim_create_user_command(commands.health, function()
      require("dual.health").report()
    end, { desc = "Check that the agent is there" })
  end
end

--- The keymaps of the plugin. An empty key means no keymap.
function M.setup_keymaps(cfg)
  local keys = cfg.keys or {}
  -- A surface that is not built yet says so, rather than throwing.
  local function action(module, name)
    return function()
      local ok, m = pcall(require, module)
      if not ok or type(m) ~= "table" or type(m[name]) ~= "function" then
        M.notify(("dual: %s is not here yet"):format(module),
          vim.log.levels.WARN)
        return
      end
      m[name]()
    end
  end

  local actions = {
    chat = action("dual.ui.chat", "toggle"),
    ask = action("dual.ops.ask", "run"),
    change = action("dual.ops.change", "run"),
    insert = action("dual.ops.change", "insert"),
    cancel = function()
      M.cancel()
    end,
    steer = action("dual.ops.steer", "run"),
  }
  for name, fn in pairs(actions) do
    local key = keys[name]
    if key ~= nil and key ~= "" then
      vim.keymap.set("n", key, fn, { desc = "dual: " .. name })
    end
  end

  -- The ask also works on a selection that is being made: the scope is
  -- the selection, not the last one.
  if keys.ask ~= nil and keys.ask ~= "" then
    vim.keymap.set("v", keys.ask, actions.ask, { desc = "dual: ask" })
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
    M.announce(M.session.new(c))
    if on_ready then
      on_ready(M.state.session)
    end
  end, function(err)
    st.starting = false
    M.notify("dual: " .. tostring(err), vim.log.levels.ERROR)
  end)
  return true
end

--- Runs a turn.
function M.send(text, on_ready)
  -- A mention is a path: the agent reads it itself.
  local expanded = require("dual.files").expand(text)
  M.start(function(session)
    session:send(expanded)
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
