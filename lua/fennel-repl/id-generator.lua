-- SPDX-License-Identifier: MIT

---Stateful ID generator.  It creates new IDs sequentially, but it can also
---re-use previously dropped IDs.  This means the generator will fill in holes
---and will not run out of integers until every possible ID is in use.
local id_generator = {
	_state = {},
	new = function(self)
		local result = 1
		for _ in ipairs(self._state) do
			result = result + 1
		end
		self._state[result] = true
		return result
	end,
	drop = function(self, id)
		self._state[id] = nil
	end
}

return id_generator
