#lang typed/racket/base

(: foo (→* ((∪ Symbol String)) (Integer) (Pair Boolean Integer)))
(define foo
  (λ (s [i 0])
    (cons (symbol? s) i)))
(foo 'abc)
(foo "abc")