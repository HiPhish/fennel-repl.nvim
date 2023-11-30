local extra = require 'fennel-repl.extra.hover'

local doc = extra.doc

vim.keymap.set('n', '<Plug>(FennelReplDoc)', doc, {
	noremap = true,
	desc = 'Show documentation for the symbol under the cursor in a floating window',
})
