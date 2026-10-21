-- The quickfix list.
--
-- When the agent greps, the results are the answer, and the user wants
-- them in a list they can walk. The list is built from the tool's
-- *output*, not from the prose around it: the plugin reads the results
-- the way the agent's own tools do, and the model's summary stays a
-- summary.

local M = {}

--- Listens to the client: the results of a search fill the list.
function M.listen(client)
  client:on("tool_result", function(ev)
    if ev.is_error == true then
      return
    end
    if ev.name == "grep" then
      M.from_grep(ev.output or "")
    elseif ev.name == "glob" then
      M.from_glob(ev.output or "")
    end
  end)
end

--- The items of a grep: "path:line: text".
function M.from_grep(output)
  local items = {}
  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    local path, number, text = line:match("^(.-):(%d+):(.*)$")
    if path ~= nil then
      items[#items + 1] = {
        filename = path,
        lnum = tonumber(number),
        col = 1,
        text = text,
      }
    end
  end
  if #items > 0 then
    M.set(items, ("%d match%s"):format(#items, #items == 1 and "" or "es"))
  end
  return items
end

--- The items of a glob: one path per line.
function M.from_glob(output)
  local items = {}
  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    if line ~= "" and not line:match("^%(") and not line:match("^%d+ match") then
      items[#items + 1] = {
        filename = line,
        lnum = 1,
        col = 1,
        text = line,
      }
    end
  end
  if #items > 0 then
    M.set(items, ("%d file%s"):format(#items, #items == 1 and "" or "s"))
  end
  return items
end

--- Puts the items in the quickfix list, and says so in the chat.
function M.set(items, what)
  vim.fn.setqflist({}, " ", {
    title = "dual",
    items = items,
  })
  local chat = require("dual.ui.chat")
  chat.append("system", "accent", ("%s — :copen to walk them"):format(what))
end

return M
