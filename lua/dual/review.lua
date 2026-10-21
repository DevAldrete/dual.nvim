-- The review: what the agent changed, and what the user decides about it.
--
-- The agent writes whole files; the user decides about parts of them. A
-- change under review is a small table:
--
--     { path, buf, base, target, tick, scope, is_new }
--
-- `base` is what the plugin believes, `target` is what the agent wants.
-- Accepting a hunk moves the base toward the target; refusing a hunk
-- moves the target back toward the base. Either way the hunk is gone,
-- and the difference is recomputed against the truth — which is the
-- buffer, if the file has one.

local M = {}

local diff = require("dual.diff")

-- The changes that are waiting for a decision: path -> change.
M.changes = {}

--- The buffer of a path, if the file is open.
local function buffer_of(path)
  local name = vim.fn.fnamemodify(path, ":p")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local other = vim.api.nvim_buf_get_name(buf)
      if other ~= "" and vim.fn.fnamemodify(other, ":p") == name then
        return buf
      end
    end
  end
  return nil
end

--- The lines of a buffer.
local function buffer_lines(buf)
  if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

--- The tick of a buffer: it says whether the user moved under us.
local function buffer_tick(buf)
  if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  return vim.api.nvim_buf_get_changedtick(buf)
end

--- Records a change the agent made.
--
-- @param path string: the file, relative to the root
-- @param text string: what the agent wants the file to be
-- @param opts table: base (what the plugin believes), scope, is_new
-- @return table: the change
function M.record(path, text, opts)
  opts = opts or {}
  local buf = opts.buf or buffer_of(path)
  local base = opts.base
  if base == nil then
    base = buffer_lines(buf)
  end
  if base == nil then
    base = {}
  end

  local change = {
    path = path,
    buf = buf,
    is_new = opts.is_new or false,
    scope = opts.scope,
    base = base,
    target = diff.lines(text),
    tick = buffer_tick(buf),
    moved = false,
  }
  M.changes[path] = change
  return change
end

--- The change of a path.
function M.get(path)
  return M.changes[path]
end

--- The paths that are waiting, in order.
function M.paths()
  local out = {}
  for path in pairs(M.changes) do
    out[#out + 1] = path
  end
  table.sort(out)
  return out
end

--- Brings the belief up to date: the buffer is the truth.
--
-- The user may have edited the file while the agent worked. When they
-- did, the difference now includes their edit, and the window says so.
function M.sync(change)
  if change == nil then
    return
  end
  if change.buf == nil then
    change.buf = buffer_of(change.path)
  end
  local tick = buffer_tick(change.buf)
  local lines = buffer_lines(change.buf)
  if lines == nil then
    return
  end
  if change.tick ~= nil and tick ~= nil and tick ~= change.tick then
    change.moved = true
  end
  change.base = lines
  change.tick = tick
end

--- The hunks of a change, recomputed from the truth.
function M.hunks(change)
  if change == nil then
    return {}
  end
  return diff.hunks(diff.text(change.base), diff.text(change.target))
end

--- The hunks that are in question, and the ones that are not.
--
-- The scope of the request is the range the user pointed at. The hunks
-- that touch it are the ones the request is about; the others are
-- listed apart, and they wait.
function M.split(change)
  local hunks = M.hunks(change)
  if change.scope == nil or change.scope.path ~= change.path then
    return hunks, {}
  end
  local scope = require("dual.scope")
  local from, to = scope.lines(change.scope)
  return diff.split(hunks, from, to)
end

--- Writes a hunk's new lines into the buffer, as an undoable edit.
--
-- @param change table: the change
-- @param hunk table: the hunk to write
-- @param seed table|nil: what a file that is not open yet holds
local function write(change, hunk, seed)
  if change.buf == nil then
    -- The file is not open: the change opens it, with what the plugin
    -- believed, and then the hunk lands in it.
    local scope = require("dual.scope")
    change.buf = vim.fn.bufadd(scope.absolute(change.path))
    vim.fn.bufload(change.buf)
    vim.api.nvim_buf_set_lines(change.buf, 0, -1, false, seed or {})
  end
  local at = hunk.base_start - 1
  vim.api.nvim_buf_set_lines(change.buf, at, at + hunk.base_count, false, hunk.new)
end

--- Accepts a hunk: the base becomes the target there.
--
-- @param change table: the change
-- @param index number: which hunk, counting from one
-- @return boolean: whether there was a hunk to accept
function M.accept(change, index)
  if change == nil then
    return false
  end
  M.sync(change)
  local hunks = M.hunks(change)
  local hunk = hunks[index]
  if hunk == nil then
    return false
  end

  local seed = change.base
  change.base = diff.accept(change.base, hunk)
  write(change, hunk, seed)
  change.tick = buffer_tick(change.buf)
  M.after(change)
  return true
end

--- Refuses a hunk: the target stops asking for it.
function M.refuse(change, index)
  if change == nil then
    return false
  end
  M.sync(change)
  local hunks = M.hunks(change)
  local hunk = hunks[index]
  if hunk == nil then
    return false
  end

  change.target = diff.refuse(change.target, hunk)
  M.after(change)
  return true
end

--- Accepts every hunk.
function M.accept_all(change)
  if change == nil then
    return
  end
  while true do
    local hunks = M.hunks(change)
    if #hunks == 0 then
      break
    end
    if not M.accept(change, 1) then
      break
    end
  end
end

--- Refuses every hunk.
function M.refuse_all(change)
  if change == nil then
    return
  end
  while true do
    local hunks = M.hunks(change)
    if #hunks == 0 then
      break
    end
    if not M.refuse(change, 1) then
      break
    end
  end
end

--- After a decision: what the plugin believes, and whether it is over.
function M.after(change)
  local buffers = require("dual.buffers")
  local hunks = M.hunks(change)
  if #hunks == 0 then
    -- Every hunk is decided: the buffer is the truth now.
    buffers.pending[change.path] = nil
    M.changes[change.path] = nil
    return
  end
  -- The change is still open: what the plugin believes is what the agent
  -- wants, minus what was refused.
  buffers.pending[change.path] = diff.text(change.target)
end

--- Forgets a change: the user threw it away.
function M.forget(path)
  local change = M.changes[path]
  if change == nil then
    return
  end
  M.changes[path] = nil
  local buffers = require("dual.buffers")
  buffers.pending[path] = nil
end

return M
