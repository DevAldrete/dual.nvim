-- The server: how the plugin runs xia.
--
-- The plugin owns the process, so it owns the server's configuration too.
-- The shell is the one bit of policy: it sees the disk, while the file
-- tools see the buffers.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local server = require("dual.server")
local config = require("dual.config")

h.group("the server")

local cfg = config.setup({})

-- The command.
local cmd = server.command(cfg)
h.eq("xia", cmd[1], "the command is the binary")
h.eq("--serve", cmd[2], "the command starts the server")

local with_model = config.setup({ server = { model = "anthropic/claude-sonnet-4" } })
local cmd2 = server.command(with_model)
h.eq("-m", cmd2[#cmd2 - 1], "the model is passed to the server")
h.eq("anthropic/claude-sonnet-4", cmd2[#cmd2], "the model is the one that was asked for")

-- The shell.
h.eq(nil, server.init_script(config.setup({ allow_shell = true })),
  "a user who wants the shell gets no hiding")
local script = server.init_script(config.setup({ allow_shell = false }))
h.ok(script ~= nil, "the shell is hidden by default")
h.contains(script, 'xia.hide_tool("bash")', "the script hides the shell")

-- The environment.
local files = {}
local env = server.environment(config.setup({ allow_shell = false }), files)
h.ok(env["XIA_INIT"] ~= nil, "the server reads the plugin's configuration")
h.eq(1, #files, "the configuration is a file")
local f = io.open(files[1], "r")
local written = f:read("*a")
f:close()
h.contains(written, "hide_tool", "the file holds the hiding")

local files2 = {}
local env2 = server.environment(config.setup({ allow_shell = true }), files2)
h.eq(nil, env2["XIA_INIT"], "a server with the shell reads nothing of the plugin's")
h.eq(0, #files2, "and no file is written")

-- The user's environment is kept.
h.ok(env["PATH"] ~= nil, "the environment of Neovim is kept")

h.report()
