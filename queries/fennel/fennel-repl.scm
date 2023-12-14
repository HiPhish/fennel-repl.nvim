;; Function (optionally named)
(fn     name: (symbol)? (parameters) _) @fennel-expr
(lambda name: (symbol)? (parameters) _) @fennel-expr

;; Variable definition
(local (binding (symbol))) @fennel-expr
(var   (binding (symbol))) @fennel-expr

;; Non-empty list
(list (_) @_child (#not-eq? @_child "")) @fennel-expr

;; Top-level expression
(sequential_table) @fennel-expr
(table) @fennel-expr

;; Local variable bindings
(let (let_clause) _) @fennel-expr


;; vim:ft=query
