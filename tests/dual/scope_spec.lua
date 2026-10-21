-- The scoped requests: change this, insert here.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local scope = require("dual.scope")
local buffers = require("dual.buffers")
local review = require("dual.review")
local change = require("dual.ops.change")

h.group("the scoped requests")

dual.setup({
  server = {
    cmd = "nvim",
    args = { "--headless", "-u", "NONE", "-l", "tests/dual/mock_xia.lua" },
  },
  keys = {},
})

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, "dual_scope_test.c")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "int main(void) {",
  "  return 0;",
  "}",
})
vim.api.nvim_set_current_buf(buf)

-- A selection over the second line.
vim.api.nvim_buf_set_mark(buf, "<", 2, 0, {})
vim.api.nvim_buf_set_mark(buf, ">", 2, 0, {})

local captured = scope.capture()
h.ok(captured ~= nil, "the selection is captured")
h.eq("dual_scope_test.c", captured.path, "the scope knows the file")
h.contains(captured.text, "return 0", "the scope holds the text")

-- The request says what "this" is, and what is wanted.
local request = scope.prompt(captured, "make it return 1", "change")
h.contains(request, "<dual_context", "the request carries the scope")
h.contains(request, "dual_scope_test.c", "the request names the file")
h.contains(request, "return 0", "the request carries the selection")
h.contains(request, "make it return 1", "the request carries the question")
h.contains(request, "Change this code", "the request says what is wanted")

-- The insert: an empty range at the cursor.
vim.api.nvim_win_set_cursor(0, { 3, 0 })
local at_cursor = scope.capture_cursor()
h.ok(at_cursor ~= nil, "the cursor is a scope")
h.eq("", at_cursor.text, "the range is empty")
local insert_request = scope.prompt(at_cursor, "a helper", "insert")
h.contains(insert_request, "<dual_context", "the request carries the scope")
h.contains(insert_request, "Write the code that goes here",
  "the request says what is wanted")

-- The turn: the scope is remembered, and the change is reviewed against
-- it.
buffers.pending = {}
change.ask(captured, "make it return 1", "change")

h.ok(h.wait_for(function()
  return dual.state.session ~= nil
end, 10000), "the server answers")
h.ok(h.wait_for(function()
  return review.get("dual_scope_test.c") ~= nil
end, 10000), "the change is under review")

local pending = review.get("dual_scope_test.c")
h.ok(pending.scope ~= nil, "the review knows the scope it was asked for")
h.eq("dual_scope_test.c", pending.scope.path, "and which file it was about")

-- The scope narrows the review: the hunks that touch it are the ones in
-- question.
local entries = review.entries(pending)
h.eq(1, #entries, "there is one hunk")
h.eq(true, entries[1].in_scope, "the hunk is in question")

dual.stop()
h.report()
