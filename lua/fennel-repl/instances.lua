-- SPDX-License-Identifier: MIT

---Table keeping track of REPL instances and their state.  This table is
---mutable; as instances are added and removed its contents will change.  Do
---not add or remove entries manually, use the methods.
---@class FennelReplInstanceTracker: table<integer, FennelRepl>
local M = {
	---Current number of registered instances
	count = 0,
}

local Repl = require 'fennel-repl.repl'

---Stack of active REPL job IDs.  The last entry is most recent.
---@type integer[]
local stack = {}


---Sets up and registers a new REPL instance.
---@param jobid   integer  ID of the REPL process job
---@param command string   Command executed by the OS to launch the REPL
---@param args    string[] Command arguments
---@return FennelRepl instance  The new REPL instance object.
function M.new(jobid, command, args)
	local instance = Repl.new(jobid, command, args)
	M[jobid] = instance
	M.count = M.count + 1
	table.insert(stack, jobid)
	return instance
end

---Unregisters a REPL instance.
---@param jobid integer  ID of the REPL process job
function M.drop(jobid)
	M[jobid] = nil
	for i, other_id in ipairs(stack) do
		if other_id == jobid then
			table.remove(stack, i)
			break
		end
	end
	M.count = M.count - 1
end

---Returns the last REPL started, if any.
---@return FennelRepl?
function M.get_topmost()
	local job_id = stack[#stack]
	if not job_id then
		return nil
	end
	return M[job_id]
end

return M
