-- The annotation: the answer, below the code it is about.
--
-- It is virtual text, so it never touches the buffer. It sits under the
-- selection, it grows as the answer arrives, and the user can throw it
-- away without touching the conversation.

local M = {}

local ns = vim.api.nvim_create_namespace("dual.annotation")

-- The annotations that are there: a scope and the mark that holds it.
M.notes = {}

local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- The lines of the annotation, as they are now.
local function note_lines(note)
  local scope = require("dual.scope")
  local lines = scope.lines(note.scope)
  local out = {}
  if note.state == "working" then
    table.insert(out, { { "dual " .. note.spinner, "DualDim" } })
  end
  for _, line in ipairs(note.answer) do
    table.insert(out, { { line, "DualAssistant" } })
  end
  return out, lines
end

--- Draws an annotation.
local function draw(note)
  local scope = require("dual.scope")
  local range = scope.range(note.scope)
  if range == nil then
    return
  end
  local lines = note_lines(note)
  local virt = {}
  for _, line in ipairs(lines) do
    table.insert(virt, line)
  end
  pcall(function()
    vim.api.nvim_buf_set_extmark(note.scope.buf, ns, range.end_row, 0, {
      virt_lines = virt,
      virt_lines_above = false,
    })
  end)
end

--- Starts an annotation for a scope: the spinner, and then the answer.
-- @param scope table: the scope the answer belongs to
function M.begin(scope)
  local note = {
    scope = scope,
    answer = {},
    state = "working",
    spinner = SPINNER[1],
    tick = 0,
  }
  table.insert(M.notes, note)

  -- The spinner turns while the agent works.
  local timer = vim.uv.new_timer()
  note.timer = timer
  timer:start(100, 100, function()
    vim.schedule(function()
      if note.state ~= "working" then
        return
      end
      note.tick = note.tick + 1
      note.spinner = SPINNER[(note.tick % #SPINNER) + 1]
      draw(note)
    end)
  end)

  draw(note)
  return note
end

--- The answer of an annotation grows.
function M.grow(note, text)
  if note == nil then
    return
  end
  note.state = "answered"
  note.answer = vim.split(text or "", "\n", { plain = true })
  draw(note)
end

--- Throws an annotation away.
function M.dismiss(note)
  if note == nil then
    return
  end
  if note.timer ~= nil then
    pcall(function()
      note.timer:stop()
      note.timer:close()
    end)
    note.timer = nil
  end
  for i, n in ipairs(M.notes) do
    if n == note then
      table.remove(M.notes, i)
      break
    end
  end
  if note.scope ~= nil and vim.api.nvim_buf_is_valid(note.scope.buf) then
    pcall(function()
      vim.api.nvim_buf_clear_namespace(note.scope.buf, ns, 0, -1)
    end)
  end
  require("dual.scope").release(note.scope)
end

--- Throws every annotation away.
function M.dismiss_all()
  local notes = {}
  for i, note in ipairs(M.notes) do
    notes[i] = note
  end
  for _, note in ipairs(notes) do
    M.dismiss(note)
  end
  M.notes = {}
end

return M
