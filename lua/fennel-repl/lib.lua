-- SPDX-License-Identifier: MIT

local fn = vim.fn
local nvim_buf_add_highlight = vim.api.nvim_buf_add_highlight
local nvim_buf_get_var       = vim.api.nvim_buf_get_var
local nvim_err_writeln       = vim.api.nvim_err_writeln
local nvim_list_wins         = vim.api.nvim_list_wins
local nvim_win_set_cursor    = vim.api.nvim_win_set_cursor
local nvim_win_get_buf       = vim.api.nvim_win_get_buf
local instances              = require 'fennel-repl.instances'

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

---Namespace for all Fennel REPL extmarks.
M.namespace = vim.api.nvim_create_namespace('')


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

function M.unescape(text)
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
	for i, line in ipairs(fn.split(M.unescape(text), '\n')) do
		fn.append(linenr + i, line)
	end
end

function M.place_comment(text)
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(M.unescape(text), '\n')) do
		local linenr = linenr + i
		fn.append(linenr, line)
		nvim_buf_add_highlight(0, -1, 'FennelReplComment', linenr, 0, -1)
	end
end

function M.place_output(text)
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(M.unescape(text), '\n')) do
		local linenr = linenr + i
		fn.append(linenr, line)
		nvim_buf_add_highlight(0, -1, 'FennelReplValue', linenr, 0, -1)
	end
end

function M.place_error(text)
	-- This should be distinct from regular output.
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(M.unescape(text), '\n')) do
		local linenr = linenr + i
		fn.append(linenr, line)
		nvim_buf_add_highlight(0, -1, 'FennelReplError', linenr, 0, -1)
	end
end

---Shows an error message within Neovim.
function M.echo_error(text)
	nvim_err_writeln(text)
end

---Follow the link under the cursor, open the file.  This is used with
---traceback messages to jump to the indicated file and line.  If there already
---is a window open we jump to it, otherwise we open a new window.
function M.follow_link()
	local instance = instances[nvim_buf_get_var(0, 'fennel_repl_jobid')]
	local file, lnum

	-- Try to find an extmark at the cursor position
	for _, info in ipairs(vim.inspect_pos().extmarks) do
		if info.ns_id == M.namespace then
			local link = instance.links[info.id]
			if link then
				file = link.file
				lnum = link.lnum
				break
			end
		end
	end

	-- No extmark at this location
	if not file then return end

	-- Try to find a suitable window
	for _, win in ipairs(nvim_list_wins()) do
		local buf = nvim_win_get_buf(win)
		local bufname = vim.fn.bufname(buf)
		if vim.fn.fnamemodify(bufname, ':p') == vim.fn.fnamemodify(file, ':p') then
			vim.fn.win_gotoid(win)
			nvim_win_set_cursor(0, {lnum, 0})
			return  -- Premature return because we have found a window
		end
	end

	-- No window found, open a new one
	vim.cmd {cmd = 'split', args = {vim.fn.fnamemodify(file, ':~:.')}}
	nvim_win_set_cursor(0, {lnum, 0})
end

return M
