-- The scoped requests: change this, and insert here.
--
-- These are the requests where the user has said exactly where the
-- change belongs. The scope travels with the request, so the agent knows
-- what "this" is, and it travels with the review, so the change is
-- judged against the request that asked for it.

local M = {}

--- Asks for a change to the visual selection.
function M.run()
  local dual = require("dual")
  local scope = require("dual.scope")
  local prompt = require("dual.ui.prompt")

  local captured, reason = scope.capture()
  if captured == nil then
    dual.notify("dual: " .. (reason or "there is no selection"),
      vim.log.levels.WARN)
    return
  end

  prompt.capture({
    title = " change ",
    prompt = "",
    row = captured.start_row,
    col = vim.fn.col(".") - 1,
  }, function(text)
    M.ask(captured, text, "change")
  end)
end

--- Asks for code at the cursor.
function M.insert()
  local dual = require("dual")
  local scope = require("dual.scope")
  local prompt = require("dual.ui.prompt")

  local captured = scope.capture_cursor()
  prompt.capture({
    title = " insert ",
    prompt = "",
    row = captured.start_row,
    col = vim.fn.col(".") - 1,
  }, function(text)
    M.ask(captured, text, "insert")
  end)
end

--- Asks the agent about a scope.
--
-- The buffers go first, so the agent reads what the user sees. The scope
-- is remembered for the turn: the change that comes back is reviewed
-- against it.
--
-- @param captured table: the scope
-- @param question string: what the user asked
-- @param kind string: "change" or "insert"
function M.ask(captured, question, kind)
  local dual = require("dual")
  local scope = require("dual.scope")
  local buffers = require("dual.buffers")

  -- The server comes first: the buffers can only be pushed to a server
  -- that is there.
  dual.start(function(session)
    buffers.sync(function()
      -- The scope is remembered for the turn: the change that comes
      -- back is reviewed against it.
      dual.state.scope = captured
      session:send(scope.prompt(captured, question, kind))
    end)
  end)
end

return M
