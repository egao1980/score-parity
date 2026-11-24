;;;; score-parity: a public-domain corpus and the checks every score-protocol
;;;; format backend must pass on it. Brief: cl-stack/docs/capabilities/score.md,
;;;; slice SC5.
;;;;
;;;; Files:
;;;;   conditions.lisp  PARITY-ERROR and its subtypes (given)
;;;;   corpus.lisp      the corpus under corpus/ and its facts (given)
;;;;   backends.lisp    soft-loading the format backends (given)
;;;;   facets.lisp      what a score holds, as plain data, and how two differ
;;;;   oracles.lisp     MuseScore and xmllint, run out of process
;;;;   checks.lisp      one check per backend path, on one piece
;;;;   matrix.lisp      every check over the corpus, per feature; PRINT-MATRIX
;;;;
;;;; Dependencies. score-protocol, with the music-theory and FSet values its
;;;; scores are made of; process-protocol through process-backend-uiop for the
;;;; oracles; cl-stack-pathlib for their temporary files. The format backends
;;;; (score-backend-musicxml, score-backend-midi) are soft: BACKEND-AVAILABLE-P
;;;; loads one when ASDF finds it, and a check whose backend is missing is
;;;; skipped, as doc-extract-parity does with its extractors. The test system
;;;; depends on both backends, so CI installs and checks them.

(defpackage #:score-parity
  (:use #:cl)
  (:documentation "A public-domain corpus of scores in MusicXML (slice SC5) and the parity
checks of the score-protocol format backends: MusicXML and .mxl round trips,
the hymnal voice split, score -> MIDI -> score with and without unfolding, and
two external oracles (MuseScore re-export, the MusicXML 4.0 XSD through
xmllint). PARITY-MATRIX runs every check over the corpus; PRINT-MATRIX shows
the result per notation feature.")
  (:export
   ;; Conditions (conditions.lisp)
   #:parity-error #:parity-error-message
   #:unknown-piece #:unknown-piece-piece
   #:backend-missing #:backend-missing-backend
   #:oracle-failed #:oracle-failed-tool #:oracle-failed-exit-code #:oracle-failed-output
   ;; The corpus (corpus.lisp)
   #:+features+
   #:corpus-root #:corpus-path #:corpus-pieces #:corpus-facts
   #:piece-facts #:piece-fact #:piece-features #:hymn-pieces #:archive-pieces
   ;; Backends (backends.lisp)
   #:+backends+ #:backend-available-p #:backend-function #:call-backend
   ;; Facets (facets.lisp)
   #:+content-facets+
   #:voice-lines #:lyric-lines #:chord-symbol-rows #:bar-lengths #:score-features
   #:content-facet #:content-differences
   ;; Oracles (oracles.lisp)
   #:+musescore-names+
   #:find-musescore #:musescore-convert #:musicxml-schema #:xmllint-validate
   ;; Checks (checks.lisp)
   #:parity-result #:make-parity-result #:parity-result-p
   #:parity-result-check #:parity-result-piece #:parity-result-status
   #:parity-result-reason #:parity-result-differences
   #:+checks+ #:+midi-facets+ #:+musescore-facets+
   #:read-piece #:check-applies-p #:run-check
   #:check-musicxml #:check-mxl #:check-hymnal-split #:check-midi #:check-midi-unfold
   #:check-musescore #:check-xsd
   ;; The matrix (matrix.lisp)
   #:parity-matrix #:matrix-cells #:print-matrix))

(in-package #:score-parity)

(defun %sc5-pending (name)
  "Contract stub for slice SC5. Every call is replaced by the implementation,
then this function is deleted."
  (error "score-parity SC5 pending: ~A" name))
