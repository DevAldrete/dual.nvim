-- The sessions picker.
--
-- The store holds the conversations that were saved. The server answers
-- `{"cmd":"sessions"}` with the list, and the user picks one to go back
-- to.

local M = {}

--- Asks the user for a session, and resumes it.
function M.run()
  local dual = require("dual")

  dual.start(function(session)
    local client = session.client
    if not client:has("sessions") then
      dual.notify("dual: this server does not know the sessions",
        vim.log.levels.WARN)
      return
    end

    client:request("sessions", {}, function(reply)
      if reply == nil or reply.ok ~= true then
        dual.notify("dual: the server did not answer with the sessions",
          vim.log.levels.WARN)
        return
      end

      local items = {}
      for _, saved in ipairs(reply.sessions or {}) do
        local name = saved.title or saved.id or "?"
        if saved.updated_at ~= nil and saved.updated_at > 0 then
          name = name .. ("  ·  %s"):format(
            os.date("%Y-%m-%d %H:%M", saved.updated_at))
        end
        if saved.messages ~= nil and saved.messages > 0 then
          name = name .. ("  ·  %d messages"):format(saved.messages)
        end
        items[#items + 1] = { name = name, session = saved }
      end

      if #items == 0 then
        dual.notify("dual: the store holds no sessions")
        return
      end

      vim.ui.select(items, {
        prompt = "the session",
        format_item = function(item)
          return item.name
        end,
      }, function(choice)
        if choice == nil then
          return
        end
        client:request("resume", { spec = choice.session.id }, function(answer)
          if answer == nil or answer.ok ~= true then
            dual.notify(("dual: the server refused the session: %s"):format(
              (answer or {}).error or "?"), vim.log.levels.WARN)
            return
          end
          local chat = require("dual.ui.chat")
          chat.append("system", "accent",
            ("the conversation is now %s"):format(choice.session.title
              or choice.session.id))
        end)
      end)
    end)
  end)
end

return M
