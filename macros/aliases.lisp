(defpackage :aliases
  (:use :common-lisp :macros)
  (:export
     :with-expressions :keep-if))

(in-package :aliases)

(aliases
 with-expressions symbol-macrolet
 keep-if          remove-if-not)
