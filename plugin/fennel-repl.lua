-- SPDX-License-Identifier: MIT

local api = vim.api
local fn  = vim.fn

local nvim_err_writeln = api.nvim_err_writeln

local protocol_file = fn.fnamemodify(fn.expand('<sfile>'), ':p:h:h') .. '/_protocol/protocol.fnl'
if fn.filereadable(protocol_file) == 0 then
	nvim_err_writeln 'Fennel REPL: missing protocol implementation. Did you check out Git submodules?'
end

local command = require 'fennel-repl.command'

local NO_HANDLER_TEMPLATE = 'Unknown Fennel REPL sub-command: %s'
local NO_FENNEL_TEMPLATE = "Missing Fennel executable in '%s'"
local START_USAGE = [[
Usage:  Fennel start [<arg> ...] [--] <fennelprg> [<arg> ...]

  <fennelprg>  The Fennel executable, such as 'fennel' or 'love'

The first set of <arg>s are arguments to this plugin, the second set of <arg>s
are arguments to the Fennel program.  Use '--' to unambiguously stop parsing
plugin arguments.]]


---Removes the first item of a list, treating it like a FIFO queue.
local function dequeue(list)
	local result = list[1]
	table.remove(list, 1)
	return result
end


---Handler for the 'start' sub-command.
local function start_handler(args)
	local mods   = args.smods
	local fargs  = fn.copy(args.fargs)
	local fennel

	while true do
		local arg = dequeue(fargs)
		if not arg then
			nvim_err_writeln(START_USAGE)
			return
		elseif arg == '--' then
			fennel = dequeue(fargs)
			break
		elseif not arg:match('^-.*') then
			fennel = arg
			break
		end
		-- Plugin arguments can be handled here.
	end

	if not fennel then
		nvim_err_writeln(NO_FENNEL_TEMPLATE:format(fn.join(args.fargs, ' ')))
		return
	end

	command.start(fennel, fargs, mods)
end


---Maps sub-commands to their respective handlers.
local subcmd_handlers = {
	start = start_handler,
}

---The actual function behind starting the REPL
local function repl_start(args)
	local subcmd = dequeue(args.fargs)

	local handler = subcmd_handlers[subcmd]
	if not handler then
		api.nvim_err_writeln(NO_HANDLER_TEMPLATE:format(subcmd))
		return
	end
	handler(args)
end

-- TODO: Should support modifiers like ':vert'
api.nvim_create_user_command('Fennel', repl_start, {desc = 'Start a Fennel REPL', nargs='*', bang=false})
