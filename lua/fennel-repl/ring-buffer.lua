-- SPDX-License-Identifier: MIT


---A ring buffer module
---
---A ring buffer has a given maximum size; adding a new element past the
---capacity -drops the oldest element.  A ring buffer may be empty.
local M = {}


---@class RingBuffer
---@field public get  fun(self: RingBuffer, position: integer): any
---@field public set  fun(self: RingBuffer, position: integer, value: any)
---@field public put  fun(self: RingBuffer, value: any): any
---@field public size fun(self: RingBuffer): integer
---@field package _capacity  integer  Capacity of the buffer
---@field package _oldest    integer  Index of the currently oldest item


---@param self  RingBuffer
---@return integer size  Current size of the ring buffer
local function size(self)
	return table.maxn(self)
end


---Converts an index in buffer coordinates to table coordinates.
local function convert_index(buffer, index)
	if index == 0 then
		error 'Invalid ring buffer index: 0'
	end
	if index > buffer:size() then
		error(string.format('Index out of bounds: %d > %d', index, buffer:size()))
	end

	if index > 0 then
		index = index % buffer:size()
	else
		index = index % buffer:size() + 1
	end
	return buffer._oldest + index % buffer:size()
end


---Append a new value to the end of the buffer, possibly dropping a previous
---value.
---@param self  RingBuffer
---@param value any
---@return any previous  The previous value at that position, may be nil.
local function put(self, value)
	local previous
	if self._oldest == 0 then
		table.insert(self, value)
		self._oldest = 1
		return
	elseif self:size() < self._capacity then
		table.insert(self, value)
		return
	else
		previous = self[self._oldest]
		self[self._oldest] = value
		self._oldest = self._oldest + 1
		if self._oldest > self:size() then
			self._oldest = 1
		end
	end
	return previous
end


---Gets an element from the ring buffer
---@param self   RingBuffer  The buffer instance
---@param index  integer     Relative to the current beginning
---@return any value  The value
local function get(self, index)
	local i = convert_index(self, index)
	return self[i]
end

---Sets the value of an existing entry in the buffer.
---@param self  RingBuffer
local function set(self, index, value)
	local i = convert_index(self, index)
	self[i] = value
end


---@param capacity integer  Capacity of the buffer
---@return RingBuffer buffer  The new ring buffer
function M.new(capacity)
	---@type RingBuffer
	local result = {
		_capacity = capacity,
		_oldest = 0,
		put = put,
		size = size,
		get = get,
		set = set,
	}
	return result
end


return M
