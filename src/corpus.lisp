;;;; SC5 the corpus (given).
;;;;
;;;; corpus/ holds public-domain pieces re-encoded by us (MIT; corpus/
;;;; PROVENANCE.md), each as <piece>.musicxml, written the way a notation
;;;; program writes MusicXML: no ids, layout and playback elements a reader
;;;; ignores, voices 1, 2, 5, 6. Some pieces also come as <piece>.mxl, a
;;;; compressed archive as other programs write one (deflated entries, a PDF
;;;; rendition listed first, the score under music/). corpus/generate-corpus.py
;;;; writes all of them and corpus/facts.sexp; never hand-edit either.
;;;;
;;;; A PIECE is the name of a corpus file without its type ("amazing-grace").
;;;; (CORPUS-PIECES) lists every corpus/*.musicxml, sorted with STRING<.
;;;; (CORPUS-PATH piece &optional (type "musicxml")) is corpus/<piece>.<type>,
;;;; whether or not that file exists.
;;;;
;;;; Facts. corpus/facts.sexp is one list of entries (PIECE . PLIST), one per
;;;; corpus file, sorted by name: what the facet rules (facets.lisp) give for
;;;; the file as READ-MUSICXML reads it. generate-corpus.py computes them from
;;;; its own model of each file, a second implementation of those rules, and
;;;; checks that music21 reads the same notes, lyrics, measures and chord
;;;; onsets. Keys:
;;;;   :TITLE         the metadata :TITLE
;;;;   :FEATURES      (SCORE-FEATURES score): keywords of +FEATURES+, in order
;;;;   :BARS          (BAR-LENGTHS score)
;;;;   :LINES         (VOICE-LINES score): rows (onset end key pitch)
;;;;   :LYRICS        (LYRIC-LINES score): rows (onset verse text syllabic)
;;;;   :CHORD-ONSETS  the onsets of (CHORD-SYMBOL-ROWS score), in order
;;;;   :SPLIT-LINES   hymns only: the four lines, rows (onset end key pitch),
;;;;                  soprano, alto, tenor, bass, that (VOICE-LINES h) must give
;;;;                  for h the piece read with :SPLIT-VOICES :AUTO. They are the
;;;;                  lines of the hand-split tune, whichever layout the file has.
;;;; Onsets, ends and lengths are rationals in whole notes.
;;;;
;;;; (PIECE-FACTS piece) is that plist; a piece with no entry signals
;;;; UNKNOWN-PIECE. (PIECE-FACT piece key) is one value, (PIECE-FEATURES piece)
;;;; its :FEATURES. (HYMN-PIECES) lists the pieces with :SPLIT-LINES and
;;;; (ARCHIVE-PIECES) those with a corpus/<piece>.mxl, both sorted.
;;;;
;;;; +FEATURES+ are the notation features a piece can carry; SCORE-FEATURES
;;;; (facets.lisp) says when a score has each, and the matrix (matrix.lisp)
;;;; reports every check per feature.

(in-package #:score-parity)

(defparameter +features+
  '(:lyrics :verses :chord-symbols :lead-sheet :pickup :repeats :endings :jumps
    :ties :tuplets :grace-notes :key-change :meter-change :shared-staff :parts)
  "The notation features of SCORE-FEATURES, in matrix order (facets.lisp). Data.")

(defun corpus-root ()
  "The corpus directory, corpus/ of the score-parity system."
  (asdf:system-relative-pathname "score-parity" "corpus/"))

(defun corpus-path (piece &optional (type "musicxml"))
  "corpus/PIECE.TYPE."
  (check-type piece string)
  (check-type type string)
  (merge-pathnames (make-pathname :name piece :type type) (corpus-root)))

(defun corpus-pieces ()
  "The name of every corpus/*.musicxml, sorted."
  (sort (mapcar #'pathname-name
                (directory (merge-pathnames (make-pathname :name :wild :type "musicxml")
                                            (corpus-root))))
        #'string<))

(defvar *facts* nil
  "corpus/facts.sexp, once read.")

(defun corpus-facts ()
  "The entries (PIECE . PLIST) of corpus/facts.sexp."
  (or *facts*
      (setf *facts*
            (with-open-file (in (merge-pathnames "facts.sexp" (corpus-root)) :external-format :utf-8)
              (with-standard-io-syntax
                (let ((*read-eval* nil)
                      (*package* (find-package '#:score-parity)))
                  (read in)))))))

(defun piece-facts (piece)
  "The facts plist of PIECE; UNKNOWN-PIECE when it has none."
  (let ((entry (assoc piece (corpus-facts) :test #'equal)))
    (unless entry
      (error 'unknown-piece :piece piece))
    (cdr entry)))

(defun piece-fact (piece key)
  (getf (piece-facts piece) key))

(defun piece-features (piece)
  (piece-fact piece :features))

(defun hymn-pieces ()
  "The pieces whose facts have :SPLIT-LINES, sorted."
  (sort (loop for (piece . plist) in (corpus-facts)
              when (getf plist :split-lines) collect piece)
        #'string<))

(defun archive-pieces ()
  "The pieces that also come as corpus/<piece>.mxl, sorted."
  (sort (mapcar #'pathname-name
                (directory (merge-pathnames (make-pathname :name :wild :type "mxl") (corpus-root))))
        #'string<))
