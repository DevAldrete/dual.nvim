-- The keys, from the editor: the picker, the masked prompt, and the key
-- on its way to the server.

vim.opt.rtp:append(vim.fn.getcwd())

local h = dofile("tests/dual/harness.lua")
local dual = require("dual")
local auth = require("dual.ops.auth")
local prompt = require("dual.ui.prompt")

h.group("the keys")

dual.setup({
  server = {
    cmd = "nvim",
    args = { "--headless", "-u", "NONE", "-l", "tests/dual/mock_xia.lua" },
  },
  keys = {},
})

-- The picker is the user's: `vim.ui.select` is replaced, so the test can
-- choose.
local offered = nil
vim.ui.select = function(items, opts, on_choice)
  offered = items
  on_choice(items[#items])
end

-- The chat is where the plugin says things.
dual.start(function()
  require("dual.ui.chat").open()
end)
h.ok(h.wait_for(function()
  return dual.state.session ~= nil
end, 10000), "the server answers")

-- The provider list.
auth.run()
h.ok(h.wait_for(function()
  return offered ~= nil
end, 10000), "the picker was offered the providers")
h.eq(2, #offered, "the server's providers are the ones offered")
h.contains(offered[1].name, "mock", "the list names the provider")
h.contains(offered[1].name, "Mock", "and its name")

-- The key is asked for in a prompt that hides it.
h.ok(h.wait_for(function()
  return prompt.buffer ~= nil
end, 10000), "the prompt is open")
h.eq(true, prompt.secret, "the prompt hides what is typed")
local label = vim.api.nvim_buf_get_lines(prompt.buffer, 0, 1, false)[1]
h.eq("the key for other", label,
  "the prompt asks for the key of the provider that was picked")

-- The text is concealed on the screen: a key is not something to read
-- over the user's shoulder.
local conceal = vim.api.nvim_get_option_value("conceallevel",
  { win = prompt.window })
h.eq(2, conceal, "what is typed is concealed")

-- And the key is given to the server.
vim.api.nvim_buf_set_lines(prompt.buffer, 1, 2, false, { "sk-the-secret" })
h.eq("sk-the-secret", prompt.text(), "the prompt holds the key")

-- Enter submits it.
vim.api.nvim_feedkeys(
  vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

h.ok(h.wait_for(function()
  return dual.state.client ~= nil
end, 10000), "the server is there")

-- The chat says the key is remembered: the round trip went through.
local chat = require("dual.ui.chat")
local function transcript_text()
  local text = ""
  for _, buf in pairs(chat.buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      text = text
        .. table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end
  end
  return text
end
h.ok(h.wait_for(function()
  return transcript_text():find("remembered", 1, true) ~= nil
end, 10000), "the chat says the key is remembered")

-- And the key itself is nowhere in the transcript.
h.ok(not transcript_text():find("sk-the-secret", 1, true),
  "the key is not in the transcript")

-- The provider now has a key, and the list says so.
offered = nil
auth.run()
h.ok(h.wait_for(function()
  return offered ~= nil
end, 10000), "the picker is offered the providers again")
local marked = false
for _, item in ipairs(offered) do
  if item.provider == "other" and item.name:find("*", 1, true) then
    marked = true
  end
end
h.ok(marked, "the provider that has a key is marked")

-- And the user can take it back: an empty key forgets it.
offered = nil
auth.run()
h.ok(h.wait_for(function()
  return offered ~= nil and prompt.buffer ~= nil
end, 10000), "the prompt is open again")
local label = vim.api.nvim_buf_get_lines(prompt.buffer, 0, 1, false)[1]
h.contains(label, "forgets it", "the prompt says the key can be forgotten")
vim.api.nvim_feedkeys(
  vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
h.ok(h.wait_for(function()
  return transcript_text():find("forgotten", 1, true) ~= nil
end, 10000), "the chat says the key is forgotten")

dual.stop()
h.report()
