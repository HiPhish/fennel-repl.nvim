-- SPDX-License-Identifier: MIT

local fn = vim.fn
local nvim_buf_get_var       = vim.api.nvim_buf_get_var
local nvim_buf_add_highlight = vim.api.nvim_buf_add_highlight
local instances = require 'fennel-repl.instances'
local M = {}

-- Operation identifiers, repeated here to avoid typos
local accept      = 'accept'
local apropos     = 'apropos'
local apropos_doc = 'apropos-doc'
local compile     = 'compile'
local complete    = 'compile'
local doc         = 'doc'
local done        = 'done'
local error       = 'error'
local eval        = 'eval'
local help        = 'help'
local reload      = 'reload'
local reset       = 'reset'

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


---Sets the prompt string of the prompt buffer, deletes the previous empty
---prompt line if there was any.  When we change the prompt there will be an
---empty line with the previous prompt which we want to get rid of.
---@param buffer number  Number of the prompt buffer
---@param prompt string  New prompt string
---@return nil
local function switch_prompt(buffer, prompt)
	if fn.prompt_getprompt(buffer) ~= prompt then
		vim.api.nvim_buf_set_lines(0, -2, -1, false, {})
	end
	fn.prompt_setprompt(buffer, prompt)
end

local function unescape(text)
	-- This is fragile, what if there is a double-backslash before the
	-- character?
	return text:gsub('\\([abfnrtv])', escape_chars)
end

local function place_text(text)
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(unescape(text), '\n')) do
		fn.append(linenr + i, line)
	end
end

local function place_output(text)
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(unescape(text), '\n')) do
		local linenr = linenr + i
		fn.append(linenr, line)
		nvim_buf_add_highlight(0, -1, 'FennelReplValue', linenr, 0, -1)
	end
end

local function place_error(text)
	-- This should be distinct from regular output.
	local linenr = fn.line('$') - 2
	for i, line in ipairs(fn.split(unescape(text), '\n')) do
		local linenr = linenr + i
		fn.append(linenr, line)
		nvim_buf_add_highlight(0, -1, 'FennelReplError', linenr, 0, -1)
	end
end


local function handle_incomplete_message(response)
	-- print('The line was incomplete')
	-- The previous line still contains an empty line with the old buffer
	switch_prompt(fn.bufnr(''), '.. ')
	response = coroutine.yield()
	local op = response.op
	if op == done then
		-- print 'Done'
		return
	end
	error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
end

local function handle_error_response(response)
	place_error(response.data)
	response = coroutine.yield()
	local op = response.op
	if op == done then
		-- print 'Done'
		return
	end
	error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
end

---Fixed callback for the 'init' operation.  If there was an error initialising
---the REPL it will be shut down.
function M.init(msg)
	local status = msg.status
	local jobid = nvim_buf_get_var(0, 'fennel_repl_jobid')

	if status == done then
		local instance = instances[jobid]
		local protocol, fennel, lua = msg.protocol, msg.fennel, msg.lua
		instance.protocol = protocol
		instance.fennel   = fennel
		instance.lua      = lua
	elseif status == error then
		local data = msg.data
		fn.jobstop(jobid)
		error(string.format('Error initialising Fennel REPL, status is %s', data))
	end
end


-- Evaluate a string of Fennel code.
function M.eval(response)
	local op = response.op
	if response.op ~= accept then
		error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
	end
	-- print 'Accepted'

	response = coroutine.yield()
	op = response.op
	local jobid = nvim_buf_get_var(0, 'fennel_repl_jobid')
	local instance = instances[jobid]
	if op == error then
		-- print('An error')
		local type, data = response.type, response.data
		if type == 'parse' and data == 'incomplete message' then
			handle_incomplete_message(response)
		else
			instance.pending = nil
			handle_error_response(response)
		end
		return
	elseif op ~= eval then
		print 'An unexpected error occurred'
		error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
	end
	-- print('Server has accepted text '.. vim.inspect(response.values))
	instance.pending = nil
	switch_prompt(vim.fn.bufnr(''), '>> ')
	local values = response.values

	response = coroutine.yield()
	op = response.op
	if op ~= done then
		error(string.format('Invalid response to evaluation: %q', op))
	end

	place_output(table.concat(values, '\t'))
	-- print('Done with evaluation')
end

-- complete: produce all possible completions for a given input symbol.
function M.complete(response)
	local op = response.op
	if op ~= accept then
		-- TODO: Handle error
	end
	response = coroutine.yield()
	op = response.op
	if op ~= complete then
		-- TODO: Handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: Handle error
	end
	place_text(table.concat(values, '\t'))
end


-- Produce documentation of a symbol.
function M.doc(response)
	local op = response.op
	if op ~= accept then
		error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
	end
	response = coroutine.yield()
	op = response.op
	if op ~= doc then
		-- TODO: handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end
	place_text(table.concat(values, '\t'))
end

-- Reload the module.
function M.reload(response)
	local op = response.op
	if op ~= accept then
		-- TODO: handle error
	end
	response = coroutine.yield()
	op = response.op
	if op == error then
		local data, traceback = response.data, response.traceback
		coroutine.yield()  -- So we can receive the 'done' instruction
		place_error(data)
		place_error(traceback)
	elseif op ~= reload then
		-- TODO: handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end
	place_text(table.concat(values, '\t'))
end

-- Print the filename and line number for a given function.
function M.find(response)
	local op = response.op
	if op ~= accept then
		-- TODO: handle error
	end
	response = coroutine.yield()
	op = response.op
	if op == error then
		if response.type == 'repl' then
			coroutine.yield()  -- So we can receive the 'done' instruction
			place_error(response.data)
			return
		end
		-- TODO: handle error
		coroutine.yield()  -- So we can receive the 'done' instruction
		return
	elseif op ~= reload then
		-- TODO: handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end
	place_text(table.concat(values, '\t'))
end

-- Compiles the expression into Lua and returns the result.
function M.compile(response)
	local op = response.op
	if op ~= accept then
		-- TODO: Handle error
	end
	response = coroutine.yield()
	op = response.op
	if op == error then
		-- TODO: It is possible for the argument to be spread over multiple
		-- lines. We have to handle that error and put the REPL into pending
		-- mode, but in such a way that the text will be sent for
		-- compilation, not evaluation.
		local data = response.data
		place_error(data)
	elseif op ~= compile then
		-- TODO: handle error
	end
	local values = response.values

	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO handle error
	end
	place_text(table.concat(values))
end

-- Produce all functions matching a pattern in all loaded modules.
function M.apropos(response)
	local op = response.op
	if op ~= accept then
		-- TODO: Handle error
	end
	response = coroutine.yield()
	op = response.op
	if op ~= apropos then
		-- TODO: Handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: Handle error
	end
	place_text(table.concat(values, '\t'))
end

-- Produce all functions that match the pattern in their docs.
function M.apropos_doc(response)
	local op = response.op
	if op ~= accept then
		-- TODO: Handle error
	end
	response = coroutine.yield()
	op = response.op
	if op ~= apropos_doc then
		-- TODO: Handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: Handle error
	end
	place_text(table.concat(values, '\t'))
end

-- Produce all documentation matching a pattern in the function name.
function M.apropos_show_docs(response)
	-- TODO
	-- This appear to be broken in Fennel in general
	-- https://github.com/bakpakin/Fennel/issues/463
end

-- Show REPL message in the REPL.
function M.help(response)
	local op = response.op
	if op ~= accept then
		error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
	end

	response = coroutine.yield()
	op = response.op
	if op ~= help then
		-- TODO: handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end

	place_text(table.concat(values, '\t'))
end

-- Erase all REPL-scope.
function M.reset(response)
	local op = response.op
	if op ~= accept then
		-- TODO: Handle error
	end

	response = coroutine.yield()
	op = response.op
	if op ~= reset then
		-- TODO: handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end

	place_text(table.concat(values, '\t'))
end

-- Leave the REPL.
function M.exit(response)
	local op = response.op
	if op ~= accept then
		-- TODO: Handle error
	end

	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end
	local jobid = nvim_buf_get_var(0, 'fennel_repl_jobid')
	fn.jobstop(jobid)
end

-- Ignore the operation.
function M.nop(_response)
	-- Intentionally empty.
end

M.comma_commands = {
	complete              = M.complete,
	doc                   = M.doc,
	reload                = M.reload,
	find                  = M.find,
	compile               = M.compile,
	apropos               = M.apropos,
	['apropos-doc']       = M.apropos_doc,
	['apropos-show-docs'] = M.apropos_show_docs,  -- TODO
	help                  = M.help,
	reset                 = M.reset,
	exit                  = M.exit,
}


return M
