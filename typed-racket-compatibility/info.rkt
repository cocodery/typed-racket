#lang info

(define collection 'multi)

(define deps '("scheme-lib"
               "typed-racket-lib"
               ("base" #:version "8.5.0.3")))


(define pkg-desc "compatibility library for older Typed Racket-based languages")

(define pkg-authors '(samth stamourv))

(define version "1.8")

(define license
  '(Apache-2.0 OR MIT))
