-- The transport: the way the plugin reaches the server.
--
-- A transport is three things and no more: it starts, it writes a line,
-- and it stops. Everything above it -- the client, the session, the
-- windows -- knows nothing about processes.
--
-- The one here runs `xia --serve` and speaks JSON lines over its standard
-- input and output. Another one (a socket, a library) would be the same
-- three things.

local M = {}

local Transport = {}
Transport.__index = Transport

--- Starts the server.
-- @param opts table: cmd, args, cwd, env
-- @param on_line function: called with every line the server writes
-- @param on_exit function: called with the exit code when the server ends
function M.new(opts)
  return setmetatable({
    cmd = opts.cmd,
    args = opts.args or {},
    cwd = opts.cwd,
    env = opts.env,
    on_line = opts.on_line,
    on_exit = opts.on_exit,
    buffer = "",
    running = false,
  }, Transport)
end

--- Starts the process.
function Transport:start()
  if self.running then
    return true
  end
  local cmd = { self.cmd }
  for _, a in ipairs(self.args) do
    table.insert(cmd, a)
  end

  local ok, err = pcall(function()
    self.proc = vim.system(cmd, {
      text = true,
      stdin = true,
      cwd = self.cwd,
      env = self.env,
      stdout = function(_, data)
        if data then
          -- The line arrives in a fast event context, where the editor
          -- may not be touched. The main loop does that.
          vim.schedule(function()
            self:feed(data)
          end)
        end
      end,
      stderr = function(_, data)
        if data and data ~= "" then
          self:on_stderr(data)
        end
      end,
    }, function(obj)
      self.running = false
      if self.on_exit then
        self.on_exit(obj.code, obj.signal)
      end
    end)
  end)
  if not ok then
    self.error = err
    return false
  end
  self.running = true
  return true
end

--- The lines the server wrote, one at a time.
function Transport:feed(data)
  self.buffer = self.buffer .. data
  while true do
    local at = self.buffer:find("\n", 1, true)
    if not at then
      break
    end
    local line = self.buffer:sub(1, at - 1)
    self.buffer = self.buffer:sub(at + 1)
    line = line:gsub("\r$", "")
    if line ~= "" and self.on_line then
      self.on_line(line)
    end
  end
end

--- The diagnostics of the server. They are the server's own business, and
-- the user sees them only when something went wrong.
function Transport:on_stderr(data)
  self.stderr = (self.stderr or "") .. data
  if self.on_error then
    self.on_error(data)
  end
end

--- Writes a line to the server.
function Transport:write(line)
  if not self.proc then
    return false
  end
  local ok = pcall(function()
    self.proc:write(line .. "\n")
  end)
  return ok
end

--- Stops the server.
function Transport:stop()
  if not self.proc then
    return
  end
  pcall(function()
    -- Closing the input tells the server the client is gone.
    self.proc:write(nil)
  end)
  pcall(function()
    self.proc:kill(15)
  end)
  self.running = false
end

return M
