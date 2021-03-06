#!dist/build/silence/silence -f

; higher-order.fl
; written by Nathaniel Symer, 2.15.16
;
; This is an example of some of the Haskell-esque
; programming you can do with this language!

(import "stdlib.sl")

; using curried functions
(display
  (map
    (+ 1) ; curried function
    '(0 1 2)))
  
;
; string manipulation
;

; capitalize a "character" (ASCII integer)
(func 'to-upper (c)
  (if (&& (>= c 97) (<= c 122))
    (- c 32) c))
    
(func 'printables (str)
  (filter (< 31) str))

(let! 'upcase (map to-upper))

(print
  (upcase "this is my f&*^ing pony, damnit!\n"))
  
(print
  ((. upcase printables) ; we can define pointfree functions!
  "a\0\0\0"))
(print "\n") ; print a newline