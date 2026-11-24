;;;; SC5 conditions (given). score-protocol owns the score conditions; these are
;;;; the harness's own: a piece that isn't in the corpus, a backend that isn't
;;;; installed, an external tool that failed.
;;;;
;;;; parity-error (error)              MESSAGE, a string or NIL
;;;; ├── unknown-piece                 PIECE: a name with no facts (corpus.lisp)
;;;; ├── backend-missing               BACKEND: a keyword of +BACKENDS+ whose system
;;;; │                                 ASDF can't find, or whose package lacks the
;;;; │                                 function asked for (backends.lisp). RUN-CHECK
;;;; │                                 turns it into a :SKIP.
;;;; └── oracle-failed                 TOOL ("MuseScore", "xmllint"), EXIT-CODE,
;;;;                                   OUTPUT (what the tool wrote on stderr):
;;;;                                   an external tool exited with an error or
;;;;                                   wrote nothing (oracles.lisp). RUN-CHECK turns
;;;;                                   it into an :ERROR.
;;;; No restarts: nothing below a check can recover, and a check is the unit
;;;; RUN-CHECK reports on.

(in-package #:score-parity)

(define-condition parity-error (error)
  ((message :initarg :message :initform nil :reader parity-error-message))
  (:report (lambda (c s)
             (format s "score-parity: ~A" (or (parity-error-message c) "error")))))

(define-condition unknown-piece (parity-error)
  ((piece :initarg :piece :reader unknown-piece-piece))
  (:report (lambda (c s)
             (format s "score-parity: ~S is not a corpus piece" (unknown-piece-piece c)))))

(define-condition backend-missing (parity-error)
  ((backend :initarg :backend :reader backend-missing-backend))
  (:report (lambda (c s)
             (format s "score-parity: backend ~(~S~) is not available~@[: ~A~]"
                     (backend-missing-backend c) (parity-error-message c)))))

(define-condition oracle-failed (parity-error)
  ((tool :initarg :tool :reader oracle-failed-tool)
   (exit-code :initarg :exit-code :initform nil :reader oracle-failed-exit-code)
   (output :initarg :output :initform nil :reader oracle-failed-output))
  (:report (lambda (c s)
             (format s "score-parity: ~A failed~@[ (exit code ~D)~]~@[: ~A~]"
                     (oracle-failed-tool c) (oracle-failed-exit-code c)
                     (let ((out (oracle-failed-output c)))
                       (and out (plusp (length out))
                            (string-trim '(#\Space #\Tab #\Newline #\Return) out)))))))
