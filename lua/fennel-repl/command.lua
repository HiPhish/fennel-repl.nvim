-- SPDX-License-Identifier: MIT

---Implementation of the Fennel command
local M = {}

local fn  = vim.fn
local api = vim.api
local nvim_buf_set_option = api.nvim_buf_set_option
local nvim_buf_get_var    = api.nvim_buf_get_var
local nvim_buf_delete     = api.nvim_buf_delete

local instances = require 'fennel-repl.instances'
local lib = require 'fennel-repl.lib'
local cb  = require 'fennel-repl.callback'
local gen = require 'fennel-repl.id-generator'

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

	---@type FennelRepl
	local repl = instances[job_id]

	for _, line in ipairs(data) do
		local success, message = pcall(lib.decode_message, line)
		if success then
			local msgid = message.id
			local callbacks = repl.callbacks
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
		elseif not repl.is_init then
			-- Just ignore it, the REPL does not yet adhere to the protocol
		elseif line ~= '' then
			-- Ignore the output
			--
			-- NOTE: This is "unsolicited" output, which means the output has
			-- not been produced by an explicit request from the client, but by
			-- the server on its own.  There are a couple of sources of
			-- unsolicited output:
			--
			--   - A REPL might echo back the message it was sent (the default
			--     Fennel REPL does this)
			--   - A default prompt from the REPL
			--   - The server called `print` on its own (e.g. as part of the
			--     application's own source code)
			--
			-- Not all unsolicited output is bad.  If it was generated
			-- intentionally by the application source code we should display
			-- it.
		end
	end
	nvim_buf_set_option(repl.buffer, 'modified', false)
end

---Display errors from the REPL as errors in Neovim.
local function on_stderr(_job_id, data, _name)
	api.nvim_out_write(fn.join(data, '\n'))
	api.nvim_out_write('\n')
end

local function on_exit(job_id, exit_code, _event)
	---@type FennelRepl
	local repl = instances[job_id]
	repl:place_comment((';; Fennel terminated with exit code %d'):format(exit_code))
	local buffer = repl.buffer
	fn.prompt_setprompt(buffer, '')
	instances.drop(nvim_buf_get_var(repl.buffer, 'fennel_repl_jobid'))
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


---Start a new process running a Fennel REPL.
function M.start(fennel, args, mods)
	local jobid = fn.jobstart({fennel, unpack(args)}, jobopts)
	if jobid == 0 then
		error(string.format("Invalid arguments to '%s': %s", fennel, vim.inspect(args.args)))
	elseif jobid == -1 then
		error(string.format("Program '%s' not executable", fennel))
	end

	local repl = instances.new(jobid, fennel, args)
	-- Could this be a problem if the message has already arrived?
	repl.callbacks[ 0] = coroutine.create(cb.init)
	repl.callbacks[-1] = coroutine.create(cb.internal_error)
	coroutine.resume(repl.callbacks[ 0], repl, mods)
	coroutine.resume(repl.callbacks[-1], repl)

	-- Upgrade the REPL
	-- NOTE: Love2D cannot handle line breaks in the expression
	local expr = BOOTSTRAP_TEMPLATE:gsub('\n', ' '):format(protocol_file, format_file)
	vim.fn.chansend(jobid, {expr, ''})
end

-- Ideas for more sub-commands:
--   - connect  Connect to an already running process with IO connected to
--     named pipes

return M
