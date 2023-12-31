-- SPDX-License-Identifier: MIT

---Various helpers.
local M = {}


local nvim_err_writeln = vim.api.nvim_err_writeln


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

---@param text string
---@return string
function M.unescape(text)
	-- This is fragile, what if there is a double-backslash before the
	-- character?
	local result = text:gsub('\\([abfnrtv])', escape_chars)
	return result
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

---Shows an error message within Neovim.
function M.echo_error(text)
	nvim_err_writeln(text)
end


return M
