-- SPDX-License-Identifier: MIT

local generator = require 'fennel-repl.id-generator'

---Factory functions for the different kind of instruction messages.
local M = {}

-- Each incoming message is a Fennel table {:id ID OP DATA}
-- ID: a positive integer
-- OP: string key of the operation to apply to the data
-- DATA: String value to operate on

---eval: evaluate a string of Fennel code.
---@param code string  The code to evaluate
function M.eval(code)
	local id = generator:new()
	return {id = id, eval = code}
end

---complete: produce all possible completions for a given input symbol.
---@param sym string  Symbol to complete
function M.complete(sym)
	local id = generator:new()
	return {id = id, complete = sym}
end

---doc: produce documentation of a symbol.
---@param sym string  Symbol to complete
function M.doc(sym)
	local id = generator:new()
	return {id = id, doc = sym}
end

---reload: reload the module.
---@param module string  Name of the module to reload
function M.reload(module)
	local id = generator:new()
	return {id = id, reload = module}
end

---find: print the filename and line number for a given function.
function M.find(val)
	local id = generator:new()
	return {id = id, find = val}
end

---compile: compiles the expression into Lua and returns the result.
---@param expr string  Expression to compile
function M.compile(expr)
	local id = generator:new()
	return {id = id, compile = expr}
end

---apropos: produce all functions matching a pattern in all loaded modules.
---@param re string  Regular expression
function M.apropos(re)
	local id = generator:new()
	return {id = id, apropos = re}
end

---apropos-doc: produce all functions that match the pattern in their docs.
---@param re string  Regular expression
function M.apropos_doc(re)
	local id = generator:new()
	return {id = id, ['apropos-doc'] = re}
end

---apropos-show-docs: produce all documentation matching a pattern in the function name.
---@param re string  Regular expression
function M.apropos_show_docs(re)
	local id = generator:new()
	return {id = id, ['apropos-show-docs'] = re}
end

---help: show REPL message in the REPL.
---@param arg string  Keyword to get help for
function M.help(arg)
	local id = generator:new()
	return {id = id, help = arg or ''}
end

---reset: erase all REPL-local scope.
function M.reset()
	local id = generator:new()
	return {id = id, reset = ''}
end

---exit: leave the REPL.
function M.exit(arg)
	local id = generator:new()
	return {id = id, exit = arg or ''}
end

---downgrade
function M.downgrade()
	local id = generator:new()
	return {id = id, downgrade = ''}
end

---Ignore the operation.
function M.nop()
	local id = generator:new()
return {id = id, nop = ''}
end

---Maps a comma-command to the function which produces the operation message.
M.comma_ops = {
	complete = M.complete,
	doc = M.doc,
	reload = M.reload,
	find = M.find,
	compile = M.compile,
	apropos = M.apropos,
	['apropos-doc']       = M.apropos_doc,
	['apropos-show-docs'] = M.apropos_show_docs,
	help = M.help,
	reset = M.reset,
	exit = M.exit,
	nop = M.nop,
}

return M
