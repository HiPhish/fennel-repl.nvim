-- SPDX-License-Identifier: MIT

local hover = require  'fennel-repl.extra.hover'
local buffer = require 'fennel-repl.extra.buffer'

local doc    = hover.doc
local eval   = hover.eval
local beval  = buffer.eval_toplevel
local eeval  = buffer.eval_expr
local reload = buffer.reload

vim.keymap.set('n', '<Plug>(FennelReplDoc)', doc, {
	noremap = true,
	desc = 'Show documentation for the symbol under the cursor in a floating window',
})

vim.keymap.set({'n', 'v'}, '<Plug>(FennelReplEval)', eval, {
	noremap = true,
	desc = 'Show evaluation result of expression under the cursor; will perform side effects',
})

vim.keymap.set('n', '<Plug>(FennelReplBufferToplevelEval)', beval, {
	noremap = true,
	desc = 'Evaluate the toplevel expression under the cursor',
})

vim.keymap.set('n', '<Plug>(FennelReplBufferExprEval)', eeval, {
	noremap = true,
	desc = 'Evaluate the expression under the cursor',
})

vim.keymap.set('n', '<Plug>(FennelReplBufferReload)', reload, {
	noremap = true,
	desc = 'Reloads the Fennel module of the current buffer',
})
