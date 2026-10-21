-- The health of the plugin: `:checkhealth dual`.
--
-- The questions are the ones a user asks when nothing happens: is the
-- binary there, does the server start, what did it say, and what can it
-- be asked?

local M = {}

--- The check, for `:checkhealth`.
function M.check()
  local health = vim.health
  health.start("dual")

  local dual = require("dual")
  local cfg = dual.state.cfg or require("dual.config").values

  health.ok("the plugin is set up", { "the configuration is in effect" })

  if vim.fn.executable(cfg.server.cmd) == 1 then
    health.ok("the server is there", {
      ("%s is on the path"):format(cfg.server.cmd),
    })
  else
    health.error("the server is not there", {
      ("%s is not on the path"):format(cfg.server.cmd),
      "install xia, or point `server.cmd` at it",
    })
    return
  end

  local ready = false
  local failure = nil
  local client = nil
  dual.start(function(c)
    client = c
    ready = true
  end)
  -- The greeting is a moment away; the check waits for it.
  vim.wait(5000, function()
    return ready
  end, 20)

  if not ready then
    health.error("the server does not answer", {
      failure or "the greeting did not arrive",
      "run the server by hand to see what it says",
    })
    return
  end

  health.ok("the server answers", {
    ("version %s"):format(client.version),
    ("model %s"):format(client.model),
    ("session %s"):format(client.session),
    ("the shell is fenced with %s"):format(client.sandbox),
  })

  -- The shell: offered when the platform can fence it in, and away when
  -- it cannot.
  local allow = cfg.allow_shell
  if allow == true or (allow ~= false and client.sandbox ~= "none") then
    health.ok("the shell is offered", {
      "the project is read-only for it",
    })
  else
    health.info("the shell is away from the model", {
      allow == false and "the user asked for no shell"
        or "this platform cannot fence the shell in",
    })
  end

  local missing = {}
  for _, command in ipairs({ "send", "steer", "answer", "sync", "cancel" }) do
    if not client:has(command) then
      table.insert(missing, command)
    end
  end
  if #missing == 0 then
    health.ok("the server understands the plugin", {
      "the commands the plugin needs are all there",
    })
  else
    health.warn("the server is older than the plugin", {
      ("it does not understand: %s"):format(table.concat(missing, ", ")),
      "the plugin will not ask for them",
    })
  end
end

--- A short report, for `:DualHealth`.
function M.report()
  local dual = require("dual")
  local cfg = dual.state.cfg or require("dual.config").values

  if vim.fn.executable(cfg.server.cmd) ~= 1 then
    dual.notify(("%s is not on the path"):format(cfg.server.cmd),
      vim.log.levels.ERROR)
    return
  end

  dual.start(function(client)
    dual.notify(("%s %s, model %s, session %s"):format(
      "xia", client.version, client.model, client.session))
  end)
end

return M
