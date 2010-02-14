;;; -*- Mode: lisp; Syntax: ansi-common-lisp; Base: 10; Package: de.setf.utility.implementation; -*-

;;;
;;; A CLOS model for MIME types.
;;;
;;; See : (among others)
;;;  http://en.wikipedia.org/wiki/MIME
;;;  http://tools.ietf.org/html/rfc2046 : (MIME) Part Two: Media Types
;;;  http://tools.ietf.org/html/rfc2049 : (MIME) Part Five: Conformance Criteria and Examples
;;;
;;; 20100106 james.anderson : added octet-stream

(in-package :de.setf.utility.implementation)

(eval-when (:execute :load-toplevel :compile-toplevel)
  (defParameter *mime-type-package* (find-package :de.setf.utility.mime.type)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun intern-mime-type-key (name &key (if-does-not-exist :error))
    (or (find-symbol (setf name (string-upcase name)) *mime-type-package*)
        (ecase if-does-not-exist
          ((nil) nil)
          (:error (error "undefined mime type keyword: ~s." name))
          (:create (setf name (intern name *mime-type-package*))
                   (export name *mime-type-package*)
                   name)))))

(defMacro def-mime-type-key (symbol &rest args)
  (setf symbol (apply #'intern-mime-type-key symbol args))
  `(defvar ,symbol ',symbol))
(defmacro defmimetypekey (symbol)
  `(def-mime-type-key ,symbol))

(def-mime-type-key "APPLICATION")
(def-mime-type-key "HTML")
(def-mime-type-key "IMAGE")
(def-mime-type-key "JSON")
(def-mime-type-key "PLAIN")
(def-mime-type-key "SVG")
(def-mime-type-key "SVG+XML")
(def-mime-type-key "TEXT")
(def-mime-type-key "XML")
(def-mime-type-key "XHTML")
(def-mime-type-key "XHTML+XML")
(def-mime-type-key "*")

(defmacro def-mime-type ((major minor) &optional supers slots &rest options)
  "define three mime type classes: one each for the major ane minor type , and one for
   the specific type which specializes the two general types.
   define and bind static instances for each class."
  (setf major (intern-mime-type-key major)
        minor (intern-mime-type-key minor))
  (flet ((defvar-form (class-name)
           `(if (boundp ',class-name)
              (unless (typep ,class-name ',class-name)
                (error "invalid mime type constant for type '~a': ~s."
                       ',class-name ,class-name))
              (defvar ,class-name (make-instance ',class-name)))))
    (let ((class-name (intern-mime-type-key (format nil "~a/~a" major minor)
                                            :if-does-not-exist :create)))
      ;; for the compiler
      (proclaim `(special ,class-name))
      ;; if the monor type is wild, then this is a major-type definition
      ;; otherwise, it's a concrete mime type.
      ;; define the class - either just the major, or the concrete and
      ;; the minor; export the names and bind them to constant instances.
      (if (eq minor 'mime:*)
        `(progn                         ; a prog1 form cause class-not-found error in mcl
           (defclass ,class-name (major-mime-type)
             ((major-type :initform ',major :allocation :class) ,@slots)
             ,@options)
           (eval-when (:execute :compile-toplevel :load-toplevel)
             (declaim (special ,class-name))
             (export ',class-name *mime-type-package*))
           ,(defvar-form class-name)
           (find-class ',class-name))
        (let ((major-class-name (intern-mime-type-key (format nil "~a/~a" 
                                                              major "*")
                                                      :if-does-not-exist
                                                      :create))
              (minor-class-name (intern-mime-type-key (format nil "~a/~a"
                                                              "*" minor)
                                                      :if-does-not-exist
                                                      :create)))
          (proclaim `(special ,minor-class-name))
          `(progn 
             (eval-when (:execute :load-toplevel)
               (export '(,class-name ,minor-class-name ,major-class-name)
                       *mime-type-package*))
             (progn ;; always do it unless (find-class ',minor-class-name nil)
               (defclass ,minor-class-name (minor-mime-type)
                 ((minor-type :initform ',minor :allocation :class)))
               (eval-when (:execute :compile-toplevel :load-toplevel)
                 (declaim (special ,minor-class-name)))
               ,(defvar-form minor-class-name))
             (prog1                     ; see above re major type definition
                                        ; nb. progn . find-class failed in ccl-1.4
               (defclass ,class-name ( ,@supers ,major-class-name ,minor-class-name mime:*/*)
                 ((expression :allocation :class :initform '(,(intern (string major) :keyword)
                                                             ,(intern (string minor) :keyword)))
                  ,@slots)
                 ,@options)
               ,(defvar-form class-name))))))))

(defmacro defmimetype (&rest args)
  `(def-mime-type ,@args))

(defclass mime-type ()
   ((expression :allocation :class :reader mime-type-expression :initform nil)))

#+(or)                                  ; no longer suffices once w/ charset
(defmethod make-load-form ((instance mime-type) &optional environment)
  (declare (ignore environment))
  `(make-instance ',(type-of instance)))

(defmethod make-load-form ((instance mime-type) &optional environment)
  "Compute a load form which includes any slots, eg. charset."
  (make-load-form-saving-slots instance :environment environment))

(defgeneric mime-type-p (datum)
  (:method ((datum mime-type)) t)
  (:method ((datum t)) nil))

(defclass major-mime-type (mime-type)
  ((major-type :initform nil :initarg :major-type
               :reader mime-type-major-type)))


(defclass minor-mime-type (mime-type)
  ((minor-type :initform nil :initarg :minor-type
               :reader mime-type-minor-type)))

(defclass mime:*/* (major-mime-type minor-mime-type)
  ())

(def-mime-type ("APPLICATION" "*"))
(def-mime-type ("APPLICATION" "JSON"))
(def-mime-type (:application :octet-stream))
(def-mime-type ("APPLICATION" "XML"))
(def-mime-type ("IMAGE" "*"))
(def-mime-type ("IMAGE" "SVG"))
(def-mime-type ("IMAGE" "SVG+XML") (mime::image/svg))
(def-mime-type ("TEXT" "*") ()
  ((charset
    :initarg :charset :initform :iso-8859-1
    :reader mime-type-charset
    :type keyword
    :documentation "See http://www.iana.org/assignments/character-sets")))
(def-mime-type ("TEXT" "XHTML"))
(def-mime-type ("APPLICATION" "XHTML+XML"))
(def-mime-type ("TEXT" "HTML"))
(def-mime-type ("TEXT" "XML"))
(def-mime-type ("TEXT" "PLAIN"))

(defmethod mime-type-charset ((type mime:*/*))
  nil)


(defgeneric mime-type (designator &rest args)
  (:documentation
   "coerce a designator to a mime type. fail if non is defined.")

  (:method ((mime-type mime-type) &rest args)
    (if args
      (apply #'make-instance (type-of mime-type) args)
      mime-type))

  (:method ((designator cons) &key &allow-other-keys)
    "Given a cons, the first two elements must be the type and the remainder the initargs."
    (destructuring-bind (major minor . args) designator
      (declare (dynamic-extent args))
      (apply #'mime-type (intern-mime-type-key (format nil "~a/~a" major minor)
                                       :if-does-not-exist :error)
             args)))

  (:method ((designator string) &rest args)
    "Given a string, coerce it to the class designator and continue."
    (declare (dynamic-extent args))
    (apply #'mime-type (intern-mime-type-key designator :if-does-not-exist :error)
           args))

  (:method ((designator symbol) &rest args)
    "Given a type designator, w/ args make a new one, w/o args return the singleton.
 Test validity by checking for a binding and constraining its type."
    (declare (dynamic-extent args))
    (let ((type (and (boundp designator) (symbol-value designator))))
      (assert (typep type 'mime-type) ()
              "Invalid mime type designator: ~s." designator)
      (if args
        (apply #'make-instance designator args)
        type))))


(defun list-mime-types ()
  (let ((types ()))
    (with-package-iterator  (next :mime :external)
      (loop (multiple-value-bind (next-p sym) (next)
              (unless next-p (return))
              (when (find-class sym nil)
                (pushnew sym types))))
    types)))
;;; (list-mime-types)


(defun clear-mime-types ()
  (dolist (type (list-mime-types))
    (setf (find-class type nil) nil)
    (unintern type :mime)))


;;;
;;; simple cloning

(unless (fboundp 'de.setf.utility::clone-instance)
  (eval-when (:compile-toplevel :load-toplevel :execute)
    (export '(de.setf.utility::clone-instance de.setf.utility::initialize-clone)
            :de.setf.utility))
  (defmethod de.setf.utility::initialize-clone ((new mime-type) (old mime-type) &rest args)
    (apply #'shared-initialize new t
           args))
  (defmethod de.setf.utility::initialize-clone ((new mime:text/*) (old mime:text/*) &rest args
                               &key (charset (slot-value old 'charset)))
    (apply #'call-next-method new old
           :charset charset
           args))
  (defmethod de.setf.utility::clone-instance ((instance mime-type) &rest args)
    (apply #'de.setf.utility::initialize-clone (allocate-instance (class-of instance)) instance
           args)))

(defmethod content-encoding ((mime-type mime:text/*) &rest args)
  (declare (dynamic-extent args) (ignore args))
  (content-encoding (mime-type-charset mime-type)))


:EOF