" SPDX-License-Identifier: MIT

" Link the special REPL highlight groups to default highlight groups
highlight default link FennelReplComment Comment
highlight default link FennelReplPrompt  Constant
highlight default link FennelReplValue   Constant
highlight default link FennelReplError   ErrorMsg
highlight default link FennelReplWarning WarningMsg

" This is used for extmarks only and will be overlaid on top of the base group
highlight default FennelReplErrorLink gui=underline cterm=underline
