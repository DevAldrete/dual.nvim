-- The client: the protocol, from this side.
--
-- The tests talk to a stand-in for the server, so they need neither the
-- binary nor a network.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local client_mod = require("dual.client")
local transport_mod = require("dual.transport.stdio")

h.group("the client")

local transport = transport_mod.new({
  cmd = "nvim",
  args = { "--headless", "-u", "NONE", "-l", "tests/dual/mock_xia.lua" },
})
local client = client_mod.new({ transport = transport })

local ready = false
local failed = nil
client:start(function()
  ready = true
end, function(err)
  failed = err
end)

h.ok(h.wait_for(function()
  return ready or failed ~= nil
end, 10000), "the server says hello")
h.is_nil(failed, "the server starts")
h.eq("0.0.0-mock", client.version, "the version comes with the greeting")
h.eq("mock/m", client.model, "the model comes with the greeting")
h.eq("mock-session", client.session, "the session comes with the greeting")
h.ok(client:has("sync"), "the capabilities are known")
h.ok(not client:has("nonsense"), "a command the server does not have is not claimed")

-- A request is answered with its own id.
local reply = nil
local id = client:request("status", {}, function(r)
  reply = r
end)
h.ok(h.wait_for(function()
  return reply ~= nil
end, 5000), "the reply comes")
h.eq(id, reply.id, "the reply carries the id of the request")
h.eq(true, reply.ok, "the reply says it worked")
h.eq("mock/m", reply.status.model, "the reply carries the state")

-- The events are handed to the listeners.
local events = {}
client:on("*", function(ev)
  table.insert(events, ev.event)
end)
client:send("send", { text = "hello" })
h.ok(h.wait_for(function()
  return #events >= 4
end, 5000), "the events come")
h.eq("run_start", events[1], "the turn starts")
h.eq("run_end", events[#events], "the turn ends")
h.ok(vim.tbl_contains(events, "message"), "the answer comes as a message")

client:stop()
h.report()
