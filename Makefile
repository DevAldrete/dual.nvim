# dual.nvim — the tests, the lint and the format.
#
# The tests need nothing but Neovim: they are plain Lua scripts, and the
# server they talk to is a stand-in that speaks the protocol.

NVIM ?= nvim
LUA_DIRS := lua plugin tests

.PHONY: test lint format check clean

test:
	@status=0; \
	for f in tests/dual/*_spec.lua; do \
		echo "== $$f"; \
		$(NVIM) --headless -u NONE -l $$f || status=1; \
	done; \
	exit $$status

lint:
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck $(LUA_DIRS); \
	else \
		echo "luacheck is not installed: skipping"; \
	fi

format:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua $(LUA_DIRS); \
	else \
		echo "stylua is not installed: skipping"; \
	fi

check: lint test

clean:
	@rm -rf .tests
