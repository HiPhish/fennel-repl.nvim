-- Additional file type settings for Fennel buffers.  Delete this file after
-- development is done!  We do not want to ship default key bindings.

vim.keymap.set('n', '<leader>st', '<Plug>(FennelReplBufferToplevelEval)', {
	noremap = true,
	buffer = 0,
})

vim.keymap.set('n', '<leader>se', '<Plug>(FennelReplBufferExprEval)', {
	noremap = true,
	buffer = 0,
})

vim.keymap.set('n', '<leader>sb', '<Plug>(FennelReplBufferReload)', {
	noremap = true,
	buffer = 0,
})
