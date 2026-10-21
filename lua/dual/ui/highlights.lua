-- The highlights of the plugin.
--
-- They link to the groups the user's colorscheme already has, so the
-- chat keeps the colors of the editor and nothing is hard-coded.

local M = {}

local function link(name, target, opts)
  vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", {
    default = true,
    link = target,
  }, opts or {}))
end

function M.setup()
  -- The conversation.
  link("DualUser", "Title")
  link("DualAssistant", "Normal")
  link("DualTool", "Comment")
  link("DualSystem", "Comment")
  link("DualDim", "Comment")
  link("DualAccent", "Constant")

  -- The diffs.
  link("DualAdd", "DiffAdd")
  link("DualDel", "DiffDelete")
  link("DualHunk", "DiffChange")
  link("DualError", "ErrorMsg")

  -- The surfaces.
  link("DualHeader", "Title", { bold = true })
  link("DualInput", "Normal")
  link("DualPending", "WarningMsg")
end

--- The group of a line of the transcript.
function M.for_line(role, style)
  if style == "add" then
    return "DualAdd"
  elseif style == "del" then
    return "DualDel"
  elseif style == "hunk" then
    return "DualHunk"
  elseif style == "error" then
    return "DualError"
  elseif style == "dim" then
    return "DualDim"
  elseif style == "accent" then
    return "DualAccent"
  end
  if role == "user" then
    return "DualUser"
  elseif role == "tool" then
    return "DualTool"
  elseif role == "system" then
    return "DualSystem"
  end
  return "DualAssistant"
end

return M
