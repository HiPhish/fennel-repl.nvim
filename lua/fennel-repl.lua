-- SPDX-License-Identifier: MIT

---Public API.  Use this module when developing new plugins on top of this
---plugin.
local M = {}

local const = require 'fennel-repl.const'
local instances = require 'fennel-repl.instances'

---Namespace for all Fennel REPL extmarks.
M.namespace = const.namespace
M.get_instance = instances.get


return M
