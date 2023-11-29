-- SPDX-License-Identifier: MIT

local lib = require 'fennel-repl.lib'

-- Click tracebacks
vim.keymap.set('n', 'gx', lib.follow_link, {
	buffer = 0,
	noremap = true,
	desc = 'Follow a link under the cursor',
})

-- Copied from Fennel file type settings, except the period is not a keyword
-- character
vim.opt.iskeyword = {
	'!', '$', '%', '#', '*', '+', '-', '/', ':', '<', '=', '>', '?', '_',
	'a-z', 'A-Z',
	'48-57', '128-247', '124', '126', '38', '94'
}

-- It would be nice if we could also click the traceback with the mouse
