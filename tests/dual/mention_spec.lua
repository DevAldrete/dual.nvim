-- The mentions and the quickfix.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local files = require("dual.files")
local quickfix = require("dual.quickfix")

h.group("the mentions and the quickfix")

dual.setup({
  server = {
    cmd = "nvim",
    args = { "--headless", "-u", "NONE", "-l", "tests/dual/mock_xia.lua" },
  },
  keys = {},
})

-- The expansion: a mention is a path, and the agent is told which ones.
local text, paths = files.expand("look at @src/main.c and @lua/dual/init.lua")
h.eq(2, #paths, "the mentions are found")
h.eq("src/main.c", paths[1], "the first mention is the path")
h.contains(text, "look at src/main.c and lua/dual/init.lua",
  "the mentions become paths")
h.contains(text, "<dual_mentions>", "the agent is told which files")
h.contains(text, "src/main.c", "the list names the file")

-- Nothing mentioned, nothing added.
local plain = files.expand("just a question")
h.eq("just a question", plain, "a text without mentions is untouched")

-- The files of the project: the ones the plugin has, at least.
local all = files.all()
h.ok(#all > 0, "the project has files")
h.ok(vim.tbl_contains(all, "lua/dual/init.lua"), "the plugin's own files are there")

-- The completion offers the files that match.
local matching = files.complete("init")
h.ok(#matching > 0, "the completion finds something")
h.ok(vim.tbl_contains(matching, "lua/dual/init.lua"), "and it is the right file")

-- The quickfix: the results of a search fill the list.
local items = quickfix.from_grep("src/main.c:12:  int x = 1;\n2 match(es)\n")
h.eq(1, #items, "the matches are the items")
h.eq("src/main.c", items[1].filename, "the item names the file")
h.eq(12, items[1].lnum, "the item names the line")
h.contains(items[1].text, "int x = 1", "the item holds the line")

-- A glob: one path per line.
local found = quickfix.from_glob("src/main.c\nsrc/other.c\n3 match(es)\n")
h.eq(2, #found, "the files are the items")
h.eq("src/main.c", found[1].filename, "the item names the file")

-- The turn: a search fills the list for real.
vim.fn.setqflist({})
dual.send("search for x")
h.ok(h.wait_for(function()
  local qf = vim.fn.getqflist()
  return #qf > 0
end, 10000), "the quickfix list has the matches")
local qf = vim.fn.getqflist()
h.eq(2, #qf, "the list holds the matches")
h.contains(vim.fn.bufname(qf[1].bufnr), "lua/dual/init.lua", "the list holds the file")
h.eq(12, qf[1].lnum, "the list holds the line")

dual.stop()
h.report()
