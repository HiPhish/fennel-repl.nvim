-- SPDX-License-Identifier: MIT

local FennelRepl = require 'fennel-repl.repl'
local lib = require 'fennel-repl.lib'
local fn = vim.fn
local chansend = vim.fn.chansend

---A Fennel REPL which communicates with an external job process.
---@class (exact) FennelJobRepl: FennelRepl
---@field jobid integer?  Job ID of the REPL job
---@field args  string[]  Command arguments
---@field cmd   string    Command which started the Fennel process
---@field new   fun(self: FennelRepl, init: table?): FennelJobRepl
local FennelJobRepl = FennelRepl:new()

function FennelJobRepl:send_message(msg, callback, ...)
	local coro = coroutine.create(callback)
	coroutine.resume(coro, self, ...)
	self.callbacks[msg.id] = coro
	chansend(self.jobid, {lib.format_message(msg), ''})
end

function FennelJobRepl:on_exit()
	self.jobid = nil
end

function FennelJobRepl:terminate()
	fn.jobstop(self.jobid)
	-- No need to call on_exit manually, jobstop will do it for us via callback
end

return FennelJobRepl
