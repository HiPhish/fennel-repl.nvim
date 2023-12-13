-- SPDX-License-Identifier: MIT

---Table keeping track of REPL instances and their state.  This table is
---mutable; as instances are added and removed its contents will change.  Do
---not add or remove entries manually, use the methods.
---@class InstanceManager: table<integer, Instance>
---@field count integer  Current number of registered instances
local M = {
	count = 0,
}

local api = vim.api
local fn  = vim.fn
local rb  = require 'fennel-repl.ring-buffer'
local lib = require 'fennel-repl.lib'

local nvim_buf_add_highlight = api.nvim_buf_add_highlight
local nvim_buf_line_count    = api.nvim_buf_line_count
local chansend = fn.chansend


---@class (exact) Link
---Link to a file location, usually from a stack trace.
---@field file string   File name
---@field lnum integer  Line number

---@class (exact) Instance
---Running instance of a Fennel REPL.
---@field is_init   boolean  Whether the REPL has been initialised yet
---@field cmd       string   Command which started the Fennel process
---@field args      string[] Command arguments
---@field jobid     integer  Job ID of the REPL job
---@field buffer    integer? Prompt buffer ID
---@field callbacks table    Pending coroutine callbacks
---@field pending   string?  Incomplete command fragments
---@field links     table<integer, Link>  Maps extmarks to file positions
---@field history   RingBuffer
---@field protocol  string?  Protocol version in use
---@field fennel    string?  Running Fennel version
---@field lua       string?  Running Lua version
---@field place_value   fun(self: Instance, text: string): nil
---@field place_comment fun(self: Instance, text: string): nil
---@field place_output  fun(self: Instance, text: string): nil
---@field place_error   fun(self: Instance, text: string): nil
---Send a message to the REPL
---@field send_message  fun(self: Instance, msg: table, cb: function, ...): nil


---@param instance Instance
---@param text     string
---@param hlgroup  string?
local function place_text(instance, text, hlgroup)
	local buffer = instance.buffer
	local start_line = nvim_buf_line_count(buffer) - 2
	for i, line in ipairs(fn.split(lib.unescape(text), '\n')) do
		local linenr = start_line + i
		fn.append(linenr, line)
		if hlgroup then
			nvim_buf_add_highlight(0, -1, hlgroup, linenr, 0, -1)
		end
	end
end

---Place text output in the REPL buffer
---@param self Instance
---@param text string
local function place_output(self, text)
	place_text(self, text, 'fennelReplStdout')
end


---Place an evaluation result in the REPL buffer.
---@param self Instance
---@param text string
local function place_value(self, text)
	place_text(self, text, 'fennelReplValue')
end

---Place a comment in the REPL buffer
---@param self Instance
---@param text string
local function place_comment(self, text)
	place_text(self, text, 'fennelReplComment')
end

---Place an error message in the REPL buffer
---@param self Instance
---@param text string
local function place_error(self, text)
	place_text(self, text, 'fennelReplError')
end

---Send a message to the REPL
---@param self Instance
---@param msg      table     The message object to send
---@param callback function  Callback function, will be wrapped in a coroutine
---@param ...      any       Initial arguments to callback
local function send_message(self, msg, callback, ...)
	local coro = coroutine.create(callback)
	coroutine.resume(coro, self, ...)
	self.callbacks[msg.id] = coro
	chansend(self.jobid, {lib.format_message(msg), ''})
end


---Sets up and registers a new REPL instance.
---@param jobid   integer  ID of the REPL process job
---@param command string   Command executed by the OS to launch the REPL
---@param args    string[] Command arguments
---@return Instance instance  The new REPL instance object.
function M:new(jobid, command, args)
	---@type Instance
	local instance = {
		is_init = false,
		cmd = command,
		args = args,
		jobid = jobid,
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

		place_value   = place_value,
		place_comment = place_comment,
		place_output  = place_output,
		place_error   = place_error,

		send_message = send_message,
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
