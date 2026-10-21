-- The chat: the transcript, the input, the header.
--
-- The chat is a split on the right: the conversation above, the input
-- below, a header above that. The input is a normal buffer, with normal
-- modes and motions: `Enter` in Insert mode adds a line, `Enter` in
-- Normal mode sends.

local M = {}

local highlights = require("dual.ui.highlights")

M.buffers = {
  transcript = nil,
  header = nil,
  input = nil,
}

M.windows = {
  transcript = nil,
  header = nil,
  input = nil,
}

-- The text of the answer that is streaming in.
M.streaming = ""

--- Is the chat open?
function M.is_open()
  return M.windows.transcript ~= nil
    and vim.api.nvim_win_is_valid(M.windows.transcript)
end

--- A scratch buffer for the chat. The buffers outlive the windows: the
--- conversation is still there when the chat is closed and opened again.
local function scratch(name, filetype)
  local full = "dual://" .. name
  local buf = vim.fn.bufnr(full)
  if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, full)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
  return buf
end

--- Listens to the session: the transcript is the conversation.
function M.attach(session)
  if M.attached then
    return
  end
  M.attached = true
  local client = session.client

  client:on("line", function(ev)
    M.append(ev.role or "assistant", ev.style or "plain", ev.text or "")
  end)
  client:on("text", function(ev)
    M.stream(ev.text or "")
  end)
  client:on("message", function(ev)
    M.flush(ev.text)
  end)
  client:on("run_start", function()
    M.set_header("dual", "working")
  end)
  client:on("run_end", function()
    M.flush()
    M.set_header("dual", "idle")
  end)  client:on("status", function(ev)
    if ev.key == "model" and ev.value ~= nil then
      M.set_header("dual " .. ev.value, "idle")
    end
  end)
  client:on("permission", function(ev)
    M.append("system", "accent",
      ("the agent wants to run %s"):format(ev.name or "something"))
    M.append("system", "dim", "  y allows it, n refuses it")
  end)
end

--- Opens the chat.
function M.open()
  if M.is_open() then
    return
  end
  local cfg = require("dual.config").values
  highlights.setup()

  M.buffers.transcript = scratch("transcript", "dual")
  M.buffers.header = scratch("header", "dual")
  M.buffers.input = scratch("input", "dual")

  -- The split on the right.
  vim.cmd("botright vsplit")
  local chat = vim.api.nvim_get_current_win()
  local width = math.max(30, math.floor(vim.o.columns * (cfg.chat.width or 0.42)))
  vim.api.nvim_win_set_width(chat, width)

  -- The header on top of the column.
  vim.cmd("aboveleft split")
  local header = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(header, M.buffers.header)
  M.windows.header = header

  -- The transcript below the header.
  vim.cmd("wincmd j")
  local transcript = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(transcript, M.buffers.transcript)
  M.windows.transcript = transcript

  -- The input at the bottom.
  vim.cmd("belowright split")
  local input = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(input, M.buffers.input)
  M.windows.input = input

  -- The heights, once the column is whole: one line of header, a few of
  -- input, the rest of the conversation.
  vim.api.nvim_win_set_height(header, 1)
  vim.api.nvim_win_set_height(input, cfg.chat.input_lines or 3)

  M.setup_input()
  M.setup_header()
  M.setup_close()

  -- The cursor belongs in the input.
  vim.api.nvim_set_current_win(input)
  M.focus_input()

  -- The transcript is the conversation: it listens to the session as
  -- soon as there is one.
  require("dual").on_session(function(session)
    M.attach(session)
  end)
end

--- The keymaps of the input.
function M.setup_input()  local buf = M.buffers.input
  if buf == nil then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

  -- In Normal mode, `Enter` sends; in Insert mode it adds a line.
  vim.keymap.set("n", "<CR>", function()
    M.send()
  end, { buffer = buf, desc = "dual: send" })
  vim.keymap.set("n", "<Esc>", function()
    M.clear_input()
  end, { buffer = buf, desc = "dual: clear" })

  -- A mention: `@` completes the files of the project, and the agent
  -- reads them itself.
  vim.keymap.set("i", "@", function()
    M.complete_mention()
  end, { buffer = buf, desc = "dual: mention a file" })

  -- An approval, when one is waiting.
  vim.keymap.set("n", "y", function()
    local session = require("dual").state.session
    if session ~= nil and session.permission ~= nil then
      session:answer(true)
    end
  end, { buffer = buf, desc = "dual: allow" })
  vim.keymap.set("n", "n", function()
    local session = require("dual").state.session
    if session ~= nil and session.permission ~= nil then
      session:answer(false)
    end
  end, { buffer = buf, desc = "dual: refuse" })

  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      M.focus_input()
    end,
  })
end

--- `q` in a chat window closes the chat, not the source buffer: the
--- conversation is not the file the user came to edit.
function M.setup_close()
  for _, key in ipairs({ "transcript", "header", "input" }) do
    local win = M.windows[key]
    if win ~= nil then
      vim.keymap.set("n", "q", function()
        M.close()
      end, { buffer = M.buffers[key], desc = "dual: close the chat" })
    end
  end
end

--- Closes the chat. The session is not lost: it is in the runtime.
function M.close()
  for _, key in ipairs({ "transcript", "header", "input" }) do
    local win = M.windows[key]
    if win ~= nil and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    M.windows[key] = nil
  end
  M.streaming = ""
end

--- Opens the chat, or closes it.
function M.toggle()
  if M.is_open() then
    M.close()
    return
  end
  M.open()
end

--- The text of the input.
function M.input_text()
  if M.buffers.input == nil then
    return ""
  end
  local lines = vim.api.nvim_buf_get_lines(M.buffers.input, 0, -1, false)
  return (table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Empties the input.
function M.clear_input()
  if M.buffers.input == nil then
    return
  end
  vim.api.nvim_buf_set_lines(M.buffers.input, 0, -1, false, { "" })
end

--- Puts the cursor in the input.
function M.focus_input()
  if M.windows.input ~= nil and vim.api.nvim_win_is_valid(M.windows.input) then
    vim.api.nvim_set_current_win(M.windows.input)
  end
end

--- Completes a mention: the files of the project.
function M.complete_mention()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = line:sub(1, col)
  local word = before:match("@([%w%._/%-]*)$")
  if word == nil then
    -- A plain `@`: it is just a character.
    vim.api.nvim_put({ "@" }, "c", false, true)
    return
  end
  local items = require("dual.files").complete(word)
  if #items == 0 then
    vim.api.nvim_put({ "@" }, "c", false, true)
    return
  end
  -- The completion starts where the word does, and the `@` stays.
  vim.fn.complete(col - #word + 1, items)
end

--- Sends what the input holds.
function M.send()
  local text = M.input_text()
  if text == "" then
    return
  end
  M.clear_input()
  require("dual").send(text)
end

--- Adds a line to the transcript.
-- @param role string: user, assistant, tool or system
-- @param style string: the style of the line
-- @param text string: the text of the line
function M.append(role, style, text)
  if M.buffers.transcript == nil then
    return
  end
  local buf = M.buffers.transcript
  local before = vim.api.nvim_buf_line_count(buf)
  local lines = vim.split(text, "\n", { plain = true })
  local group = highlights.for_line(role, style)

  local at = before
  vim.api.nvim_buf_set_lines(buf, at - 1, at - 1, false, lines)
  for i = 0, #lines - 1 do
    vim.api.nvim_buf_add_highlight(buf, -1, "DualTranscript", at - 1 + i, 0, -1)
  end
  M.follow(before)
end

--- The answer that is streaming in.
function M.stream(text)
  M.streaming = M.streaming .. (text or "")
  while true do
    local at = M.streaming:find("\n", 1, true)
    if not at then
      break
    end
    local line = M.streaming:sub(1, at - 1)
    M.streaming = M.streaming:sub(at + 1)
    M.append("assistant", "plain", line)
    M.partial = nil
  end
  M.show_partial()
end

--- The part of the answer that has no newline yet. It lives on a line of
--- its own, at the end, so it never eats what came before it.
function M.show_partial()
  if M.buffers.transcript == nil then
    return
  end
  local buf = M.buffers.transcript
  if M.partial == nil then
    local at = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, at - 1, at - 1, false, { M.streaming })
    M.partial = at
  else
    vim.api.nvim_buf_set_lines(buf, M.partial - 1, M.partial - 1, false,
      { M.streaming })
  end
  vim.api.nvim_buf_add_highlight(buf, -1, "DualTranscript", M.partial - 1, 0, -1)
end

--- The end of the answer.
function M.flush(text)
  if M.partial ~= nil then
    -- The line is already there; the answer is what was streamed.
    M.partial = nil
    M.streaming = ""
    return
  end
  if M.streaming ~= "" then
    M.append("assistant", "plain", M.streaming)
  elseif text ~= nil and text ~= "" then
    -- An answer that never streamed: it still belongs in the transcript.
    M.append("assistant", "plain", text)
  end
  M.streaming = ""
end

--- Keeps the transcript at the bottom, unless the user scrolled up to
--- read something.
-- @param previous_count number: how many lines there were before
function M.follow(previous_count)
  local win = M.windows.transcript
  if win == nil or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = M.buffers.transcript
  if buf == nil then
    return
  end
  local count = vim.api.nvim_buf_line_count(buf)
  local at_bottom = true
  pcall(function()
    at_bottom = vim.api.nvim_win_call(win, function()
      return vim.fn.line("w$") >= previous_count
    end)
  end)
  if at_bottom then
    pcall(function()
      vim.api.nvim_win_set_cursor(win, { count, 0 })
    end)
  end
end

--- The header: what the session is and where it stands.
function M.setup_header()
  if M.buffers.header == nil then
    return
  end
  M.set_header("dual", "starting")
end

--- Writes the header.
function M.set_header(left, right)
  if M.buffers.header == nil then
    return
  end
  local text = (" %s%s%s "):format(
    left,
    right and ("  " .. right) or "",
    ""
  )
  vim.api.nvim_buf_set_lines(M.buffers.header, 0, -1, false, { text })
  vim.api.nvim_buf_add_highlight(M.buffers.header, -1, "DualHeader", 0, 0, -1)
end

return M
