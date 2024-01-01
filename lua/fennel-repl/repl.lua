-- SPDX-License-Identifier: MIT

local api = vim.api
local fn  = vim.fn
local rb  = require 'fennel-repl.ring-buffer'
local lib = require 'fennel-repl.lib'

local nvim_buf_add_highlight = api.nvim_buf_add_highlight
local nvim_buf_line_count    = api.nvim_buf_line_count

---@class (exact) FennelReplLink
---Link to a file location, usually from a stack trace.
---@field file string   File name
---@field lnum integer  Line number

---Prototype object of all Fennel REPL instances.
---@class FennelRepl
---
---Whether the REPL has been initialised yet
---@field is_init boolean
---
---Prompt buffer ID
---@field buffer integer?
---
---Pending coroutine callbacks.  Maps an ID to the corresponding callback
---function.  The callback will be executed when a message with that ID
---arrives from the server.
---@field callbacks table
---
---Incomplete command fragments.  If the submitted code was incomplete this
---will hold the incomplete fragments until a complete expression has been
---submitted
---@field pending string?
---
---Map of extmarks to file positions.  When a traceback contains a
---reference to a file and line number we store the corresponding
---extmark here.  When the user clicks the extmark we look up the
---location in this table.
---@field links table<integer, FennelReplLink>
---
---Ring buffer of previous messages sent to the server.
---@field history  RingBuffer
---
---Protocol version in use
---@field protocol string?  
---
---Running Fennel version
---@field fennel string?  
---
---Running Lua version
---@field lua string?  
local FennelRepl = {
	---Internal ID of this REPL instance
	---@type integer
	id = 0,
	is_init = false,
	buffer = nil,
	callbacks = {},
	pending = nil,
	links = {},
	history = rb.new(3),
	protocol = nil,
	fennel = nil,
	lua = nil,
}


---@param text     string
---@param hlgroup  string?
function FennelRepl:place_text(text, hlgroup)
	local buffer = self.buffer
	local start_line = nvim_buf_line_count(buffer) - 2
	for i, line in ipairs(fn.split(lib.unescape(text), '\n')) do
		local linenr = start_line + i
		api.nvim_buf_call(buffer, function()
			fn.append(linenr, line)
		end)
		if hlgroup then
			nvim_buf_add_highlight(buffer, -1, hlgroup, linenr, 0, -1)
		end
	end
end

---Place text output in the REPL buffer
---@param text string
function FennelRepl:place_output(text)
	self:place_text(text, 'fennelReplStdout')
end


---Place an evaluation result in the REPL buffer.
---@param text string
function FennelRepl:place_value(text)
	self:place_text(text, 'fennelReplValue')
end

---Place a comment in the REPL buffer
---@param text string
function FennelRepl:place_comment(text)
	self:place_text(text, 'fennelReplComment')
end

---Place an error message in the REPL buffer
---@param text string
function FennelRepl:place_error(text)
	self:place_text(text, 'fennelReplError')
end

function FennelRepl:send_message(_msg, _callback, ...)
	error 'Not implemented in abstract base class.'
end

---Perform any necessary cleanup for when the REPL is exited.  Override this
---method in subclasses.
function FennelRepl:on_exit()
	return nil  -- Intentionally nothing
end

---Stop the REPL for whatever reason.  Override this method in subclasses.
function FennelRepl:terminate()
	self:on_exit()
	return nil  -- Intentionally nothing
end

---Increment this for each new instance.
local counter = 0

---Instantiates a new Fennel REPL from the prototype and a given table with
---initial values.
---@param initial table?  Table of initial values, will be mutated.
---@return FennelRepl instance  The full Fennel REPL instance.
function FennelRepl:new(initial)
	local result = initial or {}
	counter = counter + 1
	result.id = counter
	self.__index = self
	setmetatable(result, self)
	return result
end

-- return M
return FennelRepl
