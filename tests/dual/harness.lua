-- The test harness: assertions that say what they checked.
--
-- The tests are plain Lua scripts run by `nvim --headless -u NONE -l`, so
-- they need nothing but Neovim. That is the same discipline the runtime
-- keeps: a test that cannot run anywhere is a test that stops running.

local M = {
  checks = 0,
  failures = 0,
  name = "the test",
}

--- The name of the group of checks.
function M.group(name)
  M.name = name
  print("-- " .. name)
end

--- Two values are the same.
function M.eq(expected, got, what)
  M.checks = M.checks + 1
  if expected ~= got then
    M.failures = M.failures + 1
    print(string.format("FAIL: %s: %s -- expected %s, got %s", M.name,
      what or "?", vim.inspect(expected), vim.inspect(got)))
    return false
  end
  print(string.format("ok: %s: %s", M.name, what or "?"))
  return true
end

--- A value is true.
function M.ok(value, what)
  return M.eq(true, value and true or false, what)
end

--- A value is nil.
function M.is_nil(value, what)
  return M.eq(nil, value, what)
end

--- A string holds a piece of text.
function M.contains(haystack, needle, what)
  M.checks = M.checks + 1
  if type(haystack) ~= "string" or not haystack:find(needle, 1, true) then
    M.failures = M.failures + 1
    print(string.format("FAIL: %s: %s -- %q is not in %q", M.name,
      what or "?", needle, tostring(haystack)))
    return false
  end
  print(string.format("ok: %s: %s", M.name, what or "?"))
  return true
end

--- Ends the run: the exit code says whether everything passed.
function M.report()
  print(string.format("%d checks, %d failures", M.checks, M.failures))
  if M.failures > 0 then
    os.exit(1)
  end
  os.exit(0)
end

--- Waits for a condition, up to a timeout in milliseconds.
function M.wait_for(fn, timeout)
  timeout = timeout or 5000
  local waited = 0
  while waited < timeout do
    if fn() then
      return true
    end
    vim.wait(20, function()
      return false
    end)
    waited = waited + 20
  end
  return false
end

return M
