-- SPDX-License-Identifier: MIT

local xref = require 'fennel-repl.extra.xref'

vim.bo.expandtab = true

-- Copied from Fennel file type settings, except the period is not a keyword
-- character
vim.opt.iskeyword = {
	'!', '$', '%', '#', '*', '+', '-', '/', ':', '<', '=', '>', '?', '_',
	'a-z', 'A-Z',
	'48-57', '128-247', '124', '126', '38', '94'
}


-- Click tracebacks
vim.keymap.set('n', 'gx', xref.follow, {
	buffer = 0,
	noremap = true,
	desc = 'Follow a link under the cursor',
})

-- These mappings are only for convenience during development, I will remove
-- them later

vim.keymap.set('n', 'K', '<Plug>(FennelReplDoc)', {
	noremap = true,
	buffer = 0,
	desc = 'Look up documentation for the word under the cursor'
})

vim.keymap.set({'n', 'v'}, '<A-k>', '<Plug>(FennelReplEval)', {
	noremap = true,
	buffer = 0,
	desc = 'Look up documentation for the word under the cursor'
})

vim.keymap.set('n', '<C-C>', '<Plug>(FennelReplCancel)', {
	noremap = true,
	buffer = 0,
	desc = 'Cancels the current REPL process',
})

-- It would be nice if we could also click the traceback with the mouse
