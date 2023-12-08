-- SPDX-License-Identifier: MIT

local api = vim.api
local fn  = vim.fn
local nvim_buf_set_option = api.nvim_buf_set_option
local nvim_buf_get_var    = api.nvim_buf_get_var
local nvim_buf_delete     = api.nvim_buf_delete

local lib = require 'fennel-repl.lib'
local cb  = require 'fennel-repl.callback'
local gen = require 'fennel-repl.id-generator'
local instances = require 'fennel-repl.instances'

---Code to upgrade the REPL, file names will be spliced in
local BOOTSTRAP_TEMPLATE = [[
(let [{: dofile} (require :fennel)
      protocol (dofile "%s")
      format/json (dofile "%s")]
  (protocol format/json))
]]

local protocol_file = fn.fnamemodify(fn.expand('<sfile>'), ':p:h:h') .. '/_protocol/protocol.fnl'
local   format_file = fn.fnamemodify(fn.expand('<sfile>'), ':p:h:h') .. '/_format/json.fnl'
if fn.filereadable(protocol_file) == 0 then
	api.nvim_err_writeln 'Fennel REPL: missing protocol implementation. Did you check out Git submodules?'
end


---Callback for terminated Fennel process; will delete the buffer when the user
---presses <ENTER>
local function dead_prompt_callback(_text)
	nvim_buf_delete(0, {force = true})
end

local function on_stdout(job_id, data, _name)
	print('Got response: ' .. vim.inspect(data))

	---@type Instance
	local instance = instances[job_id]

	for _, line in ipairs(data) do
		local success, message = pcall(lib.decode_message, line)
		if success then
			local msgid = message.id
			local callbacks = instance.callbacks
			local callback = callbacks[msgid]
			if callback then
				coroutine.resume(callback, message)
				if coroutine.status(callback) == 'dead' then
					callbacks[msgid] = nil
					gen:drop(msgid)
				end
			else
				print(string.format('No callback for %d found in %s for job %d', msgid, vim.inspect(callbacks), job_id))
			end
		elseif not instance.is_init then
			-- Just ignore it, the REPL does not yet adhere to the protocol
		elseif line ~= '' then
			-- error(string.format("Could not decode JSON: %s\n%s", message, line))
		end
	end
	nvim_buf_set_option(0, 'modified', false)
end

---Display errors from the REPL as errors in Neovim.
local function on_stderr(_job_id, data, _name)
	api.nvim_out_write(fn.join(data, '\n'))
	api.nvim_out_write('\n')
end

local function on_exit(job_id, exit_code, _event)
	---@type Instance
	local instance = instances[job_id]
	instance:place_comment((';; Fennel terminated with exit code %d'):format(exit_code))
	local buffer = instance.buffer
	fn.prompt_setprompt(buffer, '')
	instances:drop(nvim_buf_get_var(0, 'fennel_repl_jobid'))
	fn.prompt_setcallback(buffer, dead_prompt_callback)
	api.nvim_del_current_line()  -- Remove the trailing prompt
end

---Fixed options for all newly created jobs
local jobopts = {
	on_stdout = on_stdout,
	on_stderr = on_stderr,
	on_exit   = on_exit,
	stderr_buffered = false,
	stdout_buffered = false,
}


---The actual function behind starting the REPL
local function repl_start(args)
	local command = args.fargs
	local binary = command[1]

	local jobid = fn.jobstart(command, jobopts)
	if jobid == 0 then
		error(string.format("Invalid arguments to '%s': %s", binary, vim.inspect(args.args)))
	elseif jobid == -1 then
		error(string.format("Program '%s' not executable", binary))
	end

	local instance = instances:new(jobid, command, args)
	-- Could this be a problem if the message has already arrived?
	instance.callbacks[ 0] = coroutine.create(cb.init)
	instance.callbacks[-1] = coroutine.create(cb.internal_error)
	coroutine.resume(instance.callbacks[ 0], instance)
	coroutine.resume(instance.callbacks[-1], instance)

	-- Upgrade the REPL
	-- NOTE: Love2D cannot handle line breaks in the expression
	local expr = BOOTSTRAP_TEMPLATE:gsub('\n', ' '):format(protocol_file, format_file)
	vim.fn.chansend(jobid, {expr, ''})
end

-- TODO: Should support modifiers like ':vert'
api.nvim_create_user_command('Fennel', repl_start, {desc = 'Start a Fennel REPL', nargs='*', bang=true})
