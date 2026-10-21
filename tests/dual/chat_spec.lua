-- The chat: the transcript, the input, the header.
--
-- The test drives the whole thing: the chat opens, the user types, the
-- answer comes back from a stand-in server, and the transcript is the
-- conversation.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local chat = require("dual.ui.chat")

h.group("the chat")

dual.setup({
  server = {
    cmd = "nvim",
    args = { "--headless", "-u", "NONE", "-l", "tests/dual/mock_xia.lua" },
  },
  keys = {},
})

-- The chat opens.
h.eq(false, chat.is_open(), "the chat is closed at the start")
chat.open()
h.ok(chat.is_open(), "the chat is open")
h.ok(vim.api.nvim_win_is_valid(chat.windows.header), "there is a header")
h.ok(vim.api.nvim_win_is_valid(chat.windows.transcript), "there is a transcript")
h.ok(vim.api.nvim_win_is_valid(chat.windows.input), "there is an input")
h.eq(4, #vim.api.nvim_list_wins(), "the chat is three windows beside the source")
h.eq(chat.windows.input, vim.api.nvim_get_current_win(), "the cursor is in the input")

-- The input is a buffer: what is in it is what is sent.
vim.api.nvim_buf_set_lines(chat.buffers.input, 0, -1, false, { "read the build config" })
h.eq("read the build config", chat:input_text(), "the input holds what was typed")
chat.send()

-- The transcript grows as the conversation happens.
local function transcript()
  return table.concat(vim.api.nvim_buf_get_lines(chat.buffers.transcript, 0, -1, false), "\n")
end

h.ok(h.wait_for(function()
  return dual.state.session ~= nil
end, 10000), "the server answers")
h.ok(h.wait_for(function()
  return transcript():find("read the build config", 1, true) ~= nil
end, 10000), "the user's line is in the transcript")
h.ok(h.wait_for(function()
  return transcript():find("the answer", 1, true) ~= nil
end, 10000), "the answer is in the transcript")
h.contains(transcript(), "read the build config", "the user is in the transcript")
h.contains(transcript(), "the answer", "the agent is in the transcript")

-- The input is emptied when it is sent.
h.eq("", chat:input_text(), "the input is empty after sending")

-- The chat closes, and the session is not lost.
local session = dual.state.session
chat.close()
h.eq(false, chat.is_open(), "the chat is closed")
h.eq(session, dual.state.session, "the session is still there")
chat.open()
h.ok(chat.is_open(), "the chat opens again")

dual.stop()
h.report()
