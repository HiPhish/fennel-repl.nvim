-- SPDX-License-Identifier: MIT

---Table keeping track of REPL instances and their state.  This table is
---mutable; as instances are added and removed its contents will change.  Do
---not add or remove entries manually, use the methods.
---@class FennelReplInstanceTracker: table<integer, FennelRepl>
local M = {
	---Current number of registered instances
	count = 0,
}

---Maps instance IDs to actual instance objects.
---@type table<integer, FennelRepl>
local instances = {}

---Stack of active REPL job IDs.  The last entry is most recent.
---@type integer[]
local stack = {}


---Sets up and registers a new REPL instance.
---@param instance FennelRepl  REPL instance to register
---@return FennelRepl instance  The new REPL instance object.
function M.register(instance)
	local id = instance.id
	instances[id] = instance
	M.count = M.count + 1
	table.insert(stack, id)
	return instance
end

---Unregisters a REPL instance.
---@param id integer  ID of the REPL instance
function M.drop(id)
	for i, other_id in ipairs(stack) do
		if other_id == id then
			table.remove(stack, i)
			break
		end
	end
	M.count = M.count - 1
end

---Retrieves a REPL instance from its instance ID.
---@param id integer  Instance ID
---@return FennelRepl?
function M.get(id)
	return instances[id]
end

---Returns the last REPL started, if any.
---@return FennelRepl?
function M.get_topmost()
	local id = stack[#stack]
	if not id then
		return nil
	end
	return instances[id]
end

return M
