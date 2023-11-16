-- SPDX-License-Identifier: MIT

local fn = vim.fn
local nvim_buf_get_var     = vim.api.nvim_buf_get_var
local nvim_buf_set_extmark = vim.api.nvim_buf_set_extmark
local instances            = require 'fennel-repl.instances'
local lib                  = require 'fennel-repl.lib'

local M = {}

-- Operation identifiers, repeated here to avoid typos
local accept      = 'accept'
local apropos     = 'apropos'
local apropos_doc = 'apropos-doc'
local compile     = 'compile'
local complete    = 'compile'
local doc         = 'doc'
local done        = 'done'
local error_repl  = 'error'
local eval        = 'eval'
local help        = 'help'
local print_repl  = 'print'
local read_repl   = 'read'
local reload      = 'reload'
local reset       = 'reset'

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

---Handle an error response from the server.  Prints the error to the REPL
---output and parses the traceback (if it exists).
local function handle_error_response(response)
	local type, data, traceback = response.type, response.data, response.traceback
	lib.place_error(string.format('%s error: %s', type, data))
	-- Display the traceback
	if traceback then
		---@type Instance
		local instance = instances[nvim_buf_get_var(0, 'fennel_repl_jobid')]
		-- We have to manually break up the traceback so we can parse each line
		-- individually
		for _, tb_line in ipairs(fn.split(lib.unescape(traceback), '\n')) do
			lib.place_error(tb_line)
			-- Not every line points to a file location
			local start, stop, file, pos = tb_line:find('(%S+):(%d+):')
			if start then
				local lnum = fn.line('$') - 2
				local opts = {
					end_col = stop - 1,
					hl_group = 'FennelReplErrorLink',
					hl_mode = 'combine',
				}
				local extmark = nvim_buf_set_extmark(0, lib.namespace, lnum, start - 1, opts)
				instance.links[extmark] = {file = file, lnum = tonumber(pos)}
			end
		end
	end
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
		---@type Instance
		local instance = instances[jobid]
		local protocol, fennel, lua = msg.protocol, msg.fennel, msg.lua
		instance.protocol = protocol
		instance.fennel   = fennel
		instance.lua      = lua
		lib.place_comment(string.format([[
;; Welcome to Fennel %s on %s
;; REPL protocol version %s
;; Use ,help to see available commands]], fennel, lua, protocol))
	elseif status == error_repl then
		local data = msg.data
		fn.jobstop(jobid)
		error(string.format('Error initialising Fennel REPL, status is %s', data))
	end
end

---An internal error we cannot recover from.  Just shut down the REPL and show
---an error message.
function M.internal_error(response)
	local type, data = response.type, response.data
	lib.echo_error(string.format('Fennel REPL internal error: %s\n%s', type, data))
	local jobid = nvim_buf_get_var(0, 'fennel_repl_jobid')
	fn.jobstop(jobid)
end


-- Evaluate a string of Fennel code.
function M.eval(response)
	local op = response.op
	if response.op ~= accept then
		error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
	end

	local jobid = nvim_buf_get_var(0, 'fennel_repl_jobid')
	---@type Instance
	local instance = instances[jobid]
	local values = {}

	response = coroutine.yield()
	op = response.op
	while op ~= done do
		if op == error_repl then
			-- print('An error')
			local type, data = response.type, response.data
			if type == 'parse' and data == 'incomplete message' then
				handle_incomplete_message(response)
			else
				instance.pending = nil
				handle_error_response(response)
			end
			return
		elseif op == print_repl then
			local descr, data = response.descr, response.data
			if descr == 'stdout' then
				lib.place_text(data)
			end
		elseif op == read_repl then
			local pipe = response.pipe
			-- NOTE: We need to know the input mode so we can know when the
			-- input is still incomplete. This is not possible with the current
			-- version of the protocol (0.3.0)
			vim.ui.input({prompt = 'Fennel input: ', cancelreturn = ''}, function(input)
				local file = io.open(pipe, 'a')
				if file then
					pcall(file.write, file, input)
					file:close()
				end
			end)
		elseif op == eval then
			instance.pending = nil
			switch_prompt(vim.fn.bufnr(''), '>> ')
			values = fn.extend(values, response.values)
		else
			print 'An unexpected error occurred'
			error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
		end
		response = coroutine.yield()
		op = response.op
	end

	lib.place_output(table.concat(values, '\t'))
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
	lib.place_text(table.concat(values, '\t'))
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
	lib.place_text(table.concat(values, '\t'))
end

-- Reload the module.
function M.reload(response)
	local op = response.op
	if op ~= accept then
		-- TODO: handle error
	end
	response = coroutine.yield()
	op = response.op
	if op == error_repl then
		local data, traceback = response.data, response.traceback
		coroutine.yield()  -- So we can receive the 'done' instruction
		lib.place_error(data)
		lib.place_error(traceback)
	elseif op ~= reload then
		-- TODO: handle error
	end
	local values = response.values
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end
	lib.place_text(table.concat(values, '\t'))
end

-- Print the filename and line number for a given function.
function M.find(response)
	local op = response.op
	if op ~= accept then
		-- TODO: handle error
	end
	response = coroutine.yield()
	op = response.op
	if op == error_repl then
		if response.type == 'repl' then
			coroutine.yield()  -- So we can receive the 'done' instruction
		lib.place_error(response.data)
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
	lib.place_text(table.concat(values, '\t'))
end

-- Compiles the expression into Lua and returns the result.
function M.compile(response)
	local op = response.op
	if op ~= accept then
		-- TODO: Handle error
	end
	response = coroutine.yield()
	op = response.op
	if op == error_repl then
		-- TODO: It is possible for the argument to be spread over multiple
		-- lines. We have to handle that error and put the REPL into pending
		-- mode, but in such a way that the text will be sent for
		-- compilation, not evaluation.
		local data = response.data
		lib.place_error(data)
	elseif op ~= compile then
		-- TODO: handle error
	end
	local values = response.values

	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO handle error
	end
	lib.place_text(table.concat(values))
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
	lib.place_text(table.concat(values, '\t'))
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
	lib.place_text(table.concat(values, '\t'))
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

	lib.place_text(table.concat(values, '\t'))
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

	lib.place_text(table.concat(values, '\t'))
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
