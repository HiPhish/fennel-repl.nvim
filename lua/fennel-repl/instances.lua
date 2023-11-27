-- SPDX-License-Identifier: MIT

---Table keeping track of REPL instances and their state.  This table is
---mutable; as instances are added and removed its contents will change.  Do
---not add or remove entries manually, use the methods.
---@class InstanceManager: table<integer, Instance>
---@field count integer  Current number of registered instances
local M = {
	count = 0,
}

local rb = require 'fennel-repl.ring-buffer'


---@class (exact) Link
---Link to a file location, usually from a stack trace.
---@field file string   File name
---@field lnum integer  Line number

---@class (exact) Instance
---Running instance of a Fennel REPL.
---@field cmd       string   Command which started the Fennel process
---@field buffer    integer  Prompt buffer ID
---@field callbacks table    Pending coroutine callbacks
---@field pending   string?  Incomplete command fragments
---@field links     table<integer, Link>  Maps extmarks to file positions
---@field history   RingBuffer
---@field protocol  string?  Protocol version in use
---@field fennel    string?  Running Fennel version
---@field lua       string?  Running Lua version

---Sets up and registers a new REPL instance.
---@param jobid   integer  ID of the REPL process job
---@param command string   Command executed by the OS to launch the REPL
---@param buffer  integer  Buffer ID of the prompt buffer
---@return Instance instance  The new REPL instance object.
function M:new(jobid, command, buffer)
	---@type Instance
	local instance = {
		cmd = command,
		buffer = buffer,
		-- Maps an ID to the corresponding callback function.  The callback will be
		-- executed when a message with that ID arrives from the server.
		callbacks = {},
		-- If the submitted code was incomplete this will hold the
		-- incomplete fragments until a complete expression has been
		-- submitted
		pending = nil,
		---Map of extmarks to file positions.  When a traceback contains a
		---reference to a file and line number we store the corresponding
		---extmark here.  When the user clicks the extmark we look up the
		---location in this table.
		links = {},
		---Ring buffer of previous messages sent to the server.
		history = rb.new(3),
	}
	self[jobid] = instance
	self.count = self.count + 1
	return instance
end

---Unregisters a REPL instance.
---@param jobid integer  ID of the REPL process job
function M:drop(jobid)
	self[jobid] = nil
	self.count = self.count - 1
end

return M
