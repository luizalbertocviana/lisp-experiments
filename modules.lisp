(defvar *user-modules* nil
  "list of currently loaded user modules. This variable identifies
   modules by absolute path")

(defmacro using-when (situation &rest file-names)
  "loads a fasl for each of the corresponding file-name files, if not
   already loaded, during situation time. This also updates fasl files
   as needed. Situation must be :compiling or :loading"
  (let ((situation-toplevel (case situation
                              (:compiling :compile-toplevel)
                              (:loading   :load-toplevel)))
        (situation-truename (case situation
                              (:compiling '*compile-file-truename*)
                              (:loading   '*load-truename*))))
    `(eval-when (,situation-toplevel)
      (progn ,@(loop for fn in file-names
                     collect (let ((abs-pathname-fasl (gensym))
                                   (abs-pathname-lisp (gensym))
                                   (fn-fasl           (format nil "~a.fasl" fn))
                                   (fn-lisp           (format nil "~a.lisp" fn)))
                               `(let ((,abs-pathname-fasl (merge-pathnames ,fn-fasl ,situation-truename))
                                      (,abs-pathname-lisp (merge-pathnames ,fn-lisp ,situation-truename)))
                                  (unless (member ,abs-pathname-fasl *user-modules* :test #'equal)
                                    (unless (and (probe-file ,abs-pathname-fasl)
                                                 (>= (file-write-date ,abs-pathname-fasl)
                                                     (file-write-date ,abs-pathname-lisp)))
                                      (compile-file ,abs-pathname-lisp))
                                    (load ,abs-pathname-fasl :verbose t)
                                    (push ,abs-pathname-fasl *user-modules*)))))))))

(defmacro using (&rest file-names)
  "loads a fasl for each of the corresponding file-names files, if not
   already loaded, during both loading and compilation time. This also
   updates fasl files as needed"
  `(progn
     (using-when :compiling ,@file-names)
     (using-when :loading   ,@file-names)))
