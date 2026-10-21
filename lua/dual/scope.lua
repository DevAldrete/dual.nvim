-- The scope of a request: what the user pointed at.
--
-- A scope is a range in a buffer, and it is held by two extmarks, so it
-- follows the edits the user makes while the agent works. The answer
-- lands where the code is, not where the code was.

local M = {}

local ns = vim.api.nvim_create_namespace("dual.scope")

--- The file of a buffer, relative to the root the server runs in.
function M.path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == nil or name == "" then
    return nil
  end
  local root = require("dual").state.cfg
  local cwd = root and require("dual.server").cwd(root) or vim.fn.getcwd()
  local full = vim.fn.fnamemodify(name, ":p")
  local rel = vim.fn.fnamemodify(full, ":." )
  local prefix = vim.fn.fnamemodify(cwd, ":p")
  if prefix:sub(-1) ~= "/" then
    prefix = prefix .. "/"
  end
  if full:sub(1, #prefix) == prefix then
    rel = full:sub(#prefix + 1)
  end
  return rel
end

--- The scope of the visual selection, or of the last one.
-- @return table|nil: the scope, or nil and a reason
function M.capture()
  local buf = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  local visual = (mode == "v" or mode == "V" or mode == "\22")

  local a, b
  if visual then
    a = vim.fn.getpos("v")
    b = vim.fn.getpos(".")
  else
    a = vim.fn.getpos("'<")
    b = vim.fn.getpos("'>")
  end

  if a[2] == 0 or b[2] == 0 then
    return nil, "there is no selection"
  end

  -- The selection may run backwards.
  local first, last = a, b
  if b[2] < a[2] or (b[2] == a[2] and b[3] < a[3]) then
    first, last = b, a
  end

  local linewise = (mode == "V") or (not visual and vim.fn.visualmode() == "V")
  local start_row = first[2] - 1
  local end_row = last[2] - 1
  local start_col = first[3] - 1
  local end_col = last[4] - 1
  if linewise then
    start_col = 0
    end_col = -1
  end

  local text = ""
  pcall(function()
    local lines = vim.api.nvim_buf_get_text(buf, start_row, start_col, end_row,
      end_col, {})
    text = table.concat(lines, "\n")
  end)
  if text == "" then
    return nil, "the selection is empty"
  end

  local start_mark = vim.api.nvim_buf_set_extmark(buf, ns, start_row, start_col, {})
  local end_mark = vim.api.nvim_buf_set_extmark(buf, ns, end_row,
    end_col < 0 and 0 or end_col, {})

  return {
    buf = buf,
    path = M.path(buf),
    text = text,
    start_row = start_row,
    end_row = end_row,
    start_col = start_col,
    end_col = end_col,
    linewise = linewise,
    start_mark = start_mark,
    end_mark = end_mark,
    saved = vim.bo[buf].modified,
  }
end

--- The range of a scope, as it is now: the marks follow the edits.
function M.range(scope)
  local buf = scope.buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  local start = vim.api.nvim_buf_get_extmark_by_id(buf, ns, scope.start_mark, {})
  local last = vim.api.nvim_buf_get_extmark_by_id(buf, ns, scope.end_mark, {})
  if #start < 2 or #last < 2 then
    return nil
  end
  return {
    start_row = start[1],
    start_col = start[2],
    end_row = last[1],
    end_col = last[2],
  }
end

--- The text of a scope, as it is now.
function M.text(scope)
  local range = M.range(scope)
  if range == nil then
    return scope.text
  end
  local text = ""
  pcall(function()
    local lines = vim.api.nvim_buf_get_text(scope.buf, range.start_row,
      range.start_col, range.end_row, range.end_col, {})
    text = table.concat(lines, "\n")
  end)
  if text == "" then
    return scope.text
  end
  return text
end

--- The lines a scope covers, as they are now.
function M.lines(scope)
  local range = M.range(scope)
  if range == nil then
    return scope.start_row + 1, scope.end_row + 1
  end
  return range.start_row + 1, range.end_row + 1
end

--- The request the agent receives: the scope, and the question.
function M.prompt(scope, question)
  local from, to = M.lines(scope)
  local header = ("<dual_context file=%q lines=\"%d-%d\" saved=%q>"):format(
    scope.path or "?", from, to, scope.saved and "true" or "false")
  return table.concat({
    header,
    scope.text,
    "</dual_context>",
    "",
    question or "",
  }, "\n")
end

--- Forgets a scope: the marks go, and the annotation with them.
function M.release(scope)
  if scope == nil or not vim.api.nvim_buf_is_valid(scope.buf) then
    return
  end
  pcall(function()
    vim.api.nvim_buf_del_extmark(scope.buf, ns, scope.start_mark)
    vim.api.nvim_buf_del_extmark(scope.buf, ns, scope.end_mark)
  end)
end

return M
