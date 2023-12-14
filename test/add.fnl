;;; Just a file for trying out syntax patterns

(fn add [x y]
  (if (= y 0)
    x
    (add (+ x 1) (- y 1))))

(lambda add [x y]
  (if (= y 0)
    x
    (add (+ x 1) (- y 1))))

(do
  (fn add [x y]
    (if (= y 0)
      x
      (add (+ x 1) (- y 1)))))

(local add (fn [x y]
  (if (= y 0)
    x
    (add (+ x 1) (- y 1)))))

(do
  (var x 9)
  x)

(x)
((fn [x] x) 9)
((λ [x] x) 9)
()

(let [x 1
      y 2]
  (print (+ x y)))

(+ 3 4)

{: add}
