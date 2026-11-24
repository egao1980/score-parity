;;;; SC5 the corpus (src/corpus.lisp, given) and the facts of every piece, which
;;;; the facet rules (src/facets.lisp) must reproduce from the score
;;;; READ-MUSICXML reads.

(in-package #:score-parity/tests)

;;; The corpus itself (given code and data) ---------------------------------------------

(deftest corpus-size-and-facts
  (let ((pieces (corpus-pieces)))
    (ok (<= 20 (length pieces) 40) (format nil "~D pieces" (length pieces)))
    (ok (equal pieces (sort (copy-list pieces) #'string<)) "sorted")
    (ok (equal pieces (mapcar #'car (corpus-facts))) "one facts entry per file, in order")
    (ok (signals (piece-facts "no-such-piece") 'unknown-piece))
    (ok (equal (merge-pathnames "amazing-grace.mxl" (corpus-root)) (corpus-path "amazing-grace" "mxl")))))

(deftest corpus-provenance
  (let ((text (uiop:read-file-string (merge-pathnames "PROVENANCE.md" (corpus-root)) :external-format :utf-8)))
    (dolist (piece (corpus-pieces))
      (ok (search (format nil "`~A.musicxml`" piece) text) (format nil "~A.musicxml has its provenance" piece)))
    (dolist (piece (archive-pieces))
      (ok (search (format nil "`~A.mxl`" piece) text) (format nil "~A.mxl has its provenance" piece)))
    (ok (search "MIT" text))
    (ok (probe-file (merge-pathnames "generate-corpus.py" (corpus-root))) "the generator is committed")))

(deftest corpus-text-is-latin-1
  ;; MIDI text events are Latin-1 (midi-protocol): every title and syllable fits.
  (dolist (piece (corpus-pieces))
    (let ((texts (cons (piece-fact piece :title)
                       (loop for line in (piece-fact piece :lyrics)
                             append (mapcar #'third line)))))
      (ok (every (lambda (text) (every (lambda (c) (< (char-code c) 256)) text)) texts)
          (format nil "~A: Latin-1 text" piece)))))

(deftest corpus-feature-coverage
  (flet ((count-of (feature)
           (count-if (lambda (piece) (member feature (piece-features piece))) (corpus-pieces))))
    (dolist (feature +features+)
      (ok (plusp (count-of feature)) (format nil "~(~S~) in some piece" feature)))
    ;; The brief's list: hymnal voices, verses, chord symbols, pickups, repeats
    ;; and endings, D.C. / D.S., ties, tuplets, lead sheets.
    (dolist (feature '(:verses :chord-symbols :lead-sheet :pickup :repeats :endings :jumps :ties
                       :tuplets :shared-staff))
      (ok (<= 2 (count-of feature)) (format nil "~(~S~) in two pieces or more" feature)))
    (ok (every (lambda (piece) (subsetp (piece-features piece) +features+)) (corpus-pieces)))))

(deftest corpus-hymns
  (let ((hymns (hymn-pieces)))
    (ok (<= 6 (length hymns)) (format nil "~D hymns" (length hymns)))
    (ok (every (lambda (h) (= 4 (length (piece-fact h :split-lines)))) hymns) "four voice lines each")
    (ok (<= 4 (count-if (lambda (h) (not (equal (piece-fact h :lines) (piece-fact h :split-lines)))) hymns))
        "four or more in hymnal layout: two voices per staff as shared stems")
    (ok (<= 2 (length (archive-pieces))) "compressed archives")))

(deftest backends-are-soft
  (ok (backend-available-p :musicxml))
  (ok (backend-available-p :midi))
  (ok (functionp (backend-function :musicxml "READ-MUSICXML")))
  (ok (signals (backend-function :musicxml "NO-SUCH-FUNCTION") 'backend-missing))
  (ok (signals (backend-available-p :lilypond) 'type-error))
  (let ((+backends+ '((:musicxml :system "score-backend-musicxml" :package "SCORE-BACKEND-MUSICXML")
                      (:midi :system "no-such-system-sc5" :package "NO-SUCH-PACKAGE-SC5"))))
    (ok (not (backend-available-p :midi)) "a system ASDF can't find is absent")
    (ok (signals (call-backend :midi "IMPORT-MIDI" #()) 'backend-missing))))

;;; The facts, from the score as read ----------------------------------------------------

(deftest-parametrize facts-voice-lines
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  (ok (equal (piece-fact piece :lines) (voice-lines (piece-score piece)))))

(deftest-parametrize facts-lyric-lines
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  (ok (equal (piece-fact piece :lyrics) (lyric-lines (piece-score piece)))))

(deftest-parametrize facts-chord-symbols-and-bars
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  (let ((score (piece-score piece)))
    (ok (equal (piece-fact piece :chord-onsets) (mapcar #'first (chord-symbol-rows score))))
    (ok (every (lambda (row) (stringp (second row))) (chord-symbol-rows score)))
    (ok (equal (piece-fact piece :bars) (bar-lengths score)))))

(deftest-parametrize facts-features
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  (let ((score (piece-score piece)))
    (ok (equal (piece-fact piece :features) (score-features score)))
    (ok (equal (piece-fact piece :title) (getf (sp:score-metadata score) :title)))))
