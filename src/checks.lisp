;;;; SC5 the checks: one per backend path, run on one corpus piece.
;;;;
;;;; A check returns a PARITY-RESULT (given): CHECK, its keyword; PIECE; STATUS,
;;;; :PASS, :FAIL, :SKIP or :ERROR; REASON, NIL for :PASS and a string
;;;; otherwise; DIFFERENCES, a list as CONTENT-DIFFERENCES returns (facets.lisp),
;;;; or (). +CHECKS+ (given) lists them in matrix order, each with the backend it
;;;; exercises, its matrix LABEL and its FUNCTION.
;;;;
;;;; Below, S is (READ-PIECE piece): (call-backend :musicxml "READ-MUSICXML"
;;;; (corpus-path piece) :split-voices nil), given. Backend functions are named
;;;; by their score-backend-musicxml and score-backend-midi names and reached
;;;; through CALL-BACKEND (backends.lisp), never by a compile-time reference.
;;;; Every check calls them with each LOSSY-CONVERSION muffled (MUFFLE-WARNING):
;;;; those warnings are expected (a MIDI file holds no ids). Other conditions
;;;; pass through; LOW-CONFIDENCE-GUESS is SIGNALled and declined.
;;;;
;;;; :MUSICXML  (CHECK-MUSICXML piece). T1 = (write-musicxml S),
;;;;   S2 = (read-musicxml T1), T2 = (write-musicxml S2). :PASS when
;;;;   (score-equal S S2) and (string= T1 T2): the round trip keeps the score,
;;;;   ids included, and the second write is byte-stable. Else :FAIL, the first
;;;;   that applies: REASON "read, write, read is not SCORE-EQUAL" with
;;;;   DIFFERENCES (content-differences S S2) (() when only what the facets
;;;;   don't see differs); REASON "the second write differs from the first at
;;;;   character N", N = (mismatch T1 T2).
;;;; :MXL  (CHECK-MXL piece). O1 = (write-mxl S), S3 = (read-mxl O1),
;;;;   O2 = (write-mxl S3); for an ARCHIVE-PIECE also A = (read-mxl
;;;;   (corpus-path piece "mxl")), the archive as another program writes it.
;;;;   :PASS when (score-equal S S3), (equalp O1 O2), and A, when there is one,
;;;;   is SCORE-EQUAL to S. Else :FAIL, the first that applies: REASON "write-mxl,
;;;;   read-mxl is not SCORE-EQUAL" with (content-differences S S3); REASON "the
;;;;   second archive differs from the first at byte N", N = (mismatch O1 O2);
;;;;   REASON "corpus/<piece>.mxl does not read as corpus/<piece>.musicxml" with
;;;;   (content-differences S A).
;;;; :HYMNAL-SPLIT  (CHECK-HYMNAL-SPLIT piece), for the HYMN-PIECES. H =
;;;;   (read-piece piece :split-voices :auto); E = (piece-fact piece
;;;;   :split-lines), the soprano, alto, tenor and bass of the hand-split tune.
;;;;   :PASS when (voice-lines H) is EQUAL to E. Else :FAIL with DIFFERENCES
;;;;   ((:split-lines E (voice-lines H))) and REASON "N voice lines, not M" (N
;;;;   for H, M for E) when the counts differ, else "voice line K differs", K
;;;;   the 1-based place of the first line that does. A piece without
;;;;   :SPLIT-LINES gives :SKIP, REASON "not a hymn".
;;;; :MIDI  (CHECK-MIDI piece): score -> MIDI -> score, played as written.
;;;;   O = (export-midi S nil :unfold nil), the octets; M = (import-midi O).
;;;;   D = (content-differences S M :facets +midi-facets+).
;;;; :MIDI-UNFOLD  (CHECK-MIDI-UNFOLD piece): the same with repeats, endings and
;;;;   jumps unfolded. O = (export-midi S nil) (its :UNFOLD T), M =
;;;;   (import-midi O), U the first value of (score-protocol:unfold S), and
;;;;   D = (content-differences U M :facets +midi-facets+).
;;;;   For both: :PASS when D is (); else :FAIL, DIFFERENCES D and REASON
;;;;   "score, MIDI, score differs in F, ..." naming D's facets in lower case
;;;;   ("score, MIDI, score differs in :notes, :bars"). +MIDI-FACETS+ is what an
;;;;   SMF carries back: sounding pitches with onsets and ends (spellings of notes
;;;;   outside the key are guesses on import), verse 1 with its hyphens, the
;;;;   chord symbols (exported as prefixed text) and the bar lengths.
;;;; :MUSESCORE  (CHECK-MUSESCORE piece &key (musescore (find-musescore))): the
;;;;   MuseScore interop oracle. MUSESCORE NIL gives :SKIP, REASON "MuseScore not
;;;;   found: set MUSESCORE_BIN, or put mscore, musescore or MuseScore4 on PATH".
;;;;   Else, in a fresh temporary directory (STACK-PATHLIB:WITH-TEMP-DIRECTORY):
;;;;   in.musicxml holds (write-musicxml S), UTF-8; (musescore-convert in out
;;;;   :musescore MUSESCORE) writes out.musicxml; R = (read-musicxml out
;;;;   :unsupported :skip); D = (content-differences S R :facets
;;;;   +musescore-facets+). :PASS when D is (); else :FAIL, DIFFERENCES D, REASON
;;;;   "MuseScore's re-export differs in F, ..." as for :MIDI. ORACLE-FAILED and
;;;;   process errors reach the caller.
;;;;   The tolerance. MuseScore writes the file its own way: no ids, its own
;;;;   divisions, voice numbers, beams, layout and playback elements, rests and
;;;;   gaps written as it pleases, empty voices dropped, elements our reader
;;;;   doesn't map (skipped with :UNSUPPORTED :SKIP). +MUSESCORE-FACETS+ is what
;;;;   must come back unchanged: per sounding voice, the notes with their spelled
;;;;   pitches, onsets and tied ends; the lyrics of every verse with their
;;;;   syllabic types; the bar lengths. Equality there is exact; nothing else is
;;;;   compared (facets.lisp, "Never compared").
;;;; :XSD  (CHECK-XSD piece &key (schema (musicxml-schema))). SCHEMA NIL gives
;;;;   :SKIP, REASON "MUSICXML_XSD unset, or xmllint missing". Else
;;;;   (xmllint-validate (write-musicxml S) SCHEMA): :PASS when valid, else :FAIL
;;;;   with REASON xmllint's message.
;;;;
;;;; (CHECK-APPLIES-P check piece): for :HYMNAL-SPLIT, PIECE is one of the
;;;; HYMN-PIECES; T for the other checks. PARITY-MATRIX runs a check only on the
;;;; pieces it applies to.
;;;; (RUN-CHECK check piece &rest keys) applies the check's FUNCTION to PIECE and
;;;; KEYS and returns its result. A BACKEND-MISSING signalled meanwhile gives a
;;;; result with STATUS :SKIP; any other ERROR one with STATUS :ERROR; both with
;;;; REASON the condition's report (PRINC-TO-STRING) and DIFFERENCES (). This
;;;; is the harness's job: a backend's error is a finding to report, not a crash.
;;;; For both functions a CHECK that isn't a key of +CHECKS+ is a TYPE-ERROR.

(in-package #:score-parity)

(defstruct (parity-result (:copier nil))
  "One check on one piece (file header)."
  (check nil :type symbol)
  (piece nil :type (or null string))
  (status nil :type (member nil :pass :fail :skip :error))
  (reason nil :type (or null string))
  (differences '() :type list))

(defparameter +checks+
  '((:musicxml :backend :musicxml :label "musicxml" :function check-musicxml)
    (:mxl :backend :musicxml :label "mxl" :function check-mxl)
    (:hymnal-split :backend :musicxml :label "hymnal" :function check-hymnal-split)
    (:midi :backend :midi :label "midi" :function check-midi)
    (:midi-unfold :backend :midi :label "midi-unfold" :function check-midi-unfold)
    (:musescore :backend :musescore :label "musescore" :function check-musescore)
    (:xsd :backend :xmllint :label "xsd" :function check-xsd))
  "(check :backend b :label text :function f) per check, in matrix order. Data.")

(defparameter +midi-facets+ '(:notes :verse-1 :chord-symbols :bars)
  "The facets score -> MIDI -> score keeps (file header). Data.")

(defparameter +musescore-facets+ '(:spelled :lyrics :bars)
  "The facets MuseScore's re-export keeps: the oracle's tolerance (file header). Data.")

(defun read-piece (piece &key split-voices)
  "The corpus PIECE as READ-MUSICXML reads it (given)."
  (call-backend :musicxml "READ-MUSICXML" (corpus-path piece) :split-voices split-voices))

;;; Internal helpers ----------------------------------------------------------------

(defun %lossless (thunk)
  "THUNK's values, each SCORE-PROTOCOL:LOSSY-CONVERSION muffled with MUFFLE-WARNING.
No other condition is handled: LOW-CONFIDENCE-GUESS, which is SIGNALled, is
declined (file header)."
  (handler-bind ((score-protocol:lossy-conversion #'muffle-warning))
    (funcall thunk)))

(defun %result (check piece status &optional reason differences)
  (make-parity-result :check check :piece piece :status status :reason reason
                      :differences differences))

(defun %differences-result (check piece what differences)
  ":PASS when DIFFERENCES is (), else :FAIL with REASON \"WHAT differs in F, ...\"
naming their facets in lower case (file header, :MIDI)."
  (if differences
      (%result check piece :fail
               (format nil "~A differs in ~{~(~S~)~^, ~}" what (mapcar #'first differences))
               differences)
      (%result check piece :pass)))

;;; The checks ----------------------------------------------------------------------
;;; A later artifact is made only once the earlier test passed: the first :FAIL
;;; that applies is reported, never an error from an artifact it doesn't need.

(defun check-musicxml (piece)
  "MusicXML read -> write -> read, byte-stable (file header)."
  (%lossless
   (lambda ()
     (let* ((s (read-piece piece))
            (t1 (call-backend :musicxml "WRITE-MUSICXML" s))
            (s2 (call-backend :musicxml "READ-MUSICXML" t1))) ; a string is MusicXML text
       (if (not (score-protocol:score-equal s s2))
           (%result :musicxml piece :fail "read, write, read is not SCORE-EQUAL"
                    (content-differences s s2))
           (let ((t2 (call-backend :musicxml "WRITE-MUSICXML" s2)))
             (if (string= t1 t2)
                 (%result :musicxml piece :pass)
                 (%result :musicxml piece :fail
                          (format nil "the second write differs from the first at character ~D"
                                  (mismatch t1 t2))))))))))

(defun %check-archive (piece s)
  "The corpus archive step of CHECK-MXL: A against S, for an ARCHIVE-PIECE."
  (if (member piece (archive-pieces) :test #'equal)
      (let ((a (call-backend :musicxml "READ-MXL" (corpus-path piece "mxl"))))
        (if (score-protocol:score-equal s a)
            (%result :mxl piece :pass)
            (%result :mxl piece :fail
                     (format nil "corpus/~A.mxl does not read as corpus/~A.musicxml" piece piece)
                     (content-differences s a))))
      (%result :mxl piece :pass)))

(defun check-mxl (piece)
  ".mxl write -> read, byte-stable, and the corpus archive (file header)."
  (%lossless
   (lambda ()
     (let* ((s (read-piece piece))
            (o1 (call-backend :musicxml "WRITE-MXL" s))
            (s3 (call-backend :musicxml "READ-MXL" o1)))
       (if (not (score-protocol:score-equal s s3))
           (%result :mxl piece :fail "write-mxl, read-mxl is not SCORE-EQUAL"
                    (content-differences s s3))
           (let ((o2 (call-backend :musicxml "WRITE-MXL" s3)))
             (if (equalp o1 o2)        ; octet vectors: EQUAL compares them by identity
                 (%check-archive piece s)
                 (%result :mxl piece :fail
                          (format nil "the second archive differs from the first at byte ~D"
                                  (mismatch o1 o2))))))))))

(defun check-hymnal-split (piece)
  "The hymnal voice split gives the four voice lines (file header)."
  ;; The facts first: a piece with none is UNKNOWN-PIECE, not "not a hymn".
  (let ((expected (piece-fact piece :split-lines)))
    (if (null expected)
        (%result :hymnal-split piece :skip "not a hymn")
        (let ((lines (%lossless
                      (lambda () (voice-lines (read-piece piece :split-voices :auto))))))
          (if (equal lines expected)
              (%result :hymnal-split piece :pass)
              (%result :hymnal-split piece :fail
                       (if (/= (length lines) (length expected))
                           (format nil "~D voice lines, not ~D" (length lines) (length expected))
                           (format nil "voice line ~D differs"
                                   (1+ (mismatch lines expected :test #'equal))))
                       (list (list :split-lines expected lines))))))))

(defun check-midi (piece)
  "score -> MIDI -> score as written (file header)."
  (%lossless
   (lambda ()
     (let* ((s (read-piece piece))
            (m (call-backend :midi "IMPORT-MIDI"
                             (call-backend :midi "EXPORT-MIDI" s nil :unfold nil))))
       (%differences-result :midi piece "score, MIDI, score"
                            (content-differences s m :facets +midi-facets+))))))

(defun check-midi-unfold (piece)
  "score -> MIDI -> score unfolded (file header)."
  (%lossless
   (lambda ()
     (let* ((s (read-piece piece))
            (m (call-backend :midi "IMPORT-MIDI" (call-backend :midi "EXPORT-MIDI" s nil)))
            (u (values (score-protocol:unfold s)))) ; the view: id map and passes dropped
       (%differences-result :midi-unfold piece "score, MIDI, score"
                            (content-differences u m :facets +midi-facets+))))))

(defun check-musescore (piece &key (musescore (find-musescore)))
  "Our MusicXML through MuseScore and back, within the tolerance (file header)."
  (if (null musescore)
      (%result :musescore piece :skip
               "MuseScore not found: set MUSESCORE_BIN, or put mscore, musescore or MuseScore4 on PATH")
      (%lossless
       (lambda ()
         (let ((s (read-piece piece)))
           (cl-stack-pathlib:with-temp-directory (tmp :prefix "score-parity-")
             (let* ((directory (uiop:ensure-directory-pathname (cl-stack-pathlib:path-pathname tmp)))
                    (in (make-pathname :name "in" :type "musicxml" :defaults directory))
                    (out (make-pathname :name "out" :type "musicxml" :defaults directory)))
               ;; To a pathname, WRITE-MUSICXML writes UTF-8.
               (call-backend :musicxml "WRITE-MUSICXML" s in)
               (musescore-convert in out :musescore musescore)
               ;; OUT stays a pathname: a string would be read as MusicXML text.
               (let ((r (call-backend :musicxml "READ-MUSICXML" out :unsupported :skip)))
                 (%differences-result :musescore piece "MuseScore's re-export"
                                      (content-differences s r :facets +musescore-facets+))))))))))

(defun check-xsd (piece &key (schema (musicxml-schema)))
  "Our MusicXML against the MusicXML 4.0 XSD (file header)."
  (if (null schema)
      (%result :xsd piece :skip "MUSICXML_XSD unset, or xmllint missing")
      (%lossless
       (lambda ()
         (multiple-value-bind (valid message)
             (xmllint-validate (call-backend :musicxml "WRITE-MUSICXML" (read-piece piece)) schema)
           (if valid
               (%result :xsd piece :pass)
               (%result :xsd piece :fail message)))))))

;;; Running checks ------------------------------------------------------------------

(defun %check-p (object)
  (and (assoc object +checks+) t))

(defun %check-function (check)
  "The FUNCTION of CHECK in +CHECKS+: a symbol, called through its global
definition at call time."
  (getf (cdr (assoc check +checks+)) :function))

(defun check-applies-p (check piece)
  "True when CHECK runs on PIECE in the matrix (file header)."
  (check-type check (satisfies %check-p) "a check of +CHECKS+")
  (if (eq check :hymnal-split)
      (and (member piece (hymn-pieces) :test #'equal) t)
      t))

(defun run-check (check piece &rest keys)
  "CHECK on PIECE, its errors reported as results (file header)."
  ;; Outside the HANDLER-CASE: an unknown CHECK is the caller's TYPE-ERROR.
  (check-type check (satisfies %check-p) "a check of +CHECKS+")
  (handler-case (apply (%check-function check) piece keys)
    ;; BACKEND-MISSING is an ERROR: its clause comes first.
    (backend-missing (condition)
      (%result check piece :skip (princ-to-string condition)))
    (error (condition)
      (%result check piece :error (princ-to-string condition)))))
