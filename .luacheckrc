-- luacheck: globals vim
std = "luajit"
cache = true
codes = true
self = false

-- The tests reach into the module table on purpose.
ignore = {
  "212", -- unused argument
}
