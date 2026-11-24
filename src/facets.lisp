;;;; SC5 facets: what a score holds, as plain lists, so that two scores from
;;;; different formats can be compared on what both formats carry.
;;;;
;;;; Every function here is pure and reads score-protocol values only (pitches,
;;;; chord symbols and lengths are music-theory's). Positions are rationals in
;;;; whole notes from the start of the first bar (score-protocol's
;;;; ABSOLUTE-OFFSET and BAR-START); FSet seqs are read as lists.
;;;;
;;;; Voices. The voices of a score in document order: its parts in order, each
;;;; part's PART-VOICES in order. Voice measure k (from 0) of a voice is bar
;;;; b = (score-first-bar score) + k, which starts at (bar-start score b).
;;;;
;;;; Timed events. A voice's timed events are its events, voice measure by voice
;;;; measure and in order, leaving out grace events (a SOUNDING-EVENT whose
;;;; EVENT-GRACE is true), each with its ONSET: its bar's start plus the
;;;; EVENT-DURATIONs of the events before it in its voice measure (grace events
;;;; left out). The notes of an event: a NOTE-EVENT is its own one note, a
;;;; CHORD-EVENT has its CHORD-EVENT-NOTES in order, a REST-EVENT has none.
;;;;
;;;; Sounding notes. Walk a voice's timed events in order. Every note that no
;;;; chain has taken yet starts a chain at its event's onset, ending at that
;;;; onset plus its event's duration. While the chain's last note c has a
;;;; NOTE-TIE, the timed event right after the one holding c is looked at: when
;;;; it starts at the chain's end and holds a note whose ELEMENT-ID is EQUAL to
;;;; (tie-end (note-tie c)) and whose PITCH-MIDI is that of the chain's first
;;;; note, that note joins the chain (it starts no chain of its own) and the end
;;;; moves on by its event's duration; otherwise the chain stops there, and
;;;; the tie is ignored. Each chain is one row (ONSET END KEY PITCH): ONSET and
;;;; END as above, KEY the first note's (pitch-midi (note-pitch n)) and PITCH
;;;; its (pitch-name (note-pitch n)), so "F#4" or "Bb3". This is how
;;;; score-backend-midi's export sounds a tie chain: once.
;;;; A voice's line is its rows sorted by ONSET, then KEY, stably.
;;;;
;;;; (VOICE-LINES score) → the lines of the voices that have at least one row,
;;;; in document order. A voice with nothing to sound (empty, rests only,
;;;; grace notes only) has no line: formats that drop such voices compare equal.
;;;;
;;;; (LYRIC-LINES score) → one list per line of VOICE-LINES, for the same voices
;;;; in the same order: for every timed NOTE-EVENT or CHORD-EVENT of the voice
;;;; and every lyric of its EVENT-LYRICS, the row (ONSET VERSE TEXT SYLLABIC):
;;;; the event's onset and the lyric's LYRIC-VERSE, LYRIC-TEXT and
;;;; LYRIC-SYLLABIC. Sorted by ONSET, then VERSE, stably; () for a voice without
;;;; lyrics. Extenders are not part of a row.
;;;;
;;;; (CHORD-SYMBOL-ROWS score) → for every anchor of SCORE-CHORD-SYMBOLS, the row
;;;; (ONSET TEXT): ONSET (absolute-offset score (anchor-position a)) and TEXT
;;;; (print-chord-symbol (anchor-symbol a) :dialect :pop), "G7" or "N.C.".
;;;; Sorted by ONSET, stably.
;;;;
;;;; (BAR-LENGTHS score) → (bar-length score b) for every bar b from
;;;; SCORE-FIRST-BAR to SCORE-LAST-BAR; () for a score without measures.
;;;;
;;;; (SCORE-FEATURES score) → the keywords of +FEATURES+ (corpus.lisp) that the
;;;; score has, in +FEATURES+ order. "An event" is any event of any voice, grace
;;;; events and rests included; "a note" a note event or a chord note.
;;;;   :LYRICS         an event has a lyric
;;;;   :VERSES         a lyric has a LYRIC-VERSE of 2 or more
;;;;   :CHORD-SYMBOLS  the score has a chord-symbol anchor
;;;;   :LEAD-SHEET     the score has one part, that part one voice, and the score
;;;;                   a chord-symbol anchor
;;;;   :PICKUP         the first measure's MEASURE-INFO-PICKUP-P
;;;;   :REPEATS        a measure has a MEASURE-INFO-REPEAT-END
;;;;   :ENDINGS        a measure has a MEASURE-INFO-ENDING
;;;;   :JUMPS          a measure has a MEASURE-INFO-JUMP mark
;;;;   :TIES           a note has a NOTE-TIE
;;;;   :TUPLETS        an event has an EVENT-TUPLET
;;;;   :GRACE-NOTES    a sounding event has EVENT-GRACE
;;;;   :KEY-CHANGE     a measure after the first has a MEASURE-INFO-KEY
;;;;   :METER-CHANGE   a measure after the first has a MEASURE-INFO-TIME
;;;;   :SHARED-STAFF   for some k, two voices of one part with the same
;;;;                   VOICE-STAFF both hold at least one event in voice measure k
;;;;   :PARTS          the score has two or more parts
;;;;
;;;; Facets. (CONTENT-FACET score facet) is one view of the content:
;;;;   :NOTES          each line of VOICE-LINES with its rows as (ONSET END KEY):
;;;;                   what sounds, whatever the spelling
;;;;   :SPELLED        each line with its rows as (ONSET END PITCH)
;;;;   :LYRICS         LYRIC-LINES
;;;;   :VERSE-1        each list of LYRIC-LINES reduced to its rows of verse 1, each
;;;;                   as (ONSET TEXT HYPHEN), HYPHEN T when SYLLABIC is :BEGIN or
;;;;                   :MIDDLE (the syllable goes on to the next one), else NIL.
;;;;                   That is all a MIDI lyric event holds: one verse, the text,
;;;;                   and a trailing hyphen; the syllabic type comes back as the
;;;;                   hyphens in playing order imply it.
;;;;   :CHORD-SYMBOLS  CHORD-SYMBOL-ROWS
;;;;   :BARS           BAR-LENGTHS
;;;; +CONTENT-FACETS+ lists them in this order. Another FACET is a TYPE-ERROR.
;;;; (CONTENT-DIFFERENCES a b &key (facets +content-facets+)) → for each facet
;;;; of FACETS, in that order, whose values for the scores A and B aren't EQUAL,
;;;; the list (FACET value-for-A value-for-B); () when every facet agrees.
;;;;
;;;; Never compared, on purpose: ids, provenance and confidence; rests (hidden
;;;; or not) and grace notes; voice names, stems and staves, part names and how
;;;; voices are grouped into parts; extenders; dynamics, articulations, slurs,
;;;; hairpins, fermatas; keys, meters and tempo marks (only bar lengths);
;;;; repeats, endings and jumps (a check compares against the written or the
;;;; unfolded score, whichever the format plays); metadata.

(in-package #:score-parity)

(defparameter +content-facets+ '(:notes :spelled :lyrics :verse-1 :chord-symbols :bars)
  "Every facet of CONTENT-FACET, in comparison order (file header). Data.")

;;; Walking voices (internal) -------------------------------------------------------

(defun %voices (score)
  "Every voice of SCORE in document order: the parts in order, each part's
PART-VOICES in order (file header, Voices)."
  (loop for part in (fset:convert 'list (score-protocol:score-parts score))
        append (score-protocol:part-voices part)))

(defun %voice-measures (voice)
  "VOICE's voice measures, as a fresh list of fresh lists of events."
  (mapcar (lambda (measure) (fset:convert 'list measure))
          (fset:convert 'list (score-protocol:voice-measures voice))))

(defun %grace-p (event)
  "True for a grace event. EVENT-GRACE is a SOUNDING-EVENT reader: a rest has none."
  (and (typep event 'score-protocol:sounding-event)
       (score-protocol:event-grace event)
       t))

(defun %event-notes (event)
  "The notes of EVENT: a NOTE-EVENT is its own one note, a CHORD-EVENT has its
CHORD-EVENT-NOTES in order, a rest has none (file header, Timed events)."
  (typecase event
    (score-protocol:note-event (list event))
    (score-protocol:chord-event (score-protocol:chord-event-notes event))
    (t '())))

(defun %key (note)
  (music-theory:pitch-midi (score-protocol:note-pitch note)))

(defun %by-onset-then (index)
  "A predicate ordering rows by their first element, then by element INDEX."
  (lambda (a b)
    (or (< (first a) (first b))
        (and (= (first a) (first b)) (< (nth index a) (nth index b))))))

(defun %timed-events (score voice)
  "VOICE's timed events, a simple-vector of (onset . event): grace events left
out, ONSET its bar's start plus the durations of the timed events before it in
its voice measure (file header, Timed events)."
  (let ((timed '()))
    (loop for events in (%voice-measures voice)
          for bar from (score-protocol:score-first-bar score)
          do (let ((onset nil))          ; BAR-START only for a measure with a timed event
               (dolist (event events)
                 (unless (%grace-p event)
                   (unless onset
                     (setf onset (score-protocol:bar-start score bar)))
                   (push (cons onset event) timed)
                   (incf onset (score-protocol:event-duration event))))))
    (coerce (nreverse timed) 'simple-vector)))

(defun %voice-rows (timed)
  "The (onset end key pitch) row of every tie chain of TIMED, a vector of
%TIMED-EVENTS, sorted by onset, then key, stably (file header, Sounding notes)."
  (let ((taken (make-array (length timed) :initial-element '())) ; per slot: notes joined to a chain
        (rows '()))
    (loop for i from 0
          for (onset . event) across timed
          do (dolist (head (%event-notes event))
               (unless (member head (svref taken i) :test #'eq)
                 (let ((key (%key head))
                       (end (+ onset (score-protocol:event-duration event)))
                       (tail head)
                       (j i))
                   (loop for tie = (score-protocol:note-tie tail)
                         while (and tie (< (1+ j) (length timed)))
                         do (destructuring-bind (next-onset . next) (svref timed (1+ j))
                              (let ((note (find (score-protocol:tie-end tie) (%event-notes next)
                                                :key #'score-protocol:element-id :test #'equal)))
                                (unless (and note (= next-onset end) (= key (%key note)))
                                  (loop-finish)) ; the chain stops; the tie is ignored
                                (incf j)
                                (push note (svref taken j))
                                (incf end (score-protocol:event-duration next))
                                (setf tail note))))
                   (push (list onset end key
                               (music-theory:pitch-name (score-protocol:note-pitch head)))
                         rows)))))
    (stable-sort (nreverse rows) (%by-onset-then 2))))

(defun %lyric-rows (timed)
  "The (onset verse text syllabic) rows of TIMED, sorted by onset, then verse,
stably (file header, LYRIC-LINES)."
  (stable-sort
   (loop for (onset . event) across timed
         when (typep event '(or score-protocol:note-event score-protocol:chord-event))
           append (mapcar (lambda (lyric)
                            (list onset
                                  (score-protocol:lyric-verse lyric)
                                  (score-protocol:lyric-text lyric)
                                  (score-protocol:lyric-syllabic lyric)))
                          (score-protocol:event-lyrics event)))
   (%by-onset-then 1)))

(defun %sounding-voices (score)
  "(timed . rows) for every voice of SCORE that has at least one row, in document
order: VOICE-LINES and LYRIC-LINES both read this list, so they line up."
  (loop for voice in (%voices score)
        for timed = (%timed-events score voice)
        for rows = (%voice-rows timed)
        when rows collect (cons timed rows)))

;;; The facets ----------------------------------------------------------------------

(defun voice-lines (score)
  "The sounding notes of every voice that sounds, as rows (onset end key pitch)
(file header)."
  (mapcar #'cdr (%sounding-voices score)))

(defun lyric-lines (score)
  "The lyrics of the voices of VOICE-LINES, as rows (onset verse text syllabic)
(file header)."
  (mapcar (lambda (voice) (%lyric-rows (car voice))) (%sounding-voices score)))

(defun chord-symbol-rows (score)
  "The chord-symbol anchors as rows (onset text) (file header)."
  (stable-sort
   (mapcar (lambda (anchor)
             (list (score-protocol:absolute-offset score (score-protocol:anchor-position anchor))
                   (music-theory:print-chord-symbol (score-protocol:anchor-symbol anchor)
                                                    :dialect :pop)))
           (fset:convert 'list (score-protocol:score-chord-symbols score)))
   #'< :key #'first))

(defun bar-lengths (score)
  "The length of every bar, in order (file header)."
  ;; No measures: first bar 1, last bar 0 (score-protocol measure-map.lisp), so ().
  (loop for bar from (score-protocol:score-first-bar score)
          to (score-protocol:score-last-bar score)
        collect (score-protocol:bar-length score bar)))

(defun %shared-staff-p (part)
  "True when two voices of PART on one VOICE-STAFF both hold an event in some
voice measure k (file header, :SHARED-STAFF)."
  (let ((held (make-hash-table :test 'equal))) ; (staff . k) -> T once a voice holds an event there
    (some (lambda (voice)
            (loop for events in (%voice-measures voice)
                  for k from 0
                  thereis (and events
                               (shiftf (gethash (cons (score-protocol:voice-staff voice) k) held)
                                       t))))
          (score-protocol:part-voices part))))

(defun score-features (score)
  "The keywords of +FEATURES+ that SCORE has (file header)."
  (let* ((parts (fset:convert 'list (score-protocol:score-parts score)))
         (measures (fset:convert 'list (score-protocol:score-measure-map score)))
         (anchors (fset:convert 'list (score-protocol:score-chord-symbols score)))
         (events (loop for voice in (%voices score) ; grace events and rests included
                       append (loop for events in (%voice-measures voice) append events)))
         (notes (loop for event in events append (%event-notes event)))
         (lyrics (loop for event in events append (score-protocol:event-lyrics event))))
    (flet ((has-p (feature)
             ;; One small predicate per line of the file header.
             (ecase feature
               (:lyrics lyrics)
               (:verses (some (lambda (lyric) (<= 2 (score-protocol:lyric-verse lyric))) lyrics))
               (:chord-symbols anchors)
               (:lead-sheet (and anchors
                                 (= 1 (length parts))
                                 (= 1 (length (score-protocol:part-voices (first parts))))))
               (:pickup (and measures (score-protocol:measure-info-pickup-p (first measures))))
               (:repeats (some #'score-protocol:measure-info-repeat-end measures))
               (:endings (some #'score-protocol:measure-info-ending measures))
               (:jumps (some #'score-protocol:measure-info-jump measures))
               (:ties (some #'score-protocol:note-tie notes))
               (:tuplets (some #'score-protocol:event-tuplet events))
               (:grace-notes (some #'%grace-p events))
               (:key-change (some #'score-protocol:measure-info-key (rest measures)))
               (:meter-change (some #'score-protocol:measure-info-time (rest measures)))
               (:shared-staff (some #'%shared-staff-p parts))
               (:parts (<= 2 (length parts))))))
      ;; A fresh list in +FEATURES+ order, never +FEATURES+ itself.
      (loop for feature in +features+
            when (has-p feature) collect feature))))

(defun %content-facet-p (object)
  (and (member object +content-facets+) t))

(defun %columns (lines &rest places)
  "Each row of each line of LINES reduced to its elements at PLACES."
  (mapcar (lambda (line)
            (mapcar (lambda (row) (mapcar (lambda (place) (nth place row)) places)) line))
          lines))

(defun content-facet (score facet)
  "The FACET view of SCORE's content (file header)."
  (check-type facet (satisfies %content-facet-p) "a facet of +CONTENT-FACETS+")
  (ecase facet
    (:notes (%columns (voice-lines score) 0 1 2))
    (:spelled (%columns (voice-lines score) 0 1 3))
    (:lyrics (lyric-lines score))
    (:verse-1 (mapcar (lambda (line)
                        (loop for (onset verse text syllabic) in line
                              when (eql verse 1)
                                collect (list onset text
                                              (and (member syllabic '(:begin :middle)) t))))
                      (lyric-lines score)))
    (:chord-symbols (chord-symbol-rows score))
    (:bars (bar-lengths score))))

(defun content-differences (a b &key (facets +content-facets+))
  "(facet value-a value-b) for each facet of FACETS on which A and B differ
(file header)."
  (loop for facet in facets
        for value-a = (content-facet a facet)
        for value-b = (content-facet b facet)
        unless (equal value-a value-b)
          collect (list facet value-a value-b)))
