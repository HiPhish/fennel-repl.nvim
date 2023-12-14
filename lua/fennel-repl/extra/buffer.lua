-- SPDX-License-Identifier: MIT

---Various functions for integrating Fennel buffers with the REPL
local M = {}

local ts = vim.treesitter
local instances = require 'fennel-repl.instances'
local op = require 'fennel-repl.operation'
local cb = require 'fennel-repl.callback'

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
	for id, node, metadata in query:iter_captures(find_toplevel(), 0) do
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

return M
