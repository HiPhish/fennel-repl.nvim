local hover = require 'fennel-repl.extra.hover'

local doc  = hover.doc
local eval = hover.eval

vim.keymap.set('n', '<Plug>(FennelReplDoc)', doc, {
	noremap = true,
	desc = 'Show documentation for the symbol under the cursor in a floating window',
})

vim.keymap.set({'n', 'v'}, '<Plug>(FennelReplEval)', eval, {
	noremap = true,
	desc = 'Show evaluation result of expression under the cursor; will perform side effects',
})
