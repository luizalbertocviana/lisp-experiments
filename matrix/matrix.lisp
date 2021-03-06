(defpackage :matrix
  (:use :common-lisp :macros)
  (:shadow :aref :identity)
  (:export
     :matrix :new-matrix :copy-matrix :matrix-p :matrix-number-rows :matrix-number-cols :matrix-type
     :square-matrix :identity
     :aref
     :reduce-two-matrices :reduce-matrices
     :add :sum
     :multiply :incf-product))

(in-package :matrix)

(defstruct (matrix)
  "represnets a matrix"
  (data        nil :type (simple-array))
  (type)
  (number-rows nil :type (integer 0))
  (number-cols nil :type (integer 0)))

(defun new-matrix (&key (type 'number) number-rows number-cols (initial-element 0))
  "creates a matrix with elements typed to type (defaults to number)
  whose dimensions are determined by number-rows and number-cols. All
  positions are initialized as initial-element (defaults to 0)"
  (make-matrix :data (make-array `(,number-rows ,number-cols)
                                 :element-type type
                                 :initial-element (coerce initial-element type))
               :type type
               :number-rows number-rows
               :number-cols number-cols))

(defun square-matrix (&key (type 'number) dimension (initial-element 0))
  "creates a square matrix with elements typed to type (defaults to
  number) and dimension. All positions are initialized as
  initial-element"
  (new-matrix :type            type
              :number-rows     dimension
              :number-cols     dimension
              :initial-element initial-element))

(defun aref (matrix row col)
  "element of matrix at position (row col)"
  (cl:aref (matrix-data matrix) row col))

(defun (setf aref) (value matrix row col)
  "sets (row col) position of matrix to value"
  (setf (cl:aref (matrix-data matrix) row col) value))

(defun identity (&key (type 'number) dimension)
  "creates an identity matrix"
  (let ((id (square-matrix :type      type
                           :dimension dimension)))
    (dotimes (i dimension)
      (setf (aref id i i) (coerce 1 type)))
    id))

(defun new-matrix-like (matrix)
  "creates a new matrix with the same dimensions and element type of
matrix"
  (new-matrix :type (matrix-type matrix)
              :number-rows (matrix-number-rows matrix)
              :number-cols (matrix-number-cols matrix)))

(defun reduce-two-matrices (op matrix-a matrix-b &key (result nil))
  "reduces matrix-a and matrix-b applying op position-wise. Result is
stored in result. If result is nil, a new matrix is allocated"
  (unless result
    (setf result (new-matrix-like matrix-a)))
  (dotimes (i (matrix-number-rows matrix-a))
    (dotimes (j (matrix-number-cols matrix-a))
      (setf (aref result i j)
            (funcall op
                     (aref matrix-a i j)
                     (aref matrix-b i j)))))
  result)

(defun reduce-matrices-with-reductor (op reductor matrices &key (result nil) (allocator-like #'new-matrix-like))
  "reduces matrices applying op position-wise using reductor. Result
  is stored in result. If result is nil, a new matrix is allocated using allocator-like"
  (when matrices
    (unless result
      (setf result (funcall allocator-like (first matrices))))
    (loop for mtx in matrices
          do (funcall reductor op result mtx :result result))
    result))

(defun reduce-matrices (op matrices &key (result nil))
  "reduces matrices applying op position-wise. Result is stored in
  result. If result is nil, a new matrix is allocated"
  (funcall #'reduce-matrices-with-reductor op #'reduce-two-matrices matrices :result result))

(defun sum (matrices &key (result nil))
  "sums matrices, storing result in result. If result is nil, a new
matrix is allocated"
  (funcall #'reduce-matrices #'+ matrices :result result))

(defun product (matrix-a matrix-b &key (result nil))
  "sums to result the product of matrix-a and matrix-b. If result is
nil, a new matrix is allocated"
  (unless result
    (setf result
          (new-matrix :type (matrix-type matrix-a)
                      :number-rows (matrix-number-rows matrix-a)
                      :number-cols (matrix-number-cols matrix-b))))
  (dotimes (i (matrix-number-rows matrix-a))
    (dotimes (j (matrix-number-cols matrix-b))
      (dotimes (k (matrix-number-cols matrix-a))
        (incf (aref result i j)
              (* (aref matrix-a i k)
                 (aref matrix-b k j))))))
  result)

(defgeneric add (matrix-a matrix-b)
  (:documentation "returns result of adding matrix-a and matrix-b"))

(defgeneric multiply (matrix-a matrix-b)
  (:documentation "returns product of matrix-a and matrix-b"))

(defmethod add ((matrix-a matrix) (matrix-b matrix))
  (sum '(matrix-a matrix-b)))

(defmethod multiply ((matrix-a matrix) (matrix-b matrix))
  (product matrix-a matrix-b))
