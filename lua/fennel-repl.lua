-- SPDX-License-Identifier: MIT

---Public API.  Use this module when developing new plugins on top of this
---plugin.
local M = {}

local lib = require 'fennel-repl.lib'
local instances = require 'fennel-repl.instances'

---Namespace for all Fennel REPL extmarks.
M.namespace = lib.namespace

---Returns a Fennel REPL instance with the given Job ID.
---@param jobid integer  ID of the REPL job
---@return FennelRepl
function M.get_instance(jobid)
	return instances[jobid]
end


return M
