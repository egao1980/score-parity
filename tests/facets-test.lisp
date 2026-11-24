;;;; SC5 the facet rules (src/facets.lisp) on small scores read from MusicXML
;;;; snippets.

(in-package #:score-parity/tests)

(defun score-a (&key (e "E4") (hal :begin))
  "Two voices on one staff, divisions 2, 4/4. Voice 1: C4 (two verses, verse 2
first in the file), D4 tied across the barline and on through a grace note,
E (\"Hal\"). Voice 2: a whole rest, then a chord C4 G3 (written high note
first) and a rest."
  (read-snippet (list (cat (note "C4" 4 :lyrics '((2 "two" :single) (1 "one" :single)))
                           (note "D4" 4 :tie :start)
                           (backup 8)
                           (note :rest 8 :voice 2))
                      (cat (note "D4" 2 :tie :both)
                           (note "F4" 0 :grace t)
                           (note "D4" 2 :tie :stop)
                           (note e 4 :lyrics (list (list 1 "Hal" hal)))
                           (backup 8)
                           (note "C4" 4 :voice 2)
                           (note "G3" 4 :voice 2 :chord t)
                           (note :rest 4 :voice 2)))
                :divisions 2))

(defun score-b ()
  "A pickup score in 3/4: part 1 sounds, part 2 only rests; two chord symbols in
bar 1."
  (read-snippet (list (note "G4" 1)
                      (cat (harmony "C" "major") (note "E4" 1) (harmony "G" "dominant") (note "D4" 2))
                      (note "C4" 2))
                :time '(3 4) :pickup t
                :extra-parts (list (list (note :rest 1) (note :rest 3 :measure-rest t) (note :rest 2)))))

(defun score-c ()
  "A one-bar lead sheet."
  (read-snippet (list (cat (harmony "F" "major") (note "F4" 4)))))

(deftest voice-lines-merge-ties-and-skip-grace-notes
  (testing "a tie chain is one row, across the barline and past a grace note"
    (ok (equal '(((0 1/2 60 "C4") (1/2 3/2 62 "D4") (3/2 2 64 "E4"))
                 ((1 3/2 55 "G3") (1 3/2 60 "C4")))
               (voice-lines (score-a)))))
  (testing "chord notes are rows of their own, sorted by key; rests sound nothing"
    (ok (equal '((1 3/2 55 "G3") (1 3/2 60 "C4")) (second (voice-lines (score-a))))))
  (testing "pitches are spelled as music-theory prints them"
    (ok (equal "Fb4" (fourth (third (first (voice-lines (score-a :e "Fb4")))))))))

(deftest voice-lines-onsets-and-silent-voices
  (testing "onsets are absolute, from the start of the pickup; a voice of rests has no line"
    (ok (equal '(((0 1/4 67 "G4") (1/4 1/2 64 "E4") (1/2 1 62 "D4") (1 3/2 60 "C4")))
               (voice-lines (score-b)))))
  (ok (equal '(1/4 3/4 1/2) (bar-lengths (score-b))) "the pickup and the bar that completes it")
  (ok (equal '(1 1) (bar-lengths (score-a)))))

(deftest lyric-lines-follow-voice-lines
  (ok (equal '(((0 1 "one" :single) (0 2 "two" :single) (3/2 1 "Hal" :begin)) ())
             (lyric-lines (score-a)))
      "sorted by onset, then verse; one list per voice line, () without lyrics")
  (ok (equal '(()) (lyric-lines (score-b))) "the silent part has no line, so no list"))

(deftest chord-symbol-rows-are-absolute-and-printed
  (ok (equal '((1/4 "C") (1/2 "G7")) (chord-symbol-rows (score-b))))
  (ok (equal '() (chord-symbol-rows (score-a))))
  (ok (equal '((0 "F")) (chord-symbol-rows (score-c)))))

(deftest score-features-by-rule
  (ok (equal '(:lyrics :verses :ties :grace-notes :shared-staff) (score-features (score-a))))
  (ok (equal '(:chord-symbols :pickup :parts) (score-features (score-b))))
  (ok (equal '(:chord-symbols :lead-sheet) (score-features (score-c)))))

(deftest content-facets-by-rule
  (let ((a (score-a)))
    (ok (equal '(((0 1/2 60) (1/2 3/2 62) (3/2 2 64)) ((1 3/2 55) (1 3/2 60))) (content-facet a :notes)))
    (ok (equal '(((0 1/2 "C4") (1/2 3/2 "D4") (3/2 2 "E4")) ((1 3/2 "G3") (1 3/2 "C4")))
               (content-facet a :spelled)))
    (ok (equal (lyric-lines a) (content-facet a :lyrics)))
    (ok (equal '(((0 "one" nil) (3/2 "Hal" t)) ()) (content-facet a :verse-1))
        "verse 1 only; a :BEGIN syllable carries a hyphen")
    (ok (equal '() (content-facet a :chord-symbols)))
    (ok (equal '(1 1) (content-facet a :bars)))
    (ok (equal '(:notes :spelled :lyrics :verse-1 :chord-symbols :bars) +content-facets+))
    (ok (signals (content-facet a :pitches) 'type-error))))

(deftest content-differences-by-facet
  (let ((a (score-a)))
    (ok (null (content-differences a (score-a))) "equal content, different objects")
    (let ((d (content-differences a (score-a :e "F4"))))
      (ok (equal '(:notes :spelled) (mapcar #'first d)) "another pitch: what sounds and how it is spelled")
      (ok (equal (list :notes (content-facet a :notes) (content-facet (score-a :e "F4") :notes)) (first d))))
    (ok (equal '(:spelled) (mapcar #'first (content-differences a (score-a :e "Fb4"))))
        "an enharmonic spelling sounds the same")
    (ok (equal '(:lyrics :verse-1) (mapcar #'first (content-differences a (score-a :hal :single))))
        "a lost hyphen shows in verse 1 too")
    (ok (null (content-differences a (score-a :hal :middle) :facets '(:verse-1)))
        ":MIDDLE and :BEGIN both carry a hyphen")
    (ok (null (content-differences a (score-a :e "F4") :facets '(:lyrics :bars))) "only the facets asked for")
    (ok (equal '(:bars :notes) (mapcar #'first (content-differences a (score-b) :facets '(:bars :notes))))
        "in the order asked for")))
