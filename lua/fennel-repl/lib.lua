-- SPDX-License-Identifier: MIT

local fn = vim.fn
local nvim_buf_add_highlight = vim.api.nvim_buf_add_highlight

---Various helpers.
local M = {}

--- Maps the second character from an escape sequence to its actual character
local escape_chars = {
    a = '\a',
    b = '\b',
    f = '\f',
	n = '\n',
    r = '\r',
    t = '\t',
    v = '\v',
}

---Escape a message value to be safe for transport to the REPL server.  This
---involves escaping double quote characters and turning line breaks into '\\n'
---(a backslash character followed by the letter 'n').  We cannot transport
---newlines even if they are escaped, so we need to turn them into their
---two-character representation.
local function escape(s)
	local result = type(s) == 'string' and string.format('%q', s) or tostring(s)
	-- NOTE: the newlines have been escaped in the above step already, so we
	-- only need the letter 'n'.
	return result:gsub('\n', 'n')
end

local function unescape(text)
	-- This is fragile, what if there is a double-backslash before the
	-- character?
	return text:gsub('\\([abfnrtv])', escape_chars)
end

---Converts an ASCII character code to its character
---@param code string|number  Character code in base 10
---@return string char  The character
local function ascii_to_char(code)
	if type(code) == 'number' then
		return string.char(code)
	end
	code = tonumber(code, 10)
	return string.char(code)
end

---Format a REPL message object (table) to a message string that conforms to
---the REPL protocol.
function M.format_message(message)
	local items = {}
	for k, v in pairs(message) do
		table.insert(items, string.format('"%s" %s', k, escape(v)))
	end
	return string.format('{%s}', table.concat(items, ' '))
end

---Parse a message from the server to a Lua table.
function M.decode_message(message)
	-- Decoding JSON can get stuck on ASCII character codes. See
	-- `:h luaref-literal` for the format
	message = message:gsub('\\(%d%d?%d?)', ascii_to_char)
	return vim.json.decode(message)
end

function M.place_text(text)
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(unescape(text), '\n')) do
		fn.append(linenr + i, line)
	end
end

function M.place_comment(text)
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(unescape(text), '\n')) do
		local linenr = linenr + i
		fn.append(linenr, line)
		nvim_buf_add_highlight(0, -1, 'FennelReplComment', linenr, 0, -1)
	end
end

function M.place_output(text)
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(unescape(text), '\n')) do
		local linenr = linenr + i
		fn.append(linenr, line)
		nvim_buf_add_highlight(0, -1, 'FennelReplValue', linenr, 0, -1)
	end
end

function M.place_error(text)
	-- This should be distinct from regular output.
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(unescape(text), '\n')) do
		local linenr = linenr + i
		fn.append(linenr, line)
		nvim_buf_add_highlight(0, -1, 'FennelReplError', linenr, 0, -1)
	end
end

return M
