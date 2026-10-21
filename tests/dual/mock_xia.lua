-- A stand-in for `xia --serve`.
--
-- It speaks the protocol well enough for the tests, and nothing else:
-- the greeting, a turn that answers, and the replies that have answers.
-- The plugin's tests never need the real binary.

local answer = "the answer"
local capabilities = {
  "send",
  "steer",
  "answer",
  "cancel",
  "continue",
  "sync",
  "status",
  "save",
  "resume",
  "quit",
  "models",
  "model",
  "sessions",
}

-- The arguments: the answer the mock gives, and the capabilities it
-- claims.
for i, a in ipairs(_G.arg or {}) do
  if i == 1 then
    answer = a
  elseif i == 2 then
    capabilities = vim.split(a, ",", { plain = true })
  end
end

local function write(msg)
  io.write(vim.json.encode(msg) .. "\n")
  io.flush()
end

write({
  event = "hello",
  version = "0.0.0-mock",
  model = "mock/m",
  session = "mock-session",
  capabilities = capabilities,
})

while true do
  local line = io.read("l")
  if line == nil then
    break
  end
  line = line:gsub("\r$", "")
  if line ~= "" then
    local ok, req = pcall(vim.json.decode, line)
    if ok and type(req) == "table" then
      local cmd = req.cmd or ""
      if cmd == "quit" then
        write({ id = req.id, ok = true })
        break
      elseif cmd == "send" then
        write({ id = req.id, ok = true })
        write({ event = "run_start" })
        write({ event = "line", role = "user", style = "plain", text = req.text })
        -- A turn that asks for a change changes a file: the one it was
        -- pointed at, or the one it names.
        local changed = req.text:match('file="([^"]+)"')
          or req.text:match("^change%s+(%S+)")
        if changed ~= nil then
          write({
            event = "file_changed",
            path = changed,
            text = "int main(void) {\n  return 1;\n}\n",
            is_new = false,
          })
        end
        write({ event = "text", text = answer })
        write({ event = "message", text = answer })
        write({ event = "run_end", ok = true })
      elseif cmd == "status" then
        write({
          id = req.id,
          ok = true,
          status = {
            running = false,
            paused = false,
            model = "mock/m",
            session = "mock-session",
          },
        })
      elseif cmd == "models" then
        write({
          id = req.id,
          ok = true,
          models = {
            { provider = "mock", model = "m", context_window = 8000, active = true },
          },
        })
      elseif cmd == "sync" then
        write({ id = req.id, ok = true })
      else
        write({ id = req.id, ok = true })
      end
    end
  end
end
