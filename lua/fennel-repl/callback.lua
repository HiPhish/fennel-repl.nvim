-- SPDX-License-Identifier: MIT

local api = vim.api
local fn  = vim.fn
local nvim_buf_get_var     = api.nvim_buf_get_var
local nvim_win_set_option  = api.nvim_win_set_option
local nvim_buf_set_option  = api.nvim_buf_set_option
local nvim_buf_set_var     = api.nvim_buf_set_var
local nvim_buf_set_name    = api.nvim_buf_set_name
local nvim_buf_set_extmark = api.nvim_buf_set_extmark
local instances            = require 'fennel-repl.instances'
local lib                  = require 'fennel-repl.lib'
local const                = require 'fennel-repl.const'

local op  = require 'fennel-repl.operation'

---Collection of callback functions which we call when a response arrives.
---Some of the callbacks take a number of arguments, these are usually provide
---some initial information for the callback.  Subsequent resumes only accept a
---response object.
---
---The common pattern is to first create a coroutine, then resume it
---immediately with initial arguments.  The coroutine will yield as soon as it
---needs a responses.  We then register the suspended coroutine.
---
---    local callback = coroutine.create(M.eval)
---    coroutine.resume(callback, on_done, on_stdout, on_error)
---    repl.callbacks[123] = callback
local M = {}

-- Operation identifiers, repeated here to avoid typos
local accept      = 'accept'
local apropos     = 'apropos'
local apropos_doc = 'apropos-doc'
local compile     = 'compile'
local complete    = 'complete'
local doc         = 'doc'
local done        = 'done'
local error_repl  = 'error'
local eval        = 'eval'
local help        = 'help'
local print_repl  = 'print'
local read_repl   = 'read'
local reload      = 'reload'
local reset       = 'reset'

local BASE_PROMPT = '>> '
local WELCOME_TEMPLATE = [[
;; Welcome to Fennel %s on %s
;; REPL protocol version %s
;; Use ,help to see available commands]]

---Map of comma-commands onto their callback functions.  The map will be filled
---later after the functions have been defined.
local comma_commands


---Callback function for all Fennel prompts
local function active_prompt_callback(text)
	local repl = instances.get(nvim_buf_get_var(0, 'fennel_repl_id'))
	if not repl then return end
	local comma_command, comma_arg = string.match(text, '^%s*,(%S+)%s*(.*)')

	local message, callback
	if repl.pending then
		repl.pending = repl.pending .. '\n' .. text
		message = op.eval(repl.pending)
		callback = M.eval
	elseif comma_command then
		local comma_op = op.comma_ops[comma_command]
		if not comma_op then
			repl:place_error(string.format('Unknown command %s', comma_command))
			return
		end
		message = comma_op(comma_arg)
		callback = comma_commands[comma_command]
	else
		repl.pending = text
		message = op.eval(repl.pending)
		callback = M.eval
	end
	repl.callbacks[message.id] = callback
	repl.history:put(text)
	print('Sending ' .. lib.format_message(message))
	repl:send_message(message, callback)
end

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

local function handle_incomplete_message(_response)
	-- print('The line was incomplete')
	-- The previous line still contains an empty line with the old buffer
	switch_prompt(fn.bufnr(''), '.. ')
	local _, response = coroutine.yield()
	return response
end

---Handle an error response from the server.  Prints the error to the REPL
---output and parses the traceback (if it exists).
---@param repl FennelRepl
local function handle_error_response(repl, response)
	local type, data, traceback = response.type, response.data, response.traceback
	repl:place_error(string.format('%s error:', type))

	-- The output might contain ANSI escape sequences which we will replace
	-- with extmarks here.
	local ansi_pattern = '%[7m(.+)%[0m'
	for _, line in ipairs(fn.split(lib.unescape(data), '\n')) do
		local start, stop = line:find(ansi_pattern)
		if start then
			line = line:gsub(ansi_pattern, '%1')
		end
		repl:place_error(line)
		if start then
			local lnum = fn.line('$') - 2
			local opts = {
				end_col = stop - 8,
				hl_group = 'fennelReplErrorRange',
				hl_mode = 'combine',
			}
			nvim_buf_set_extmark(0, const.namespace, lnum, start - 1, opts)
		end
	end

	-- Display the traceback
	if traceback then
		-- We have to manually break up the traceback so we can parse each line
		-- individually
		for _, tb_line in ipairs(fn.split(lib.unescape(traceback), '\n')) do
			repl:place_error(tb_line)
			-- Not every line points to a file location
			local start, stop, file, pos = tb_line:find('(%S+):(%d+):')
			if start then
				local lnum = fn.line('$') - 2
				local opts = {
					end_col = stop - 1,
					hl_group = 'fennelReplErrorLink',
					hl_mode = 'combine',
				}
				local extmark = nvim_buf_set_extmark(0, const.namespace, lnum, start - 1, opts)
				repl.links[extmark] = {file = file, lnum = tonumber(pos) or 0}
			end
		end
	end

	_, response = coroutine.yield()
	return response
end

---Fixed callback for the 'init' operation.  If there was an error initialising
---the REPL it will be shut down.
---@param repl FennelRepl
---@param mods table       Command modifiers passed to the initial command
function M.init(repl, mods)
	local id = repl.id
	local msg = coroutine.yield()
	local status = msg.status

	if status == done then
		local protocol, fennel, lua = msg.protocol, msg.fennel, msg.lua
		repl.is_init  = true
		repl.protocol = protocol
		repl.fennel   = fennel
		repl.lua      = lua

		local buffer = api.nvim_create_buf(true, true)
		do
			nvim_buf_set_option(buffer, 'buftype', 'prompt')
			nvim_buf_set_option(buffer, 'bufhidden', 'hide')
			nvim_buf_set_option(buffer, 'buflisted', false)
			nvim_buf_set_option(buffer, 'swapfile', false)
			nvim_buf_set_option(buffer, 'filetype', 'fennel-repl')
			nvim_buf_set_var(buffer, 'fennel_repl_id', id)
			nvim_buf_set_name(buffer, string.format('Fennel REPL (%d)', id))
			fn.prompt_setprompt(buffer, BASE_PROMPT)
			fn.prompt_setcallback(buffer, active_prompt_callback)
		end
		repl.buffer = buffer

		-- Open the REPL buffer in a new window
		vim.cmd {cmd = 'sbuffer', args = {fn.string(buffer)}, mods = mods}
		nvim_win_set_option(0, 'number', false)
		nvim_win_set_option(0,  'spell', false)
		vim.cmd 'startinsert'

		repl:place_comment(WELCOME_TEMPLATE:format(fennel, lua, protocol))
	elseif status == error_repl then
		local data = msg.data
		repl:terminate()
		error(string.format('Error initialising Fennel REPL, status is %s', data))
	end
end

---An internal error we cannot recover from.  Just shut down the REPL and show
---an error message.
function M.internal_error(repl)
	local response = coroutine.yield()
	local type, data = response.type, response.data
	repl:place_error(string.format('Fennel REPL internal error: %s\n%s', type, data))
end


---Evaluate a string of Fennel code.
---
---@param on_done   fun(values: string[]): any?  What to do with the result
---@param on_stdout fun(data: string): any?  What to do with output to stdout
---@param on_error  fun(type: string, data: string, traceback: string): any?  Handle error from REPL
function M.eval(repl, on_done, on_stdout, on_error)
	local response = coroutine.yield()
	local op = response.op
	if response.op ~= accept then
		error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
	end

	local values = {}

	response = coroutine.yield()
	op = response.op
	while op ~= done do
		if op == error_repl then
			-- print('An error')
			local type, data = response.type, response.data
			if type == 'parse' and data == 'incomplete message' then
				response = handle_incomplete_message(response)
			else
				repl.pending = nil
				if on_error then
					response = coroutine.yield(on_error(type, data, response.traceback))
				else
					response = handle_error_response(repl, response)
				end
			end
			-- Take over flow of logic from here; we expect the next response
			-- to be final
			op = response.op
			if op == done then
				-- print 'Done'
				return
			end
			error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
		elseif op == print_repl then
			local descr, data = response.descr, response.data
			if descr == 'stdout' then
				if on_stdout then
					on_stdout(data)
				else
					repl:place_output(data)
				end
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
			repl.pending = nil
			switch_prompt(repl.buffer, '>> ')
			values = fn.extend(values, response.values)
		else
			print 'An unexpected error occurred'
			error(string.format('Invalid response to evaluation: %s', vim.inspect(response)))
		end
		response = coroutine.yield()
		op = response.op
	end

	if on_done then
		return on_done(values)
	end
	repl:place_value(table.concat(values, '\t'))
end

---complete: produce all possible completions for a given input symbol.
---@param on_done fun(values: string[]): any?  What to do with the result
function M.complete(repl, on_done)
	local response = coroutine.yield()
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
	if on_done then
		return on_done(values)
	end
	repl:place_output(table.concat(values, '\t'))
end


-- Produce documentation of a symbol.
---@param on_done fun(values: string[]): any?  What to do with the result
function M.doc(repl, on_done)
	local response = coroutine.yield()
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
	if on_done then
		return on_done(values)
	end
	repl:place_output(table.concat(values, '\t'))
end

---Reload the module.
---@param repl  FennelRepl
---@param on_done   (fun(values: string[]): any)?
function M.reload(repl, on_done)
	local response = coroutine.yield()
	local op = response.op
	if op ~= accept then
		-- TODO: handle error
	end
	while true do
		response = coroutine.yield()
		op = response.op
		if op == reload then
			local values = response.values
			if on_done then
				on_done(values)
			else
				repl:place_comment(';; ' .. table.concat(values))
			end
			break
		elseif op == error_repl then
			local data, traceback = response.data, response.traceback
			coroutine.yield()  -- So we can receive the 'done' instruction
			repl:place_error(data)
			repl:place_error(traceback)
			break
		elseif op == print_repl then
			local descr, data = response.descr, response.data
			if descr == 'stdout' then
				repl:place_output(data)
			end
		end
	end
	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end
end

-- Print the filename and line number for a given function.
function M.find(repl)
	local response = coroutine.yield()
	local op = response.op
	if op ~= accept then
		-- TODO: handle error
	end
	response = coroutine.yield()
	op = response.op
	if op == error_repl then
		if response.type == 'repl' then
			coroutine.yield()  -- So we can receive the 'done' instruction
		repl:place_error(response.data)
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
	repl:place_output(table.concat(values, '\t'))
end

-- Compiles the expression into Lua and returns the result.
function M.compile(repl)
	local response = coroutine.yield()
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
		repl:place_error(data)
	elseif op ~= compile then
		-- TODO: handle error
	end
	local values = response.values

	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO handle error
	end
	repl:place_output(table.concat(values))
end

-- Produce all functions matching a pattern in all loaded modules.
function M.apropos(repl)
	local response = coroutine.yield()
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
	repl:place_output(table.concat(values, '\t'))
end

-- Produce all functions that match the pattern in their docs.
function M.apropos_doc(repl)
	local response = coroutine.yield()
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
	repl:place_output(table.concat(values, '\t'))
end

-- Produce all documentation matching a pattern in the function name.
function M.apropos_show_docs(_repl)
	local _response = coroutine.yield()
	-- TODO
	-- This appear to be broken in Fennel in general
	-- https://github.com/bakpakin/Fennel/issues/463
end

---Show REPL message in the REPL.
---@param repl FennelRepl
function M.help(repl)
	local response = coroutine.yield()
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

	repl:place_output(table.concat(values, '\t'))
end

-- Erase all REPL-scope.
function M.reset(repl)
	local response = coroutine.yield()
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

	repl:place_output(table.concat(values, '\t'))
end

-- Leave the REPL.
function M.exit(repl)
	local response = coroutine.yield()
	local op = response.op
	if op ~= accept then
		-- TODO: Handle error
	end

	response = coroutine.yield()
	op = response.op
	if op ~= done then
		-- TODO: handle error
	end
	repl:terminate()
end

-- Ignore the operation.
function M.nop(_response)
	-- Intentionally empty.
end

comma_commands = {
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
