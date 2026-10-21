-- The session: the state of the conversation.
--
-- A client that records what it is told, so the test can ask what the
-- session did without a server.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local session_mod = require("dual.session")

h.group("the session")

local function fake_client()
  local c = { sent = {}, handlers = {} }
  function c:send(cmd, fields)
    table.insert(self.sent, { cmd = cmd, fields = fields })
  end
  function c:on(event, fn)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], fn)
  end
  function c:emit(event, msg)
    for _, fn in ipairs(self.handlers[event] or {}) do
      fn(msg)
    end
  end
  return c
end

local client = fake_client()
local session = session_mod.new(client)

h.eq(false, session.running, "nothing is running at the start")
h.eq(0, #session:history(), "the transcript is empty at the start")

-- A turn.
session:send("read the build config")
h.eq(1, #client.sent, "the turn is sent")
h.eq("send", client.sent[1].cmd, "it is a send")
h.eq("read the build config", client.sent[1].fields.text, "the text is the user's")
h.eq(true, session.running, "the turn is running")

client:emit("run_end", { ok = true })
h.eq(false, session.running, "the turn is over when the run ends")

-- The answer streams in.
client:emit("text", { text = "The build " })
client:emit("text", { text = "config compiles." })
h.eq("The build config compiles.", session:answer_text(),
  "the answer is the pieces together")

-- The transcript keeps the lines.
client:emit("line", { role = "user", style = "plain", text = "read it" })
client:emit("line", { role = "assistant", style = "plain", text = "sure" })
h.eq(2, #session:history(), "the lines are kept")
h.eq("user", session:history()[1].role, "the role is kept")
h.eq("sure", session:history()[2].text, "the text is kept")

-- An approval waits.
client:emit("permission", { name = "write_file", input = '{"path":"a.c"}' })
h.ok(session.permission ~= nil, "the approval is waiting")
h.eq("write_file", session.permission.name, "the tool that wants it is known")
session:answer(true)
h.is_nil(session.permission, "the approval is answered")
h.eq("answer", client.sent[#client.sent].cmd, "the answer is sent")
h.eq(true, client.sent[#client.sent].fields.allow, "the answer allows")

-- A parked turn.
client:emit("paused", { message = "waiting for a human" })
h.eq(true, session.paused, "the turn is parked")
client:emit("run_end", { ok = true })
h.eq(false, session.paused, "the park is over when the run ends")

-- Steering and cancelling.
session:steer("do it this way")
h.eq("steer", client.sent[#client.sent].cmd, "the guidance is sent")
h.eq("do it this way", client.sent[#client.sent].fields.text, "the guidance is the text")
session:cancel()
h.eq("cancel", client.sent[#client.sent].cmd, "the run is stopped")

h.report()
