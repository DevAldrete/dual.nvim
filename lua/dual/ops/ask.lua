-- The quick ask: ask about the code under the cursor.
--
-- The selection defines the question. The answer lands below the code,
-- in the buffer, and the code is not touched.

local M = {}

--- Asks about the visual selection.
function M.run()
  local dual = require("dual")
  local scope = require("dual.scope")
  local prompt = require("dual.ui.prompt")
  local annotation = require("dual.ui.annotation")

  local captured, reason = scope.capture()
  if captured == nil then
    dual.notify("dual: " .. (reason or "there is no selection"),
      vim.log.levels.WARN)
    return
  end

  local row = captured.start_row
  local col = vim.fn.col(".") - 1
  prompt.capture({
    title = " ask ",
    prompt = "",
    row = row,
    col = col,
  }, function(question)
    M.ask(captured, question)
  end)
end

--- Asks the agent about a scope.
-- @param captured table: the scope
-- @param question string: what the user asked
function M.ask(captured, question)
  local dual = require("dual")
  local scope = require("dual.scope")
  local buffers = require("dual.buffers")
  local annotation = require("dual.ui.annotation")

  -- The server comes first: the buffers can only be pushed to a server
  -- that is there.
  dual.start(function(session)
    -- The agent reads what the user sees: the buffers go first.
    buffers.sync(function()
      local note = annotation.begin(captured)

      -- The answer grows in the annotation as it arrives, and lands
      -- whole when the turn ends.
      session.client:on("text", function()
        if not note.done then
          annotation.grow(note, session:answer_text())
        end
      end)
      session.client:on("message", function(ev)
        if not note.done then
          annotation.grow(note, ev.text or session:answer_text())
        end
      end)
      session.client:on("run_end", function()
        note.done = true
      end)

      session:send(scope.prompt(captured, question, "ask"))
    end)
  end)
end

return M
