-- The prompt: the small window that asks for a line of text.
--
-- It is a floating window near the code, with an input buffer. `Enter`
-- submits, `Esc` cancels, and the text never enters the source buffer.

local M = {}

M.window = nil
M.buffer = nil

--- Opens the prompt near a position.
-- @param opts table: prompt (the text to show), row, col, on_submit, on_cancel
function M.open(opts)
  M.close()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "dual://prompt")
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "dual-prompt", { buf = buf })
  M.buffer = buf

  local width = opts.width or math.min(60, math.max(30, vim.o.columns - 10))
  local height = opts.height or 3
  local row = opts.row or math.floor(vim.o.lines * 0.5)
  local col = opts.col or math.floor(vim.o.columns * 0.5)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(0, math.min(row, vim.o.lines - height - 1)),
    col = math.max(0, math.min(col, vim.o.columns - width - 1)),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = opts.title or " dual ",
    title_pos = "center",
  })
  M.window = win

  if opts.prompt ~= nil and opts.prompt ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { opts.prompt })
  end

  -- `Enter` submits, in either mode.
  local function submit()
    local text = M.text()
    M.close()
    if opts.on_submit then
      opts.on_submit(text)
    end
  end
  local function cancel()
    M.close()
    if opts.on_cancel then
      opts.on_cancel()
    end
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = buf, desc = "dual: submit" })
  vim.keymap.set("n", "<CR>", submit, { buffer = buf, desc = "dual: submit" })
  vim.keymap.set("i", "<Esc>", cancel, { buffer = buf, desc = "dual: cancel" })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, desc = "dual: cancel" })
  vim.keymap.set("n", "q", cancel, { buffer = buf, desc = "dual: cancel" })

  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  vim.cmd("startinsert")
  return win
end

--- The text of the prompt.
function M.text()
  if M.buffer == nil or not vim.api.nvim_buf_is_valid(M.buffer) then
    return ""
  end
  local lines = vim.api.nvim_buf_get_lines(M.buffer, 0, -1, false)
  return (table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Closes the prompt.
function M.close()
  if M.window ~= nil and vim.api.nvim_win_is_valid(M.window) then
    pcall(vim.api.nvim_win_close, M.window, true)
  end
  M.window = nil
  M.buffer = nil
end

--- Asks for a line of text.
-- @param opts table: prompt, title, row, col
-- @param on_submit function: called with the text
function M.capture(opts, on_submit)
  M.open(vim.tbl_extend("force", opts or {}, {
    on_submit = function(text)
      if text ~= nil and text ~= "" then
        on_submit(text)
      end
    end,
  }))
end

return M
