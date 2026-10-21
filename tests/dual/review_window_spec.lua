-- The review window: the diff, the hunks, the decision.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local buffers = require("dual.buffers")
local review = require("dual.review")
local window = require("dual.ui.review")

h.group("the review window")

dual.setup({ keys = {} })

local before = table.concat({
  "int main(void) {",
  "  int x = 1;",
  "  return 0;",
  "}",
}, "\n")

local after = table.concat({
  "int main(void) {",
  "  int x = 2;",
  "  return 0;",
  "}",
}, "\n")

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, "dual_review_window.c")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(before, "\n", { plain = true }))
vim.api.nvim_set_current_buf(buf)

buffers.pending = {}
local change = review.record("dual_review_window.c", after)

-- The window opens with the diff in it.
window.open("dual_review_window.c")
h.ok(window.is_open(), "the review is open")
h.eq(1, #vim.api.nvim_list_wins() - 1, "the review adds one window")

local function shown()
  return table.concat(vim.api.nvim_buf_get_lines(window.buffer, 0, -1, false), "\n")
end

h.contains(shown(), "dual_review_window.c", "the window names the file")
h.contains(shown(), "@@", "the window shows the diff")
h.contains(shown(), "-  int x = 1;", "the window shows what goes")
h.contains(shown(), "+  int x = 2;", "the window shows what comes")
h.eq(1, #window.marks, "there is one hunk to decide")

-- The hunk under the cursor is found.
vim.api.nvim_win_set_cursor(window.window, { 3, 0 })
local mark = window.under_cursor()
h.ok(mark ~= nil, "the cursor is on the hunk")
h.eq(1, mark.index, "and it is the first one")

-- Accepting it writes the change into the buffer.
window.accept()
h.eq(after, table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"),
  "the buffer holds the change")
h.ok(not window.is_open(), "the review is over, and closes")

-- A change with two hunks: the window walks them.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
})
buffers.pending = {}
local two = review.record("dual_review_window.c", table.concat({
  "ONE", "two", "three", "four", "five", "six", "seven", "eight", "nine", "TEN",
}, "\n"))
window.open("dual_review_window.c")
h.eq(2, #window.marks, "there are two hunks to decide")

-- ]c walks to the next one.
vim.api.nvim_win_set_cursor(window.window, { 1, 0 })
window.goto(1)
h.eq(window.marks[1].first, vim.api.nvim_win_get_cursor(window.window)[1],
  "the cursor lands on the first hunk")
window.goto(1)
h.eq(window.marks[2].first, vim.api.nvim_win_get_cursor(window.window)[1],
  "the cursor lands on the second hunk")
window.goto(-1)
h.eq(window.marks[1].first, vim.api.nvim_win_get_cursor(window.window)[1],
  "and back again")

-- Refusing one leaves the buffer alone.
window.refuse()
h.eq("one", vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1],
  "the buffer is what it was")
h.eq(1, #window.marks, "one hunk is left")

-- Closing the review keeps the change pending.
window.close()
h.ok(not window.is_open(), "the review is closed")
h.ok(review.get("dual_review_window.c") ~= nil, "the change is still waiting")

review.forget("dual_review_window.c")
buffers.pending = {}
h.report()
