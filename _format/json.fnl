(fn [env data]
  "Serializes the output to a JSON object."
  (: "{%s}" :format
       (table.concat
        (icollect [_ [k v] (ipairs data)]
          (: "%s: %s" :format (env.fennel.view k)
             (: (case v
                  {:list data} (.. "[" (table.concat data ",") "]")
                  {:string data} (env.fennel.view data)
                  {:sym data} (tostring data)
                  _ (env.protocol.internal-error "Wrong data kind" (env.fennel.view v)))
                :gsub "\n" "\\\\n"))) ", ")))
