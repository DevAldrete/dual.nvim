-- The keys, from the editor.
--
-- The provider is a choice and the key belongs to that choice. The
-- server keeps the keys; this asks it which providers there are, asks
-- for the key in a prompt that hides it, and gives it to the server.
--
-- The key never goes near the transcript, the command line or the
-- environment.

local M = {}

--- Asks the user for a provider, and for the key that belongs to it.
function M.run()
  local dual = require("dual")

  dual.start(function(session)
    local client = session.client
    if not client:has("auth") then
      dual.notify("dual: this server does not know about the keys",
        vim.log.levels.WARN)
      return
    end

    client:request("auth", {}, function(reply)
      if reply == nil or reply.ok ~= true then
        dual.notify("dual: the server did not answer about the keys",
          vim.log.levels.WARN)
        return
      end

      local items = {}
      for _, provider in ipairs(reply.providers or {}) do
        local name = provider.provider or "?"
        if provider.name ~= nil and provider.name ~= "" then
          name = name .. "  ·  " .. provider.name
        end
        if provider.has_key == true then
          name = "* " .. name
        end
        items[#items + 1] = { name = name, provider = provider.provider }
      end

      if #items == 0 then
        dual.notify("dual: the server knows no providers")
        return
      end

      vim.ui.select(items, {
        prompt = "the provider",
        format_item = function(item)
          return item.name
        end,
      }, function(choice)
        if choice == nil then
          return
        end
        M.ask_key(choice.provider, choice.name)
      end)
    end)
  end)
end

--- Asks for the key, hidden, and gives it to the server.
-- @param provider string: the provider the key belongs to
-- @param label string: how the provider is named in the list
function M.ask_key(provider, label)
  local prompt = require("dual.ui.prompt")
  local dual = require("dual")

  local has_key = label ~= nil and label:sub(1, 2) == "* "
  prompt.capture({
    title = " the key ",
    prompt = has_key
      and ("the key for " .. provider .. " (empty forgets it)")
      or ("the key for " .. provider),
    secret = true,
    allow_empty = has_key,
  }, function(key)
    local client = dual.state.client
    if client == nil then
      return
    end
    local request = { provider = provider }
    if key == "" then
      request.remove = true
    else
      request.key = key
    end
    client:request("auth", request, function(reply)
      if reply == nil or reply.ok ~= true then
        dual.notify("dual: the server did not take the key",
          vim.log.levels.WARN)
        return
      end
      local chat = require("dual.ui.chat")
      if key == "" then
        chat.append("system", "accent",
          ("the key for %s is forgotten"):format(provider))
      else
        chat.append("system", "accent",
          ("the key for %s is remembered"):format(provider))
      end
    end)
  end)
end

return M
