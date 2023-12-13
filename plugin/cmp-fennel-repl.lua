-- SPDX-License-Identifier: MIT

-- We request completion from the REPL through a request.  This request
-- contains the fully qualified name of the text, such as 'string.fo' for the
-- function 'string.format'.  The text to sent to the REPL is the current word
-- under the cursor, plus any adjacent words connected through the '.' (full
-- stop) character.  The '.' is not a keyword character in Fennel, but we still
-- need it so we can properly join names like 'string' and 'fo' in 'string.fo'.


local has_cmp, cmp = pcall(require, 'cmp')
if not has_cmp then return end

local instances = require 'fennel-repl.instances'
local op        = require 'fennel-repl.operation'
local cb        = require 'fennel-repl.callback'

---Completion source for cmp-nvim
local source = {}


---Convert one completion value from the REPL to a completion item
local function value_to_item(value)
	local parts = vim.fn.split(value, '\\v\\.')
	-- Display only the last part, but keep the full value around
	return {
		label = parts[#parts],
		labelDetails = {
			description = value,
		},
	}
end

---Returns the current word under the cursor in insert mode.  The expand
---function is not suitable because in insert mode the cursor is one character
---past the current word.
local function get_current_word()
	-- https://vi.stackexchange.com/a/17196
	local linenr = vim.fn.line('.')
	local column = vim.fn.charcol('.') - 1

	local line = vim.fn.getline(linenr)
	local lhs = vim.fn.strcharpart(line, 0, column)
	local rhs = vim.fn.strcharpart(line, column, vim.fn.strchars(line) - column + 1)
	lhs = vim.fn.matchstr(lhs, '\\v(\\k|\\.)*$')
	rhs = vim.fn.matchstr(rhs, '\\v^(\\k|\\.)*')
	return lhs .. rhs
end


---Returns human-readable name of the source
function source:get_debug_name()
	return 'Fennel REPL'
end

---The source is available if the current buffer has a Fennel REPL job ID and
---the job is still running.
function source:is_available()
	local jobid = vim.b.fennel_repl_jobid
	if not jobid then return false end
	local success = pcall(vim.fn.jobpid, jobid)
	return success
end

---Table access triggers completion
function source:get_trigger_characters()
	return {'.'}
end

---Request completion from the REPL based on current word.
---@param _params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(_params, callback)
	local input = get_current_word()
	if #input == 0 then return end

	local jobid = vim.b.fennel_repl_jobid
	local repl  = instances[jobid]
	local msg   = op.complete(input)

	local function process_completion(values)
		callback(vim.tbl_map(value_to_item, values))
	end
	repl:send_message(msg, cb.complete, process_completion)
end

---Enrich the completion item with additional data from the REPL.  This is not
---very efficient because of the extra round trips per item, but it works.
---@param item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(item, callback)
	local sym = item.labelDetails.description or ''
	local jobid = vim.b.fennel_repl_jobid
	local repl  = instances[jobid]
	local msg   = op.doc(sym)

	-- Fetch docstring from REPL and add it to the item
	local function apply_doc(values)
		local text = values[1]
		item.documentation = string.gsub(text, '\\n', '\n')
		callback(item)
	end
	repl:send_message(msg, cb.doc, apply_doc)

	-- How can we get the type? It gets more complicated because the symbols we
	-- get back might be special forms like 'set' which we cannot pass to the
	-- 'type' function.  We could do something like this:
	--
	--   (let [(success thing) (pcall (. (require :fennel) :eval) sym)]
	--       (if success (type thing) ""))
	--
	-- The 'sym' is a string, so we try to see if we can evaluate it to an
	-- object.
end

cmp.register_source('fennel-repl', source)
