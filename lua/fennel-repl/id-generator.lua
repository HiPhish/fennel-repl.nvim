-- SPDX-License-Identifier: MIT

---Holds the state of the generator.  Whenever a new ID is generated we store
---it here, when the ID is dropped we remove it.  This is effectively a "list"
---which may contain holes.  We always plug the first hole available.
---@type table<integer, boolean>  Internal state of the generator
local state = {}

---Stateful ID generator.  It creates new IDs sequentially, but it can also
---re-use previously dropped IDs.  This means the generator will fill in holes
---and will not run out of integers until every possible ID is in use.
---@class (exact) IDGenerator
---@field public new  fun(IDGenerator): integer
---@field public drop fun(IDGenerator, integer)
local M = {
	---Generate a new ID.
	---@return integer
	new = function()
		local result = 1
		for _ in ipairs(state) do
			result = result + 1
		end
		state[result] = true
		return result
	end,
	---Remove an existing ID
	---@param id  integer  Drop a previously registered job ID.
	drop = function(id)
		state[id] = nil
	end
}

return M
