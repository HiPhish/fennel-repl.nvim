" SPDX-License-Identifier: MIT

runtime! syntax/fennel.vim
runtime! syntax/fennel.lua

syntax match fennelReplPrompt /^>> /
syntax match fennelReplPrompt /^\.\. /

" ,apropos-doc
syntax match fennelReplCommand /,\(\k\|-\)\+/

" #<function: builtin#123>
syntax match fennelReplFunctionRep /#<function: builtin#\d\+>/
" #<function: 0x123deadbeef>
syntax match fennelReplFunctionRep /#<function: 0x\d\+>/


" Link the special REPL highlight groups to default highlight groups
highlight default link fennelReplComment      Comment
highlight default link fennelReplPrompt       Ignore
highlight default link fennelReplCommand      Identifier
highlight default link fennelReplValue        Constant
highlight default link fennelReplError        ErrorMsg
highlight default link fennelReplWarning      WarningMsg
highlight default link fennelReplStdout       Normal
highlight default link fennelReplFunctionRep  Normal

" This is used for extmarks only and will be overlaid on top of the base group
highlight default fennelReplErrorLink gui=underline cterm=underline

let b:current_syntax = 'fennel-repl'
