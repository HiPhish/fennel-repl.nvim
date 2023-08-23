-- SPDX-License-Identifier: MIT

local lib = require 'fennel-repl.lib'

-- Click tracebacks
vim.keymap.set('n', 'gx', lib.follow_link, {
	buffer = 0,
	noremap = true,
	desc = 'Follow a link under the cursor',
})

-- It would be nice if we could also click the traceback with the mouse
