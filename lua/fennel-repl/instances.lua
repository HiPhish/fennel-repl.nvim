-- SPDX-License-Identifier: MIT

---Table keeping track of REPL instances and their state.  This table is
---mutable; as instances are added and removed its contents will change.  Do
---not add or remove entries manually, use the methods.
local M = {
	count = 0,
}

---Sets up and registers a new REPL instance.
---@param jobid   number  ID of the REPL process job
---@param command string  Command executed by the OS to launch the REPL
---@param buffer  number  Buffer ID of the prompt buffer
---@return table instance  The new REPL instance object.
function M:new(jobid, command, buffer)
	local instance = {
		cmd = command,
		-- Prompt buffer ID
		buffer = buffer,
		-- Maps an ID to the corresponding callback function.  The callback will be
		-- executed when a message with that ID arrives from the server.
		callbacks = {},
		-- If the submitted code was incomplete this will hold the
		-- incomplete fragments until a complete expression has been
		-- submitted
		pending = nil,
	}
	self[jobid] = instance
	self.count = self.count + 1
	return instance
end

---Unregisters a REPL instance.
---@param jobid number  ID of the REPL process job
function M:drop(jobid)
	self[jobid] = nil
	self.count = self.count - 1
end

return M
