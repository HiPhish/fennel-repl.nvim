-- SPDX-License-Identifier: MIT
local api = vim.api
local fn  = vim.fn
local nvim_buf_set_option = api.nvim_buf_set_option
local nvim_buf_set_var    = api.nvim_buf_set_var
local nvim_buf_get_var    = api.nvim_buf_get_var
local nvim_buf_delete     = api.nvim_buf_delete
local nvim_buf_set_name   = api.nvim_buf_set_name

local lib = require 'fennel-repl.lib'
local op  = require 'fennel-repl.operation'
local cb  = require 'fennel-repl.callback'
local gen = require 'fennel-repl.id-generator'
local instances = require 'fennel-repl.instances'

local BASE_PROMPT = '>> '
local CONT_PROMPT = '.. '


---Callback function for all Fennel prompts
local function active_prompt_callback(text)
	local jobid = nvim_buf_get_var(0, 'fennel_repl_jobid')
	local instance = instances[jobid]
	local comma_command, comma_arg = string.match(text, '^%s*,(%S+)%s*(.*)')

	local message, callback
	if instance.pending then
		instance.pending = instance.pending .. '\n' .. text
		message = op.eval(instance.pending)
		callback = cb.eval
	elseif comma_command then
		message = op.comma_ops[comma_command](comma_arg)
		callback = cb.comma_commands[comma_command]
	else
		instance.pending = text
		message = op.eval(instance.pending)
		callback = cb.eval
	end
	instance.callbacks[message.id] = coroutine.create(callback)
	print('Sending ' .. lib.format_message(message))
	fn.chansend(jobid, {lib.format_message(message), ''})
end

---Callback for terminated Fennel process; will delete the buffer when the user
---presses <ENTER>
local function dead_prompt_callback(text)
	nvim_buf_delete(0, {force = true})
end

local function on_stdout(job_id, data, _name)
	print('Got response: ' .. vim.inspect(data))
	for _, line in ipairs(data) do
		-- print 'ping iterate over lines of data'
		local success, message = pcall(lib.decode_message, line)
		if success then
			local msgid = message.id
			local callbacks = instances[job_id].callbacks
			local callback = callbacks[msgid]
			if callback then
				coroutine.resume(callback, message)
				if coroutine.status(callback) == 'dead' then
					callbacks[msgid] = nil
					gen:drop(msgid)
				end
			else
				print(string.format('No callback for %d found in %s for job %d', msgid, vim.inspect(instances[job_id].callbacks), job_id))
			end
		elseif line ~= '' then
			error(string.format("Could not decode JSON: %s", message))
		end
	end
	nvim_buf_set_option(0, 'modified', false)
end

---Display errors from the REPL as errors in Neovim.
local function on_stderr(job_id, data, _name)
	api.nvim_out_write(fn.join(data, '\n'))
	api.nvim_out_write('\n')
end

local function on_exit(job_id, exit_code, _event)
	local buffer = instances[job_id].buffer
	local msg = string.format(';;; Fennel terminated with exit code %d', exit_code)
	fn.prompt_setprompt(buffer, '')
	fn.append('$', msg)
	instances:drop(nvim_buf_get_var(0, 'fennel_repl_jobid'))
	fn.prompt_setcallback(buffer, dead_prompt_callback)
end

---Fixed options for all newly created jobs
local jobopts = {
	on_stdout = on_stdout,
	on_stderr = on_stderr,
	on_exit   = on_exit,
	stderr_buffered = false,
	stdout_buffered = false,
}


local function repl_start(args)
	local command = args.fargs
	local binary = command[1]

	local jobid = fn.jobstart(command, jobopts)
	if jobid == 0 then
		error(string.format("Invalid arguments to '%s': %s", binary, vim.inspect(args.args)))
	elseif jobid == -1 then
		error(string.format("Program '%s' not executable", binary))
	end

	-- Set up the prompt buffer
	local buffer = api.nvim_create_buf(true, true)
	do
		nvim_buf_set_option(buffer, 'buftype', 'prompt')
		nvim_buf_set_option(buffer, 'bufhidden', 'hide')
		nvim_buf_set_option(buffer, 'buflisted', false)
		nvim_buf_set_option(buffer, 'swapfile', false)
		nvim_buf_set_option(buffer, 'filetype', 'fennel-repl')
		nvim_buf_set_var(buffer, 'fennel_repl_jobid', jobid)
		nvim_buf_set_var(buffer, 'fennel_repl_args', args.fargs)
		nvim_buf_set_var(buffer, 'fennel_repl_bin', binary)
		nvim_buf_set_name(buffer, string.format('Fennel REPL (%d)', jobid))
		fn.prompt_setprompt(buffer, BASE_PROMPT)
		fn.prompt_setcallback(buffer, active_prompt_callback)
	end

	local instance = instances:new(jobid, command, buffer)
	-- This could be a problem if the message has already arrived.
	instance.callbacks[0] = coroutine.create(cb.init)

	-- Open the REPL buffer unless it is already open
	local repl_open = false
	for _, wininfo in ipairs(fn.getwininfo()) do
		if wininfo.bufnr == buffer then
			repl_open = true
			break
		end
	end

	if not repl_open then
		-- Open the REPL buffer in a new window
		vim.cmd {cmd = 'sbuffer', args = {fn.string(buffer)}}
		vim.cmd {cmd = 'setlocal', args = {'nospell'}}
		vim.cmd 'startinsert'
	end
end

-- TODO: Should support modifiers like ':vert'
api.nvim_create_user_command('Fennel', repl_start, {desc = 'Start a Fennel REPL', nargs='*', bang=true})
