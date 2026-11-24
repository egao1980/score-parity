;;;; SC5 soft-loading the format backends (given).
;;;;
;;;; score-parity hard-depends on score-protocol only; a format backend is used
;;;; when it is installed. +BACKENDS+ names each by a keyword, with its ASDF
;;;; system and package:
;;;;   :MUSICXML  score-backend-musicxml: READ-MUSICXML, WRITE-MUSICXML,
;;;;              READ-MXL, WRITE-MXL (and the reader's :SPLIT-VOICES :AUTO)
;;;;   :MIDI      score-backend-midi: EXPORT-MIDI, IMPORT-MIDI
;;;;
;;;; (BACKEND-AVAILABLE-P backend) is T when the backend's package exists, or
;;;; when ASDF finds its system and LOAD-SYSTEM loads it; NIL when ASDF doesn't
;;;; find the system. An error while loading is not caught: an installed backend
;;;; that doesn't load is broken, not absent.
;;;; (BACKEND-FUNCTION backend name) is the function named NAME, a string such as
;;;; "READ-MUSICXML", in the backend's package. It signals BACKEND-MISSING when
;;;; the backend isn't available, and when the package has no fbound external
;;;; symbol of that name.
;;;; (CALL-BACKEND backend name &rest arguments) applies that function.
;;;; A BACKEND that isn't a key of +BACKENDS+ is a TYPE-ERROR.

(in-package #:score-parity)

(defparameter +backends+
  '((:musicxml :system "score-backend-musicxml" :package "SCORE-BACKEND-MUSICXML")
    (:midi :system "score-backend-midi" :package "SCORE-BACKEND-MIDI"))
  "(backend :system name :package name) per format backend. Data.")

(defun %backend-entry (backend)
  (check-type backend (member :musicxml :midi))
  (cdr (assoc backend +backends+)))

(defun backend-available-p (backend)
  "T when BACKEND is loaded or ASDF can find and load it (file header)."
  (let ((entry (%backend-entry backend)))
    (cond ((find-package (getf entry :package)) t)
          ((asdf:find-system (getf entry :system) nil)
           (asdf:load-system (getf entry :system))
           (and (find-package (getf entry :package)) t))
          (t nil))))

(defun backend-function (backend name)
  "The function NAME of BACKEND's package, or BACKEND-MISSING (file header)."
  (check-type name string)
  (let ((entry (%backend-entry backend)))
    (unless (backend-available-p backend)
      (error 'backend-missing :backend backend
                              :message (format nil "ASDF finds no system ~S" (getf entry :system))))
    (multiple-value-bind (symbol status) (find-symbol name (getf entry :package))
      (unless (and (eq status :external) (fboundp symbol))
        (error 'backend-missing :backend backend
                                :message (format nil "~A has no function ~A" (getf entry :package) name)))
      (symbol-function symbol))))

(defun call-backend (backend name &rest arguments)
  (apply (backend-function backend name) arguments))
