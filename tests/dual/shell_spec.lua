-- The shell: offered when the platform can fence it in, and away when it
-- cannot.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local server = require("dual.server")
local config = require("dual.config")

h.group("the shell")

-- The default: the shell is offered when the server can fence it in.
local auto = config.merge(config.defaults, {})
h.eq("auto", auto.allow_shell, "the shell follows the server by default")

local script = server.init_script(auto)
h.ok(script ~= nil, "there is something to say about the shell")
h.contains(script, "xia.sandbox()", "the rule asks what the shell is fenced with")
h.contains(script, 'xia.hide_tool("bash")',
  "and keeps the shell away when there is no sandbox")

-- The user says no.
local never = config.merge(config.defaults, { allow_shell = false })
local hiding = server.init_script(never)
h.ok(hiding ~= nil, "the user's choice is written down")
h.contains(hiding, 'xia.hide_tool("bash")', "the shell stays away")
h.ok(not hiding:find("xia.sandbox()"), "and the server is not asked")

-- The user says yes: the plugin has nothing to say, and the user's own
-- configuration is left alone.
local always = config.merge(config.defaults, { allow_shell = true })
h.eq(nil, server.init_script(always), "the plugin writes nothing")

-- The user's own configuration still runs.
local user_init = vim.fn.tempname() .. ".lua"
local f = assert(io.open(user_init, "w"))
f:write("print('hello')\n")
f:close()
vim.env.XIA_INIT = user_init
local with_user = server.init_script(auto)
h.ok(with_user ~= nil, "there is still something to say")
h.contains(with_user, "dofile(", "the user's configuration is run")
h.contains(with_user, user_init, "and it is the user's own file")
vim.env.XIA_INIT = nil

-- The greeting says what the shell is fenced with, and the plugin keeps
-- it.
local client = require("dual.client")
local c = client.new({})
c:on_hello({ version = "1.0.0", model = "mock/m", session = "s",
             capabilities = {}, sandbox = "seatbelt" })
h.eq("seatbelt", c.sandbox, "the client knows what the shell is fenced with")

local plain = client.new({})
plain:on_hello({ version = "1.0.0", model = "mock/m", session = "s",
                 capabilities = {} })
h.eq("none", plain.sandbox, "a server that says nothing has no sandbox")

h.report()
