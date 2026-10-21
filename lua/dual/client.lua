-- The client: the protocol, from this side.
--
-- It writes requests, matches the replies to them, and hands the events
-- to whoever is listening. It knows nothing about the editor.

local M = {}

local Client = {}
Client.__index = Client

--- A new client over a transport.
-- @param opts table: transport
function M.new(opts)
  return setmetatable({
    transport = opts.transport,
    pending = {},
    handlers = {},
    next_id = 0,
    ready = false,
    version = "",
    model = "",
    session = "",
    capabilities = {},
    -- What the shell is fenced with: "seatbelt", "landlock", or "none".
    sandbox = "none",
  }, Client)
end

--- Starts the server and waits for the greeting.
-- @param on_ready function: called with the client when it is ready
-- @param on_error function: called when the server cannot be reached
function Client:start(on_ready, on_error)
  self.transport.on_line = function(line)
    self:on_line(line)
  end
  self.transport.on_exit = function(code, signal)
    self.ready = false
    if self.on_exit then
      self.on_exit(code, signal)
    end
  end

  local started = self.transport:start()
  if not started then
    if on_error then
      on_error(self.transport.error or "the server did not start")
    end
    return false
  end

  self.on_ready = on_ready
  self.on_error = on_error
  return true
end

--- A line of the protocol.
function Client:on_line(line)
  local ok, msg = pcall(vim.json.decode, line)
  if not ok or type(msg) ~= "table" then
    return
  end

  if msg.event ~= nil then
    if msg.event == "hello" then
      self:on_hello(msg)
    end
    self:dispatch(msg.event, msg)
    return
  end

  local cb = self.pending[msg.id]
  if cb ~= nil then
    self.pending[msg.id] = nil
    cb(msg)
  end
end

--- The greeting: what the server is, and what it may be asked.
function Client:on_hello(msg)
  self.ready = true
  self.version = msg.version or ""
  self.model = msg.model or ""
  self.session = msg.session or ""
  self.capabilities = msg.capabilities or {}
  self.sandbox = msg.sandbox or "none"
  if self.on_ready then
    self.on_ready(self)
  end
end

--- True when the server understands the command.
function Client:has(command)
  for _, c in ipairs(self.capabilities) do
    if c == command then
      return true
    end
  end
  return false
end

--- Sends a request. The callback is called with the reply.
-- @param cmd string: the command
-- @param fields table: what the command needs
-- @param cb function: called with the reply
function Client:request(cmd, fields, cb)
  self.next_id = self.next_id + 1
  local id = self.next_id
  local msg = { id = id, cmd = cmd }
  for k, v in pairs(fields or {}) do
    msg[k] = v
  end
  if cb ~= nil then
    self.pending[id] = cb
  end
  self.transport:write(vim.json.encode(msg))
  return id
end

--- Sends a request and forgets the answer.
function Client:send(cmd, fields)
  return self:request(cmd, fields, nil)
end

--- Listens for an event. The name "*" hears everything.
function Client:on(event, fn)
  if self.handlers[event] == nil then
    self.handlers[event] = {}
  end
  table.insert(self.handlers[event], fn)
  return fn
end

--- Hands an event to the listeners.
function Client:dispatch(event, msg)
  for _, fn in ipairs(self.handlers[event] or {}) do
    pcall(fn, msg)
  end
  for _, fn in ipairs(self.handlers["*"] or {}) do
    pcall(fn, msg)
  end
end

--- Stops the server.
function Client:stop()
  self.ready = false
  if self.transport then
    self.transport:stop()
  end
end

return M
