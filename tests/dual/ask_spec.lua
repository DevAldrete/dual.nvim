-- The quick ask: the scope, the request, the annotation.
--
-- The test drives the whole thing: a selection is captured, the question
-- is asked, the agent answers, and the answer lands below the code.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local scope = require("dual.scope")
local buffers = require("dual.buffers")
local annotation = require("dual.ui.annotation")
local ask = require("dual.ops.ask")

h.group("the quick ask")

-- A file with something in it, and a selection over it.
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, "dual_ask_test.c")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "int main(void) {",
  "  return 0;",
  "}",
})
vim.api.nvim_set_current_buf(buf)

-- The scope of a selection: the lines, the text and the file.
vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
vim.api.nvim_buf_set_mark(buf, ">", 2, 0, {})
vim.cmd("normal! gg")
vim.api.nvim_win_set_cursor(0, { 2, 2 })

local captured = scope.capture()
h.ok(captured ~= nil, "the selection is captured")
h.eq("dual_ask_test.c", captured.path, "the scope knows the file")
h.contains(captured.text, "return 0", "the scope holds the text")

-- The request carries the scope and the question.
local request = scope.prompt(captured, "what does this do?")
h.contains(request, "<dual_context", "the request carries the scope")
h.contains(request, "dual_ask_test.c", "the request names the file")
h.contains(request, "lines=", "the request names the lines")
h.contains(request, "return 0", "the request carries the selection")
h.contains(request, "what does this do?", "the request carries the question")

-- The scope follows the edits: the marks move with the text.
vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "/* a new line */" })
local range = scope.range(captured)
h.ok(range ~= nil, "the scope is still there")
h.eq(1, range.start_row, "the scope moved down with the text")

-- The buffers that are pushed are the ones the plugin owns.
buffers.pending = {}
local payload = buffers.payload()
h.contains(payload["dual_ask_test.c"], "return 0", "the buffer is pushed")

-- The whole thing: the question goes out, the answer comes back.
dual.setup({
  server = {
    cmd = "nvim",
    args = { "--headless", "-u", "NONE", "-l", "tests/dual/mock_xia.lua" },
  },
  keys = {},
})

ask.ask(captured, "what does this do?")

h.ok(h.wait_for(function()
  return dual.state.session ~= nil
end, 10000), "the server answers")

-- The answer is in the annotation, below the code.
h.ok(h.wait_for(function()
  local notes = annotation.notes
  return #notes > 0 and #notes[#notes].answer > 0
end, 10000), "the answer lands in the annotation")
local note = annotation.notes[#annotation.notes]
h.contains(table.concat(note.answer, "\n"), "the answer", "the answer is there")

-- And the annotation is virtual text: the buffer is untouched.
h.eq(4, vim.api.nvim_buf_line_count(buf), "the buffer is not changed by the answer")

-- A change the agent made waits for the user.
buffers.on_change("a.c", "the agent's version")
h.eq(1, #buffers.pending_paths(), "the change is pending")
h.eq("the agent's version", buffers.payload()["a.c"],
  "the pending change is what the plugin believes")
buffers.accept("a.c")
h.eq(0, #buffers.pending_paths(), "an accepted change is not pending any more")

annotation.dismiss_all()
dual.stop()
h.report()
