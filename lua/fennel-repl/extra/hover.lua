---Convenient high-level REPL features.  These build on top of the primitives
---from lover-level modules and are not provided to the user directly.  The
---user is supposed to access them through mappings instead.
local M = {}

local preview   = vim.lsp.util.open_floating_preview
local instances = require 'fennel-repl.instances'
local op        = require 'fennel-repl.operation'
local cb        = require 'fennel-repl.callback'
local lib       = require 'fennel-repl.lib'


---List of events which close the preview window
---@type string[]
local close_events = {'CursorMoved', 'CursorMovedI', 'InsertCharPre'}
---Maximum floating window width
local max_width = 40
---Maximum floating window height
local max_height = 30


---Focus ID shared among all hover windows in the Fennel REPL
local focus_id = 'fennel_repl_hover_window'


---Helper function which gets the current word under the cursor, including
---adjacent word delimited by full stop characters.  This means we will get
---`string.format` instead of just `format`.
---@return string? word  The word under the cursor if there is any
local function get_word()
	vim.opt.iskeyword:append {'.'}
	local success, word = pcall(vim.fn.expand, '<cword>')
	vim.opt.iskeyword:remove {'.'}
	return success and #word > 0 and word or nil
end


---Open a floating preview window with contents.
---@param text string  The text to display
local function open_window(text)
	local lines = vim.fn.split(text, '\\\\n')
	local width = 0
	for _, line in ipairs(lines) do
		local n = #line
		if n > width then width = n end
	end

	preview(lines, '', {
		width = width,
		height = #lines,
		max_width = max_width,
		max_height = max_height,
		close_events = close_events,
		focus_id = focus_id,
		focusable = true,
		focus = true,
		border = 'single',
	})
end


---Opens documentation for the current symbol under the buffer in a hover
---window.
function M.doc()
	local sym = get_word()
	if not sym then return end

	local jobid = vim.b.fennel_repl_jobid
	if not jobid then return end
	---@type Instance
	local repl  = instances[jobid]
	if not repl then return end

	local msg = op.doc(sym)

	-- Fetch docstring from REPL and add it to the item
	repl.callbacks[msg.id] = coroutine.create(function (response)
		cb.doc(response, function(values)
			local text = values[1]
			open_window(text)
		end)
	end)
	vim.fn.chansend(jobid, {lib.format_message(msg), ''})
end

return M
