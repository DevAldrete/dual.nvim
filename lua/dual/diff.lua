-- The diff engine.
--
-- The agent edits whole files; the user decides about parts of them. This
-- turns one whole file into the hunks a diff shows, and it turns a
-- decision about a hunk into an edit.
--
-- The comparison is Neovim's own (`vim.diff`), so there is nothing to
-- install and nothing to shell out to. The notation is a git diff's,
-- because that is the notation everybody reads.

local M = {}

--- The lines of a text.
function M.lines(text)
  return vim.split(text or "", "\n", { plain = true })
end

--- The text of a list of lines.
function M.text(lines)
  return table.concat(lines, "\n")
end

--- The hunks between two texts.
--
-- A hunk knows both of its sides: the lines it replaces and the lines
-- that replace them. That is what makes a decision symmetric — accepting
-- moves the base toward the target, refusing moves the target back.
--
-- @param base string: the text the plugin believes
-- @param target string: the text the agent wants
-- @param context number: how many context lines a hunk carries
-- @return table: the hunks, in the order they appear
function M.hunks(base, target, context)
  context = context or 3
  local old = M.lines(base)
  local new = M.lines(target)

  -- Neovim's difference says where the lines change: a start and a count
  -- for each side.
  local changes = vim.diff(base, target, { result_type = "indices" })
  local hunks = {}
  local group = nil

  for _, change in ipairs(changes) do
    local a_start, a_count = change[1], change[2]
    local b_start, b_count = change[3], change[4]

    -- The context reaches back and forward; two changes whose contexts
    -- touch are one hunk, not two.
    local from = math.max(1, a_start - context)
    local to = math.min(#old, a_start + a_count - 1 + context)
    if group ~= nil and from <= group.old_to + 1 and b_start <= group.new_to + 1 then
      group.changes[#group.changes + 1] = change
      group.old_to = math.max(group.old_to, a_start + a_count - 1)
      group.new_to = math.max(group.new_to, b_start + b_count - 1)
      group.old_from = math.min(group.old_from, from)
    else
      group = {
        changes = { change },
        old_from = from,
        old_to = to,
        new_from = math.max(1, b_start - context),
        new_to = math.min(#new, b_start + b_count - 1 + context),
      }
      hunks[#hunks + 1] = group
    end
  end

  for _, hunk in ipairs(hunks) do
    M.fill(hunk, old, new)
  end
  return hunks
end

--- Fills a hunk with both of its sides, and with the lines a diff shows.
function M.fill(hunk, old, new)
  local old_lines = {}
  local new_lines = {}
  local shown = {}

  local old_at = hunk.old_from
  local new_at = hunk.new_from

  for _, change in ipairs(hunk.changes) do
    -- The context before the change.
    while old_at < change[1] do
      local line = old[old_at] or ""
      old_lines[#old_lines + 1] = line
      new_lines[#new_lines + 1] = line
      shown[#shown + 1] = { type = "context", text = line }
      old_at = old_at + 1
      new_at = new_at + 1
    end
    -- The lines that go, and the lines that come.
    for i = change[1], change[1] + change[2] - 1 do
      local line = old[i] or ""
      old_lines[#old_lines + 1] = line
      shown[#shown + 1] = { type = "del", text = line }
    end
    for i = change[3], change[3] + change[4] - 1 do
      local line = new[i] or ""
      new_lines[#new_lines + 1] = line
      shown[#shown + 1] = { type = "add", text = line }
    end
    old_at = change[1] + change[2]
    new_at = change[3] + change[4]
  end

  -- The context after the last change.
  local after = math.min(#new, hunk.new_to)
  while new_at <= after do
    local line = new[new_at] or ""
    old_lines[#old_lines + 1] = line
    new_lines[#new_lines + 1] = line
    shown[#shown + 1] = { type = "context", text = line }
    new_at = new_at + 1
    old_at = old_at + 1
  end

  hunk.old = old_lines
  hunk.new = new_lines
  hunk.lines = shown
  hunk.base_start = hunk.old_from
  hunk.base_count = #old_lines
  hunk.target_start = hunk.new_from
  hunk.target_count = #new_lines
  return hunk
end

--- The header of a hunk, the way a diff writes it.
function M.header(hunk)
  -- A count of one is left out, the way a diff writes it.
  local function side(start, count)
    if count == 1 then
      return tostring(start)
    end
    return ("%d,%d"):format(start, count)
  end
  return ("@@ -%s +%s @@"):format(
    side(hunk.base_start, hunk.base_count),
    side(hunk.target_start, hunk.target_count)
  )
end

--- The lines of a hunk, as a diff writes them.
function M.render(hunk)
  local out = { M.header(hunk) }
  for _, line in ipairs(hunk.lines) do
    local sign = " "
    if line.type == "del" then
      sign = "-"
    elseif line.type == "add" then
      sign = "+"
    end
    out[#out + 1] = sign .. line.text
  end
  return out
end

--- The whole difference, as a diff writes it.
function M.unified(base, target, path)
  local out = {}
  if path ~= nil and path ~= "" then
    out[#out + 1] = "--- a/" .. path
    out[#out + 1] = "+++ b/" .. path
  end
  for _, hunk in ipairs(M.hunks(base, target)) do
    for _, line in ipairs(M.render(hunk)) do
      out[#out + 1] = line
    end
  end
  return out
end

--- Takes a hunk into the base: the base becomes the target there.
function M.accept(base_lines, hunk)
  local out = {}
  for i = 1, hunk.base_start - 1 do
    out[#out + 1] = base_lines[i]
  end
  for _, line in ipairs(hunk.new) do
    out[#out + 1] = line
  end
  for i = hunk.base_start + hunk.base_count, #base_lines do
    out[#out + 1] = base_lines[i]
  end
  return out
end

--- Takes the base's version of a hunk into the target: the hunk is
--- refused, and the target stops asking for it.
function M.refuse(target_lines, hunk)
  local out = {}
  for i = 1, hunk.target_start - 1 do
    out[#out + 1] = target_lines[i]
  end
  for _, line in ipairs(hunk.old) do
    out[#out + 1] = line
  end
  for i = hunk.target_start + hunk.target_count, #target_lines do
    out[#out + 1] = target_lines[i]
  end
  return out
end

--- Does a hunk touch a range of lines?
--
-- The range is counted from 1, the way a person counts lines.
function M.touches(hunk, from, to)
  if from == nil or to == nil then
    return true
  end
  local first = hunk.base_start
  local last = hunk.base_start + hunk.base_count - 1
  return first <= to and last >= from
end

--- The hunks that touch a range, and the ones that do not.
function M.split(hunks, from, to)
  local inside = {}
  local outside = {}
  for _, hunk in ipairs(hunks) do
    if M.touches(hunk, from, to) then
      inside[#inside + 1] = hunk
    else
      outside[#outside + 1] = hunk
    end
  end
  return inside, outside
end

return M
