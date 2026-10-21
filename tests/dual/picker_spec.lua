-- The pickers: the model and the session.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local model = require("dual.ops.model")
local sessions = require("dual.ops.sessions")

h.group("the pickers")

dual.setup({
  server = {
    cmd = "nvim",
    args = { "--headless", "-u", "NONE", "-l", "tests/dual/mock_xia.lua" },
  },
  keys = {},
})

-- The picker is the user's: `vim.ui.select` is replaced, so the test
-- can choose.
local chosen = nil
local offered = nil
vim.ui.select = function(items, opts, on_choice)
  offered = items
  on_choice(items[#items])
end

-- The model picker.
model.run()
h.ok(h.wait_for(function()
  return offered ~= nil
end, 10000), "the picker was offered the models")
h.eq(2, #offered, "the server's models are the ones offered")
h.contains(offered[1].name, "mock/m", "the list names the model")
h.contains(offered[1].name, "8k", "the list says how big the context is")
h.contains(offered[1].name, "*", "the model in use is marked")

-- The pick is given to the server.
h.ok(h.wait_for(function()
  return dual.state.client ~= nil
end, 10000), "the server is there")

-- The sessions picker.
offered = nil
sessions.run()
h.ok(h.wait_for(function()
  return offered ~= nil
end, 10000), "the picker was offered the sessions")
h.eq(2, #offered, "the store's sessions are the ones offered")
h.contains(offered[1].name, "the first one", "the list names the session")
h.contains(offered[1].name, "messages", "the list says how big it is")

-- A server that does not know the command says so, rather than failing.
local refused = false
local notify = dual.notify
dual.notify = function(text, level)
  refused = true
end
local client = dual.state.client
local has = client.has
client.has = function()
  return false
end
offered = nil
model.run()
h.ok(refused, "the plugin says the server does not know the models")
client.has = has
dual.notify = notify

dual.stop()
h.report()
