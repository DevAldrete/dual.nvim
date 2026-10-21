-- The review state: what the agent changed, and what a decision does.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local buffers = require("dual.buffers")
local review = require("dual.review")

h.group("the review state")

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

-- A file with a buffer, which is what the plugin believes.
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, "dual_review_test.c")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(before, "\n", { plain = true }))
vim.api.nvim_set_current_buf(buf)

-- A change the agent made.
local change = review.record("dual_review_test.c", after)
h.eq("dual_review_test.c", change.path, "the change knows its file")
h.eq(buf, change.buf, "the change found the buffer")
h.eq(1, #review.hunks(change), "one hunk, one change")

-- The plugin believes what it holds.
buffers.pending = {}
review.after(change)
h.eq(after, buffers.pending["dual_review_test.c"],
  "the plugin believes what the agent wants")

-- Refusing a hunk: the buffer stays, the target stops asking.
review.refuse(change, 1)
h.eq(before, table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"),
  "the buffer is what it was")
h.eq(0, #review.hunks(change), "the hunk is gone")
h.eq(nil, buffers.pending["dual_review_test.c"],
  "the change is resolved, so the plugin believes the buffer")
h.eq(nil, review.get("dual_review_test.c"), "the change is resolved")

-- Accepting a hunk: the buffer takes the new lines.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(before, "\n", { plain = true }))
buffers.pending = {}
local change2 = review.record("dual_review_test.c", after)
review.accept(change2, 1)
h.eq(after, table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"),
  "the buffer holds the change")
h.eq(0, #review.hunks(change2), "the hunk is gone")
h.eq(nil, buffers.pending["dual_review_test.c"],
  "the buffer is the truth, and the pending change is gone")

-- A change in a file with no buffer: accepting it opens the file.
buffers.pending = {}
local change3 = review.record("dual_review_new.c", "int added(void) { return 1; }\n")
h.eq(nil, change3.buf, "the file is not open")
review.accept(change3, 1)
h.ok(change3.buf ~= nil, "accepting opens the file")
h.eq("int added(void) { return 1; }\n",
  table.concat(vim.api.nvim_buf_get_lines(change3.buf, 0, -1, false), "\n"),
  "the file holds what the agent wrote")

-- The scope: the hunks that touch it are the ones in question.
buffers.pending = {}
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(before, "\n", { plain = true }))
vim.api.nvim_buf_set_mark(buf, "<", 2, 0, {})
vim.api.nvim_buf_set_mark(buf, ">", 2, 0, {})
local scope = require("dual.scope").capture()
h.ok(scope ~= nil, "the scope is there")
local scoped = review.record("dual_review_test.c", after, { scope = scope })
local inside, outside = review.split(scoped)
h.eq(1, #inside, "the hunk that touches the scope is in it")
h.eq(0, #outside, "the hunk out of the scope is out of it")

review.forget("dual_review_test.c")
review.forget("dual_review_new.c")
buffers.pending = {}
h.report()
