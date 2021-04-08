(defpackage :array
  (:use :common-lisp :macros))

(in-package :array)

(defun build-static-traversal-code (arr n body &key (unroll 1))
  (multiple-value-bind (quot rem) (truncate n unroll)
    (let ((remaining-base (- n rem)))
      (with-gensyms (i base)
        `(let ((,base 0))
           (dotimes (,i ,quot)
             ,@(loop for offset from 0 to (1- unroll)
                     collect `(symbol-macrolet ((idx (+ ,base ,offset))
                                                (elt (aref ,arr
                                                           (+ ,offset ,base))))
                                ,@body))
             (incf ,base ,unroll))
           ,@(loop for r from 0 to (1- rem)
                   collect `(symbol-macrolet ((idx ,(+ remaining-base r))
                                              (elt (aref ,arr
                                                         ,(+ remaining-base r))))
                              ,@body)))))))

(defmacro traversal ((arr n &key (unroll 1)) &body body)
  (build-traversal-code arr n body :unroll unroll))
(defun build-dynamic-traversal-code (arr n body &key (unroll 1))
  (let ((exec-lambda-body `(funcall (lambda () ,@body))))
   (with-gensyms (once-n quot rem base remaining-base i r)
    `(let ((,once-n ,n))
       (multiple-value-bind (,quot ,rem) (truncate ,once-n ,unroll)
         (let ((,base 0)
               (,remaining-base (- ,once-n ,rem)))
           (dotimes (,i ,quot)
             ,@(loop for offset from 0 to (1- unroll)
                     collect `(symbol-macrolet ((idx (+ ,base ,offset))
                                                (elt (aref ,arr
                                                           (+ ,base ,offset))))
                                ,exec-lambda-body))
             (incf ,base ,unroll))
           (dotimes (,r ,rem)
             (symbol-macrolet ((idx (+ ,remaining-base ,r))
                               (elt (aref ,arr
                                          (+ ,remaining-base ,r))))
               ,exec-lambda-body))))))))

