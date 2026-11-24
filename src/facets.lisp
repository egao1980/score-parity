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

(defun voice-lines (score)
  "The sounding notes of every voice that sounds, as rows (onset end key pitch)
(file header)."
  (declare (ignore score))
  (%sc5-pending 'voice-lines))

(defun lyric-lines (score)
  "The lyrics of the voices of VOICE-LINES, as rows (onset verse text syllabic)
(file header)."
  (declare (ignore score))
  (%sc5-pending 'lyric-lines))

(defun chord-symbol-rows (score)
  "The chord-symbol anchors as rows (onset text) (file header)."
  (declare (ignore score))
  (%sc5-pending 'chord-symbol-rows))

(defun bar-lengths (score)
  "The length of every bar, in order (file header)."
  (declare (ignore score))
  (%sc5-pending 'bar-lengths))

(defun score-features (score)
  "The keywords of +FEATURES+ that SCORE has (file header)."
  (declare (ignore score))
  (%sc5-pending 'score-features))

(defun content-facet (score facet)
  "The FACET view of SCORE's content (file header)."
  (declare (ignore score facet))
  (%sc5-pending 'content-facet))

(defun content-differences (a b &key (facets +content-facets+))
  "(facet value-a value-b) for each facet of FACETS on which A and B differ
(file header)."
  (declare (ignore a b facets))
  (%sc5-pending 'content-differences))
