-- The session: the conversation, and where it stands.
--
-- One session, one server, one conversation. Every surface of the plugin
-- -- the chat, the quick ask, the annotations -- talks to this, so they
-- all share the same history.

local M = {}

local Session = {}
Session.__index = Session

--- A session over a client.
function M.new(client)
  local s = setmetatable({
    client = client,
    running = false,
    paused = false,
    permission = nil,
    entries = {},
    text = "",
  }, Session)

  client:on("run_start", function()
    s.running = true
    s.text = ""
  end)
  client:on("run_end", function()
    s.running = false
    s.paused = false
    s.permission = nil
  end)
  client:on("paused", function()
    s.paused = true
  end)
  client:on("permission", function(ev)
    s.permission = { name = ev.name, input = ev.input }
  end)
  client:on("text", function(ev)
    s.text = s.text .. (ev.text or "")
  end)
  client:on("line", function(ev)
    table.insert(s.entries, {
      role = ev.role or "assistant",
      style = ev.style or "plain",
      tight = ev.tight or false,
      text = ev.text or "",
    })
  end)

  return s
end

--- Runs a turn. The text is what the user said.
function Session:send(text)
  if text == nil or text == "" then
    return
  end
  self.running = true
  self.text = ""
  self.client:send("send", { text = text })
end

--- Guides the turn that is running. When nothing is running, it starts
--- one.
function Session:steer(text)
  if text == nil or text == "" then
    return
  end
  self.client:send("steer", { text = text })
end

--- Answers an approval.
function Session:answer(allow, always)
  self.permission = nil
  self.client:send("answer", { allow = allow, always = always or false })
end

--- Stops the run.
function Session:cancel()
  self.client:send("cancel", {})
end

--- The answer of the turn that is running, so far.
function Session:answer_text()
  return self.text
end

--- The transcript, newest last.
function Session:history()
  return self.entries
end

return M
