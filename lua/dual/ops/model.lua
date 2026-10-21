-- The model picker.
--
-- The plugin does not know what models exist and does not want to: xia
-- does. The server answers `{"cmd":"models"}` with the catalog, and the
-- user picks one.
--
-- The picker is `vim.ui.select`, so the user's own picker takes over.

local M = {}

--- Asks the user for a model, and gives it to the server.
function M.run()
  local dual = require("dual")

  dual.start(function(session)
    local client = session.client
    if not client:has("models") then
      dual.notify("dual: this server does not know the models",
        vim.log.levels.WARN)
      return
    end

    client:request("models", {}, function(reply)
      if reply == nil or reply.ok ~= true then
        dual.notify("dual: the server did not answer with the models",
          vim.log.levels.WARN)
        return
      end

      local items = {}
      for _, model in ipairs(reply.models or {}) do
        local name = ("%s/%s"):format(model.provider or "?", model.model or "?")
        if model.name ~= nil and model.name ~= "" and model.name ~= model.model then
          name = name .. "  ·  " .. model.name
        end
        if model.context_window ~= nil and model.context_window > 0 then
          name = name .. ("  ·  %dk"):format(math.floor(model.context_window / 1000))
        end
        if model.active == true then
          name = "* " .. name
        end
        items[#items + 1] = { name = name, model = model }
      end

      if #items == 0 then
        dual.notify("dual: the server knows no models")
        return
      end

      vim.ui.select(items, {
        prompt = "the model",
        format_item = function(item)
          return item.name
        end,
      }, function(choice)
        if choice == nil then
          return
        end
        local wanted = ("%s/%s"):format(
          choice.model.provider, choice.model.model)
        client:request("model", { model = wanted }, function(answer)
          if answer == nil or answer.ok ~= true then
            dual.notify(("dual: the server refused the model: %s"):format(
              (answer or {}).error or "?"), vim.log.levels.WARN)
            return
          end
          local chat = require("dual.ui.chat")
          chat.append("system", "accent", ("the model is now %s"):format(wanted))
        end)
      end)
    end)
  end)
end

return M
