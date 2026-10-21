-- The review window: the diff, the hunks, the decision.
--
-- The window is a floating one: a review is a moment, and it should not
-- disturb the layout the user has. The full comparison is a split,
-- because two versions side by side want the room.
--
-- The notation is a git diff's, because that is what everybody reads.

local M = {}

local diff = require("dual.diff")
local highlights = require("dual.ui.highlights")

M.window = nil
M.buffer = nil
M.path = nil
M.change = nil

-- Where the hunks are in the window: the line they start at, and the
-- line they end at.
M.marks = {}

--- Is the review open?
function M.is_open()
  return M.window ~= nil and vim.api.nvim_win_is_valid(M.window)
end

--- The hunk under the cursor.
function M.under_cursor()
  if not M.is_open() then
    return nil
  end
  local line = vim.api.nvim_win_get_cursor(M.window)[1]
  for _, mark in ipairs(M.marks) do
    if line >= mark.first and line <= mark.last then
      return mark
    end
  end
  return nil
end

--- The lines of the window.
function M.draw()
  if M.change == nil then
    return
  end
  local entries = require("dual.review").entries(M.change)

  local lines = {}
  local marks = {}
  local signs = {}

  local inside = {}
  local outside = {}
  for _, entry in ipairs(entries) do
    if entry.in_scope then
      inside[#inside + 1] = entry
    else
      outside[#outside + 1] = entry
    end
  end

  -- The header: what is being reviewed, and how much of it is left.
  local header = (" %s  ·  %d hunk%s"):format(
    M.path,
    #inside,
    #inside == 1 and "" or "s"
  )
  if M.change.moved then
    header = header .. "  ·  the buffer changed under the review"
  end
  lines[#lines + 1] = header
  signs[#signs + 1] = "DualHeader"

  local function add(entry)
    lines[#lines + 1] = diff.header(entry.hunk)
    signs[#signs + 1] = "DualHunk"
    local first = #lines
    for _, line in ipairs(entry.hunk.lines) do
      local sign = " "
      if line.type == "del" then
        sign = "-"
      elseif line.type == "add" then
        sign = "+"
      end
      lines[#lines + 1] = sign .. line.text
      signs[#signs + 1] = line.type == "del" and "DualDel"
        or (line.type == "add" and "DualAdd" or nil)
    end
    marks[#marks + 1] = {
      first = first,
      last = #lines,
      index = entry.index,
      in_scope = entry.in_scope,
    }
  end

  for _, entry in ipairs(inside) do
    add(entry)
  end

  if #outside > 0 then
    lines[#lines + 1] = ""
    signs[#signs + 1] = nil
    lines[#lines + 1] = "--- outside the scope of the request ---"
    signs[#signs + 1] = "DualPending"
    for _, entry in ipairs(outside) do
      add(entry)
    end
  end

  vim.api.nvim_buf_set_lines(M.buffer, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(M.buffer, -1, 0, -1)
  for i, sign in ipairs(signs) do
    if sign ~= nil then
      vim.api.nvim_buf_add_highlight(M.buffer, -1, sign, i - 1, 0, -1)
    end
  end
  M.marks = marks
end

--- The keys of the review.
function M.setup_keys()
  local buf = M.buffer

  vim.keymap.set("n", "]c", function()
    M.goto(1)
  end, { buffer = buf, desc = "dual: the next hunk" })
  vim.keymap.set("n", "[c", function()
    M.goto(-1)
  end, { buffer = buf, desc = "dual: the previous hunk" })

  vim.keymap.set("n", "a", function()
    M.accept()
  end, { buffer = buf, desc = "dual: accept the hunk" })
  vim.keymap.set("n", "r", function()
    M.refuse()
  end, { buffer = buf, desc = "dual: refuse the hunk" })
  vim.keymap.set("n", "A", function()
    M.accept_all()
  end, { buffer = buf, desc = "dual: accept every hunk" })
  vim.keymap.set("n", "R", function()
    M.refuse_all()
  end, { buffer = buf, desc = "dual: refuse every hunk" })

  vim.keymap.set("n", "d", function()
    M.full_diff()
  end, { buffer = buf, desc = "dual: the whole file, side by side" })
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = buf, desc = "dual: close the review" })
end

--- Moves to the next or the previous hunk.
function M.goto(direction)
  if not M.is_open() or #M.marks == 0 then
    return
  end
  local line = vim.api.nvim_win_get_cursor(M.window)[1]
  local target = nil
  if direction > 0 then
    for _, mark in ipairs(M.marks) do
      if mark.first > line then
        target = mark
        break
      end
    end
    target = target or M.marks[1]
  else
    for i = #M.marks, 1, -1 do
      if M.marks[i].first < line then
        target = M.marks[i]
        break
      end
    end
    target = target or M.marks[#M.marks]
  end
  pcall(vim.api.nvim_win_set_cursor, M.window, { target.first, 0 })
end

--- Accepts the hunk under the cursor.
function M.accept()
  local mark = M.under_cursor()
  if mark == nil then
    return
  end
  require("dual.review").accept(M.change, mark.index)
  M.after()
end

--- Refuses the hunk under the cursor.
function M.refuse()
  local mark = M.under_cursor()
  if mark == nil then
    return
  end
  require("dual.review").refuse(M.change, mark.index)
  M.after()
end

--- Accepts every hunk that is in question.
--
-- The hunks outside the scope are not touched: the user asked for
-- something, and the agent did more.
function M.accept_all()
  local review = require("dual.review")
  local entries = review.entries(M.change)
  local indexes = {}
  for _, entry in ipairs(entries) do
    if entry.in_scope then
      indexes[#indexes + 1] = entry.index
    end
  end
  -- From the last one: accepting a hunk changes the ones after it.
  for i = #indexes, 1, -1 do
    review.accept(M.change, indexes[i])
  end
  M.after()
end

--- Refuses every hunk that is in question.
function M.refuse_all()
  local review = require("dual.review")
  local entries = review.entries(M.change)
  local indexes = {}
  for _, entry in ipairs(entries) do
    if entry.in_scope then
      indexes[#indexes + 1] = entry.index
    end
  end
  for i = #indexes, 1, -1 do
    review.refuse(M.change, indexes[i])
  end
  M.after()
end

--- After a decision: redraw, or move on to the next file.
function M.after()
  local review = require("dual.review")
  if M.change == nil or review.get(M.path) == nil then
    -- The change is over: the next one waits, if there is one.
    local paths = review.paths()
    if #paths > 0 then
      M.open(paths[1])
      return
    end
    M.close()
    return
  end
  M.draw()
end

--- The whole file, side by side: what the user has and what the agent
--- wants.
function M.full_diff()
  if M.change == nil then
    return
  end
  local review = require("dual.review")
  review.sync(M.change)

  local old = vim.api.nvim_create_buf(false, true)
  local new = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(old, 0, -1, false, M.change.base)
  vim.api.nvim_buf_set_lines(new, 0, -1, false, M.change.target)
  vim.api.nvim_buf_set_name(old, "dual://review-old")
  vim.api.nvim_buf_set_name(new, "dual://review-new")

  vim.cmd("botright 2new")
  vim.api.nvim_win_set_buf(0, old)
  vim.cmd("diffthis")
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, new)
  vim.cmd("diffthis")
  vim.cmd("wincmd p")
  vim.cmd("diffthis")
  vim.cmd("setlocal scrollbind")

  vim.keymap.set("n", "q", function()
    vim.cmd("diffoff")
    vim.cmd("close")
    vim.cmd("close")
  end, { buffer = new, desc = "dual: back to the review" })
end

--- Opens the review of a path.
function M.open(path)
  local review = require("dual.review")
  local change = review.get(path)
  if change == nil then
    return
  end
  M.path = path
  M.change = change

  local buf = vim.fn.bufnr("dual://review")
  if buf == -1 or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "dual://review")
  end
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "dual-review", { buf = buf })
  M.buffer = buf

  local width = math.max(40, math.floor(vim.o.columns * 0.9))
  local height = math.max(10, math.floor(vim.o.lines * 0.8))
  M.window = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " dual: review ",
    title_pos = "center",
  })

  highlights.setup()
  M.setup_keys()
  M.draw()
  pcall(vim.api.nvim_win_set_cursor, M.window, { 1, 0 })
end

--- Closes the review. The change stays pending: the user may come back.
function M.close()
  if M.window ~= nil and vim.api.nvim_win_is_valid(M.window) then
    pcall(vim.api.nvim_win_close, M.window, true)
  end
  M.window = nil
  M.marks = {}
  M.change = nil
  M.path = nil
end

return M
