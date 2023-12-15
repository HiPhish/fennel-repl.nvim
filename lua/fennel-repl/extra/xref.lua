-- SPDX-License-Identifier: MIT

---Functions for dealing with cross-references
local M = {}

local nvim_list_wins      = vim.api.nvim_list_wins
local instances           = require 'fennel-repl.instances'
local nvim_buf_get_var    = vim.api.nvim_buf_get_var
local nvim_win_get_buf    = vim.api.nvim_win_get_buf
local nvim_win_set_cursor = vim.api.nvim_win_set_cursor


---Follow the link under the cursor, open the file.  This is used with
---traceback messages to jump to the indicated file and line.  If there already
---is a window open we jump to it, otherwise we open a new window.
function M.follow()
	local repl = instances[nvim_buf_get_var(0, 'fennel_repl_jobid')]
	local file, lnum

	-- Try to find an extmark at the cursor position
	for _, info in ipairs(vim.inspect_pos().extmarks) do
		if info.ns_id == M.namespace then
			local link = repl.links[info.id]
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
