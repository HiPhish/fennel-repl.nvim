-- SPDX-License-Identifier: MIT

---Various functions for integrating Fennel buffers with the REPL
local M = {}

local ts = vim.treesitter
local fn = vim.fn
local instances = require 'fennel-repl.instances'
local op = require 'fennel-repl.operation'
local cb = require 'fennel-repl.callback'


---Path separator, depends on operating system.
---@type '/' | '\\'
local PATHSEP = fn.has('win32') ~= 0 and '\\' or '/'

---Maps buffer numbers to module specifications.  Each specification contains
---the file name and the module name.  If the file name has changed the module
---name might no longer be valid.
---@type table<integer, {fname: string, modname: string}>
local modules = {}

---Returns the toplevel node at the current cursor position
---@return TSNode? root
local function find_toplevel()
	local node = ts.get_node {
		ignore_injections = true,
	}
	local root = node
	while true do
		---The very top-level node is the entire document, we want a child of
		---the document
		local parent = node:parent()
		local grandparent = parent:parent()
		if grandparent then
			root = parent
			node = parent
		else
			break
		end
	end
	return root
end

---Returns the node captured closest to the cursor, if any
---@param capture string  Name of the capture
---@param row     integer
---@param col     integer
---@return TSNode? node
local function find_closest_capture(capture, row, col)
	local query = ts.query.get('fennel', 'fennel-repl')
	local result
	for id, node in query:iter_captures(find_toplevel(), 0) do
		local name = query.captures[id]
		if name == capture then
			local contains_cursor = ts.node_contains(node, {row, col, row, col})
			if not result and contains_cursor then
				result = node
			elseif ts.node_contains(result, {node:range(true)}) and contains_cursor then
				result = node
			end
		end
	end
	return result
end


---Evaluates the top-level expression in the current buffer at the current
---cursor position.
function M.eval_toplevel()
	local repl = instances.get_topmost()
	if not repl then
		return
	end
	local root = find_toplevel()
	if not root then
		return
	end
	local bufnr = vim.api.nvim_get_current_buf()
	local text = ts.get_node_text(root, bufnr)
	local msg = op.eval(text)
	repl:send_message(msg, cb.eval)
end

---Evaluates the closest expression to the cursor.
function M.eval_expr()
	local repl = instances.get_topmost()
	if not repl then
		return
	end
	local cursor = vim.fn.getcurpos()
	local node = find_closest_capture('fennel-expr', cursor[2] - 1, cursor[3] - 1)
	if not node then
		print 'No node'
		return
	end
	local bufnr = vim.api.nvim_get_current_buf()
	local text = ts.get_node_text(node, bufnr)
	local msg = op.eval(text)
	repl:send_message(msg, cb.eval)
end

---Reloads the current buffer in the last REPL
function M.reload()
	local repl = instances.get_topmost()
	if not repl or vim.bo.buftype ~= '' then return end
	-- We cannot reverse-lookup a module specification, we instead have to ask
	-- the user for the module name.  The result is cached for subsequent
	-- reloads.  The cache might be invalid if the file name has changed.
	local bufnr = vim.api.nvim_get_current_buf()
	local fname = fn.expand('%')
	local modinfo = modules[bufnr]
	if not modinfo then
		local modname = fn.input{
			prompt = 'Module name: ',
			default = fn.fnamemodify(fname, ':r'):gsub(PATHSEP, '.'),
			cancelreturn = false,
		}
		if not modname or modname == '' then return end
		modinfo = {fname = fname, modname = modname}
		modules[bufnr] = modinfo
	elseif modinfo.fname ~= fname then
		local modname = fn.input{
			prompt = 'File name has changed, new module name: ',
			default = modinfo.modname,
			cancelreturn = false,
		}
		if not modname or modname == '' then return end
		modinfo.modname = modname
	end

	local function confirm_reload(_values)
		repl:place_comment(string.format(";; Reloaded :%s", modinfo.modname))
	end
	local msg = op.reload(modinfo.modname)
	repl:send_message(msg, cb.reload, confirm_reload)
end

return M
