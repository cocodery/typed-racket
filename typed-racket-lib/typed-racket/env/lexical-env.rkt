#lang racket/base

;; this environment maps *lexical* variables to types
;; it also contains the proposition environment

;; these environments are unified in "Logical Types for Untyped Languages"
;; but split here for performance

(require "../utils/utils.rkt"
         racket/keyword-transform racket/list
         (for-syntax syntax/parse racket/base)
         (contract-req)
         racket/match
         "../env/type-env-structs.rkt"
         "../env/global-env.rkt"
         "../types/numeric-tower.rkt"
         "../types/path-type.rkt"
         "../rep/object-rep.rkt"
         "../utils/tc-utils.rkt"
         (only-in "../rep/type-rep.rkt" Type?)
         "../typecheck/renamer.rkt"
         "../types/utils.rkt"
         "../types/kw-types.rkt"
         (except-in "../types/abbrev.rkt" -> ->* one-of/c)
         (for-template
           (only-in racket/contract/private/provide
             provide/contract-info?
             provide/contract-info-original-id)))

(require-for-cond-contract "../rep/object-rep.rkt"
                           "../rep/core-rep.rkt")

(provide lexical-env
         add-props-to-current-lexical!
         with-lexical-env
         with-extended-lexical-env
         with-naively-extended-lexical-env)
(provide/cond-contract
 [lookup-id-type/lexical ((identifier?) (env? #:fail (or/c #f Type? (-> any/c (or/c Type? #f))))
                                        . ->* .
                                        (or/c Type? #f))]
 [lookup-obj-type/lexical ((Object?) (env? #:fail (or/c #f Type? (-> any/c (or/c Type? #f))))
                                     . ->* .
                                     (or/c Type? #f))]
 [lookup-alias/lexical ((identifier?) (env?) . ->* . (or/c OptObject? #f))])

;; used at the top level
(define (add-props-to-current-lexical! ps)
  (lexical-env (env-replace-props (lexical-env) (append ps (env-props (lexical-env))))))


;; run code in an extended env
(define-syntax (with-extended-lexical-env stx)
  (syntax-parse stx
    [(_ [#:identifiers ids:expr
         #:types tys:expr
         (~optional (~seq #:aliased-objects aliased-objects:expr)
                    #:defaults ([aliased-objects #'#f]))]
        . body)
     (syntax/loc stx
       (let ([cur-env (lexical-env)]
             [idents ids]
             [types tys]
             [objs aliased-objects])
         (let*-values ([(ts pss)
                        (for/lists (_1 _2) ([id (in-list idents)]
                                            [ty (in-list types)]
                                            [obj (in-list/rest (or objs '()) #f)])
                          (extract-props (or obj (-id-path id)) ty))]
                       [(ps) (apply append pss)])
           (with-lexical-env
               (env-replace-props
                (env-extend/bindings cur-env ids ts objs)
                (append ps (env-props cur-env)))
             . body))))]))

;; find the type of identifier i, looking first in the lexical env, then in the top-level env
;; identifier -> Type
(define lookup-id-type/lexical
 (let ([fail=false (lambda () #f)])
 (lambda (i [env (lexical-env)] #:fail [fail #f])
  (env-lookup-id
   env i
   (λ (i) (lookup-type i (λ ()
                           (cond
                             [(syntax-property i 'constructor-for)
                              => (λ (prop)
                                   (define orig (un-rename prop))
                                   (define t (lookup-id-type/lexical orig env))
                                   (register-type i t)
                                   t)]
                             [(syntax-procedure-alias-property i)
                              => (λ (prop)
                                   (define orig (car (flatten prop)))
                                   (define t (lookup-id-type/lexical orig env))
                                   (register-type i t)
                                   t)]
                             [(syntax-procedure-converted-arguments-property i)
                              => (λ (prop)
                                   (define orig (car (flatten prop)))
                                   (define pre-t
                                     (lookup-id-type/lexical
                                      orig env #:fail (lambda (i) (lookup-fail i) #f)))
                                   (define t (if pre-t
                                                 (kw-convert pre-t #f)
                                                 Err))
                                   (register-type i t)
                                   t)]
                             [(and (let* ([v (and (syntax-transforming?) (not (syntax-tainted? i)) (syntax-local-value i fail=false))]
                                          [orig-id (and (provide/contract-info? v)
                                                        (provide/contract-info-original-id v))])
                                     (and (identifier? orig-id)
                                          (lookup-type orig-id fail=false))))
                              => (λ (orig-t)
                                   (register-type i orig-t)
                                   orig-t)]
                             [else ((or fail lookup-fail) i)]))))))))

(define (lookup-obj-type/lexical obj [env (lexical-env)] #:fail [fail #f])
  (match obj
    [(Path: pes x)
     #:when (not (ormap uninterpreted-PE? pes))
     (cond
       [(identifier? x)
        (or (path-type pes (lookup-id-type/lexical x env #:fail fail))
            Univ)]
       [else
        (define nm-ty (env-lookup-obj env (-id-path x) (λ (_) Univ)))
        (or (path-type pes nm-ty)
            Univ)])]
    [_
     (env-lookup-obj env obj (λ (obj) (match obj
                                        [(Path: (cons (? VecLenPE?) _) _) -Index]
                                        [(? LExp?) -Int]
                                        [_ (and fail (fail obj))])))]))

;; looks up the representative object for an id (i.e. itself or an alias if one exists)
(define (lookup-alias/lexical i [env (lexical-env)])
  (env-lookup-alias env i -id-path))
