#lang typed/racket/shallow

;; Chaperoned struct predicates must be wrapped in a contract.
;; (Even though `struct-predicate-procedure?` will return
;;  true for these values)

(module untyped racket
  (struct s ())
  (define s?? (chaperone-procedure s? (lambda (x) (x) x)))
  ;; provide enough names to trick #:struct
  (provide s struct:s (rename-out [s?? s?])))

(require/typed 'untyped
  [#:struct s ()])

(define (fail-if-called)
  (error 'pr226 "Untyped code invoked a higher-order value passed as 'Any'"))

(require typed/rackunit)
(check-exn #rx"Untyped code invoked a higher-order value"
  (lambda () (s? fail-if-called)))
