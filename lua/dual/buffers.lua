-- The files: the buffers the agent works on.
--
-- The plugin pushes the buffers it owns before every turn, so the agent
-- reads what the user sees — the live buffer, unsaved changes and all.
-- What the agent changes comes back, and waits: a change the user has
-- not decided about is *pending*, and it is pending until the review
-- says otherwise.

local M = {}

-- The changes the agent made that the user has not decided about:
-- path -> the content the agent wants.
M.pending = {}

--- The buffers the plugin owns, by the policy of the configuration.
function M.owned()
  local cfg = require("dual.config").values
  local mode = (cfg.files or {}).sync or "loaded"

  if mode == "current" then
    local buf = vim.api.nvim_get_current_buf()
    return { buf }
  end

  local out = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buflisted ~= false
        and vim.api.nvim_buf_get_name(buf) ~= "" then
      if mode ~= "modified" or vim.bo[buf].modified then
        table.insert(out, buf)
      end
    end
  end
  return out
end

--- The files to push: the pending changes, and the buffers.
function M.payload()
  local scope = require("dual.scope")
  local cfg = require("dual.config").values
  local max = (cfg.files or {}).max_size or (512 * 1024)

  local files = {}
  -- A pending change is what the plugin believes about that file, so it
  -- wins over the buffer: pushing the buffer would lose the change.
  for path, content in pairs(M.pending) do
    files[path] = content
  end

  for _, buf in ipairs(M.owned()) do
    local path = scope.path(buf)
    if path ~= nil and files[path] == nil then
      local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      if #content <= max then
        files[path] = content
      end
    end
  end
  return files
end

--- Pushes the files to the server.
-- @param cb function: called with the reply
function M.sync(cb)
  local dual = require("dual")
  local client = dual.state.client
  if client == nil then
    if cb then
      cb(nil)
    end
    return
  end
  client:request("sync", { files = M.payload() }, function(reply)
    if reply ~= nil and reply.ok == true and reply.refused ~= nil then
      for _, item in ipairs(reply.refused) do
        dual.notify(("dual: %s was not sent: %s"):format(
          item.path or "?", item.reason or "it leaves the root"))
      end
    end
    if cb then
      cb(reply)
    end
  end)
end

--- Listens to the client: a change the agent made waits for the user.
function M.listen(client)
  client:on("file_changed", function(ev)
    M.on_change(ev.path, ev.text or "")
    local dual = require("dual")
    dual.notify(("dual: the agent changed %s; it waits for you"):format(
      ev.path or "a file"))
  end)
end

--- A change the agent made: it waits for the user.
function M.on_change(path, content)
  if path == nil then
    return
  end
  M.pending[path] = content
end

--- A change the user accepted: the pending change is the buffer's now.
function M.accept(path)
  M.pending[path] = nil
end

--- A change the user threw away: the buffer's version is the truth.
function M.reject(path)
  M.pending[path] = nil
end

--- The paths that are waiting.
function M.pending_paths()
  local out = {}
  for path in pairs(M.pending) do
    table.insert(out, path)
  end
  table.sort(out)
  return out
end

return M
