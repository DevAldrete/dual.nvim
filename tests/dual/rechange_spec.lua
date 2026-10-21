-- The review, end to end: the agent changes a file, and the review
-- opens on it.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local review = require("dual.review")
local window = require("dual.ui.review")

h.group("the review, end to end")

dual.setup({
  server = {
    cmd = "nvim",
    args = { "--headless", "-u", "NONE", "-l", "tests/dual/mock_xia.lua" },
  },
  keys = {},
})

h.ok(h.wait_for(function()
  return dual.state.session ~= nil
end, 10000) == false, "the server is not started yet")

-- A turn that changes a file.
dual.send("change demo.c")

h.ok(h.wait_for(function()
  return dual.state.session ~= nil
end, 10000), "the server answers")

h.ok(h.wait_for(function()
  return review.get("demo.c") ~= nil
end, 10000), "the change is under review")
h.ok(h.wait_for(function()
  return window.is_open()
end, 10000), "the review opened on its own")

local change = review.get("demo.c")
h.ok(change ~= nil, "the change is there")
h.eq(1, #review.hunks(change), "there is a hunk to decide")

-- The window shows the difference.
local shown = table.concat(
  vim.api.nvim_buf_get_lines(window.buffer, 0, -1, false), "\n")
h.contains(shown, "demo.c", "the window names the file")
h.contains(shown, "@@", "the window shows the diff")

-- Accepting it decides the change.
vim.api.nvim_win_set_cursor(window.window, { 3, 0 })
window.accept()
h.eq(nil, review.get("demo.c"), "the change is decided")

dual.stop()
h.report()
