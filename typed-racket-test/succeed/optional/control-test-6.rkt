#lang racket/load

(module typed typed/racket/optional
  (provide f)

  (: f (-> Void))
  (define (f)
    (abort-current-continuation
     (default-continuation-prompt-tag)
     (λ: ([x : Number]) (+ 1 x)))))

(module untyped racket
  (require 'typed)

  (call-with-continuation-prompt
   (λ () (f))
   (default-continuation-prompt-tag)
   ;; behavioral values are not allowed to pass
   ;; through the Any contract to here
   (λ (f) (f 3))))

(require 'untyped)
