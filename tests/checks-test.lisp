;;;; SC5 the checks (src/checks.lisp) on every corpus piece they apply to, with
;;;; the published backends: each must pass. The oracles are in oracles-test.

(in-package #:score-parity/tests)

(defun passes (check piece)
  (let ((result (run-check check piece)))
    (ok (and (parity-result-p result)
             (eq check (parity-result-check result))
             (equal piece (parity-result-piece result))
             (eq :pass (parity-result-status result))
             (null (parity-result-reason result)))
        (result-message result))))

(deftest-parametrize musicxml-round-trip
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  ;; read -> write -> read is SCORE-EQUAL, and the second write is byte-stable
  (passes :musicxml piece))

(deftest-parametrize mxl-round-trip
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  ;; write-mxl -> read-mxl is SCORE-EQUAL and byte-stable; corpus archives read
  ;; as their MusicXML
  (passes :mxl piece))

(deftest-parametrize hymnal-split
    ((piece) :ids (hymn-pieces) :rows (hymn-rows))
  ;; :split-voices :auto gives soprano, alto, tenor and bass with the pitches,
  ;; onsets and tied ends of the hand-split tune
  (passes :hymnal-split piece))

(deftest-parametrize midi-round-trip
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  ;; score -> MIDI -> score keeps pitches, onsets, ends, verse 1, chord symbols
  ;; and bar lengths, played as written
  (passes :midi piece))

(deftest-parametrize midi-round-trip-unfolded
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  ;; the same against score-protocol's UNFOLD of the piece
  (passes :midi-unfold piece))

(deftest check-results-carry-their-reasons
  (testing "a check on a piece it doesn't apply to"
    (ok (not (check-applies-p :hymnal-split "jingle-bells")))
    (ok (check-applies-p :hymnal-split "hymn-shared"))
    (ok (every (lambda (check)
                 (every (lambda (piece) (check-applies-p check piece)) (corpus-pieces)))
               '(:musicxml :mxl :midi :midi-unfold :musescore :xsd)))
    (let ((result (run-check :hymnal-split "jingle-bells")))
      (ok (eq :skip (parity-result-status result)))
      (ok (equal "not a hymn" (parity-result-reason result)))))
  (testing "an error in a check is a result, not a crash"
    (let ((result (run-check :musicxml "no-such-piece")))
      (ok (eq :error (parity-result-status result)))
      (ok (and (stringp (parity-result-reason result)) (plusp (length (parity-result-reason result)))))
      (ok (null (parity-result-differences result))))
    (let ((result (run-check :hymnal-split "no-such-piece")))
      (ok (eq :error (parity-result-status result)))
      (ok (search "no-such-piece" (parity-result-reason result)) "UNKNOWN-PIECE's report")))
  (testing "a missing backend is a skip"
    (let* ((+backends+ '((:musicxml :system "score-backend-musicxml" :package "SCORE-BACKEND-MUSICXML")
                         (:midi :system "no-such-system-sc5" :package "NO-SUCH-PACKAGE-SC5")))
           (result (run-check :midi "jingle-bells")))
      (ok (eq :skip (parity-result-status result)))
      (ok (search "midi" (parity-result-reason result)) "BACKEND-MISSING's report")))
  (testing "unknown checks"
    (ok (signals (run-check :lilypond "jingle-bells") 'type-error))
    (ok (signals (check-applies-p :lilypond "jingle-bells") 'type-error))))

(deftest direct-check-calls
  (testing "the check functions return results themselves"
    (let ((result (check-musicxml "amazing-grace")))
      (ok (eq :musicxml (parity-result-check result)))
      (ok (eq :pass (parity-result-status result))))
    (let ((result (check-hymnal-split "amazing-grace")))
      (ok (eq :hymnal-split (parity-result-check result)))
      (ok (eq :skip (parity-result-status result)))))
  (testing "the facet lists"
    (ok (equal '(:notes :verse-1 :chord-symbols :bars) +midi-facets+))
    (ok (equal '(:spelled :lyrics :bars) +musescore-facets+))
    (ok (equal '(:musicxml :mxl :hymnal-split :midi :midi-unfold :musescore :xsd) (mapcar #'first +checks+)))))
