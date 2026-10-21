-- The diff engine: the hunks, and what a decision about one does.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local diff = require("dual.diff")

h.group("the diff engine")

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

-- One change, one hunk. The context reaches three lines back and three
-- lines forward, so in a file this small the hunk is the whole file.
local hunks = diff.hunks(before, after)
h.eq(1, #hunks, "one change is one hunk")
local hunk = hunks[1]
h.eq(1, hunk.base_start, "the hunk starts with its context")
h.eq(4, hunk.base_count, "the hunk carries its context")
h.eq("@@ -1,4 +1,4 @@", diff.header(hunk), "the header says where the hunk is")
h.eq("context", hunk.lines[1].type, "the context comes first")
h.eq("del", hunk.lines[2].type, "the line that goes is marked")
h.eq("add", hunk.lines[3].type, "the line that comes is marked")
h.contains(hunk.lines[2].text, "int x = 1", "the old line is the old one")
h.contains(hunk.lines[3].text, "int x = 2", "the new line is the new one")

-- The rendering is the notation of a diff.
local rendered = diff.render(hunk)
h.eq("@@ -1,4 +1,4 @@", rendered[1], "the header is the first line")
h.eq(" int main(void) {", rendered[2], "the context keeps its space")
h.eq("-  int x = 1;", rendered[3], "the removal is marked")
h.eq("+  int x = 2;", rendered[4], "the addition is marked")
h.eq(" }", rendered[#rendered], "the context ends the hunk")

-- Two changes, far apart: two hunks.
local spread = table.concat({
  "one",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight",
  "nine",
  "ten",
}, "\n")
local spread2 = table.concat({
  "ONE",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight",
  "nine",
  "TEN",
}, "\n")
local two = diff.hunks(spread, spread2)
h.eq(2, #two, "two distant changes are two hunks")

-- Two changes, close together: one hunk.
local close = table.concat({ "a", "b", "c", "d", "e" }, "\n")
local close2 = table.concat({ "A", "b", "c", "d", "E" }, "\n")
local one = diff.hunks(close, close2)
h.eq(1, #one, "two close changes are one hunk")

-- No change, no hunk.
h.eq(0, #diff.hunks(before, before), "no change is no hunk")

-- Accepting a hunk moves the base toward the target.
local base_lines = diff.lines(before)
local accepted = diff.accept(base_lines, hunk)
h.eq(after, diff.text(accepted), "the base is the target where the hunk is")

-- Refusing a hunk moves the target back toward the base.
local target_lines = diff.lines(after)
local refused = diff.refuse(target_lines, hunk)
h.eq(before, diff.text(refused), "the target stops asking for the change")

-- The scope: the hunks that touch it, and the ones that do not.
local inside, outside = diff.split(two, 1, 2)
h.eq(1, #inside, "the hunk in the range is in it")
h.eq(1, #outside, "the hunk out of the range is out of it")
h.ok(diff.touches(two[1], 1, 2), "the first hunk touches the range")
h.ok(not diff.touches(two[2], 1, 2), "the second hunk does not")

-- The whole difference, as a diff writes it.
local unified = diff.unified(before, after, "src/main.c")
h.eq("--- a/src/main.c", unified[1], "the diff names the file")
h.eq("+++ b/src/main.c", unified[2], "the diff names the new file")
h.contains(table.concat(unified, "\n"), "-  int x = 1;", "the diff holds the change")

h.report()
