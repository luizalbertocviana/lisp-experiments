(defvar *user-modules* nil
  "list of currently loaded user modules. This variable identifies
   modules by absolute path")

(defun loaded (name)
  "returns t iff name is a member of *base-path* (module is
   loaded). Name should be a fasl absolute path. This is intended for
   internal use"
  (member name *user-modules* :test #'equal))

(defun register (name)
  "add name to *user-modules*. Name must be an fasl absolute
   path. Intended for internal use"
  (push name *user-modules*))

(defvar *compilation-depth* 0
  "this variable indicates in which direction modules are being
   compiled. If a top-down compilation is taking place, this variable
   should be positive; if a bottom-up compilation is happenning, its
   value should be negative; if no compilation is in course, its value
   is zero")

(defun bottom-up-compilation ()
  "returns t iff *compilation-depth* is negative"
  (minusp *compilation-depth*))

(defun top-down-compilation ()
  "returns t iff *compilation-depth* is positive"
  (plusp *compilation-depth*))

(defun no-compilation ()
  (zerop *compilation-depth*))

(defparameter *base-path* #.(or *compile-file-truename* *load-truename*)
  "absolute path of modules.lisp file. This is used as the root of the
   project. This way, you should put modules.lisp at the root of your
   project so you can properly use these macros")

(defun abs-base-path (name)
  "returns absolute path of name based on *base-path*"
  (merge-pathnames name *base-path*))

(defmacro using-when (situation &rest file-names)
  "loads a fasl for each of the corresponding file-name files, if not
   already loaded or outdated, during situation time. This also
   updates fasl files as needed. Situation must be :compiling or
   :loading"
  `(eval-when (,situation)
     (progn ,@(loop for fn in file-names
                    collect (let* ((fn-fasl              (format nil "~a.fasl" fn))
                                   (fn-lisp              (format nil "~a.lisp" fn))
                                   (abs-pathname-fasl    (abs-base-path fn-fasl))
                                   (abs-pathname-lisp    (abs-base-path fn-lisp))
                                   (fasl-membership-test (gensym))
                                   (fasl-updated-test    (gensym)))
                              ;; creates absolute paths for both fasl
                              ;; and lisp files, based on current
                              ;; file being compiled/loaded
                              `(let ((,fasl-membership-test (loaded ,abs-pathname-fasl))
                                     (,fasl-updated-test    (and (probe-file ,abs-pathname-fasl)
                                                                 (>= (file-write-date ,abs-pathname-fasl)
                                                                     (file-write-date ,abs-pathname-lisp)))))
                                 ;; if module is not loaded or is
                                 ;; outdated
                                 (unless (and ,fasl-membership-test ,fasl-updated-test)
                                   ;; update module in case it is
                                   ;; outdated and no bottom-up
                                   ;; compilation is taking place
                                   (unless (or ,fasl-updated-test (bottom-up-compilation))
                                     (incf *compilation-depth*)
                                     (unwind-protect
                                          (compile-file ,abs-pathname-lisp)
                                       (decf *compilation-depth*)))
                                   ;; load module
                                   (load ,abs-pathname-fasl :verbose t))))))))

(defmacro using (&rest file-names)
  "loads a fasl for each of the corresponding file-names files, if not
   already loaded, during both loading and compilation time. This also
   updates fasl files as needed"
  `(progn
     ;; prepares to load modules during both compilation and loading
     ;; times
     (using-when :compile-toplevel ,@file-names)
     (using-when :load-toplevel    ,@file-names)))

(defmacro module (name)
  "registers module in *user-modules*. This macro should be used at
   the end of a file, so it only registers it if loading was
   successful"
  (let* ((name-fasl         (format nil "~a.fasl" name))
         (abs-pathname-fasl (abs-base-path name-fasl)))
    `(eval-when (:load-toplevel)
       (unless (loaded ,abs-pathname-fasl)
         (register ,abs-pathname-fasl)))))

(defmacro used-by (&rest file-names)
  "this macro should be used as the last form in a file. After the
   other forms of a file containing this macro are compiled, each of
   file-names lisp files is compiled as well. Useful for updating
   macro applications"
  `(eval-when (:compile-toplevel)
     (progn ,@(loop for fn in file-names
                    collect (let* ((fn-lisp           (format nil "~a.lisp" fn))
                                   (fn-fasl           (format nil "~a.fasl" fn))
                                   (abs-pathname-lisp (abs-base-path fn-lisp))
                                   (abs-pathname-fasl (abs-base-path fn-fasl)))
                              `(unless (top-down-compilation)
                                 (decf *compilation-depth*)
                                 (unwind-protect
                                      (compile-file ,abs-pathname-lisp)
                                   (incf *compilation-depth*))
                                 (when (loaded ,abs-pathname-fasl)
                                   (load ,abs-pathname-fasl))))))))
