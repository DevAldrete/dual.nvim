-- The files of the project.
--
-- A mention is a path, and the path has to be one the agent can read.
-- The plugin owns the buffers, so the agent reads the *live* buffer, not
-- the file on the disk: a mention only has to name the path.

local M = {}

-- The files, and when they were looked for.
M.cache = nil
M.cached_at = 0

-- How long the list is good for, in milliseconds.
local TTL = 5000

-- How many files the completion offers.
local MAX = 200

--- The files of the project, relative to the root.
function M.all()
  local now = vim.uv.now()
  if M.cache ~= nil and (now - M.cached_at) < TTL then
    return M.cache
  end

  local dual = require("dual")
  local cfg = dual.state.cfg
  local root = cfg and require("dual.server").cwd(cfg) or vim.fn.getcwd()

  local files = {}
  local ok = pcall(function()
    for name, kind in vim.fs.dir(root, { depth = 12 }) do
      if kind == "file" then
        local rel = vim.fn.fnamemodify(name, ":.")
        if rel ~= "" and not rel:match("^%.") then
          files[#files + 1] = rel
        end
      end
    end
  end)
  if not ok then
    files = {}
  end
  table.sort(files)

  M.cache = files
  M.cached_at = now
  return files
end

--- The files that match what the user has typed.
function M.complete(word)
  word = word or ""
  local out = {}
  local needle = word:lower()
  for _, path in ipairs(M.all()) do
    if needle == "" or path:lower():find(needle, 1, true) then
      out[#out + 1] = path
      if #out >= MAX then
        break
      end
    end
  end
  return out
end

--- The mentions of a text, and the text without them.
--
-- A mention is a path: the agent reads it itself, so nothing is pasted
-- and nothing goes stale.
--
-- @param text string: what the user wrote
-- @return string: the text for the agent
-- @return table: the paths that were mentioned
function M.expand(text)
  local paths = {}
  local out = text:gsub("@([%w%._/%-]+)", function(path)
    paths[#paths + 1] = path
    return path
  end)
  if #paths == 0 then
    return out, paths
  end

  local lines = { out, "", "<dual_mentions>" }
  for _, path in ipairs(paths) do
    lines[#lines + 1] = path
  end
  lines[#lines + 1] = "</dual_mentions>"
  return table.concat(lines, "\n"), paths
end

return M
