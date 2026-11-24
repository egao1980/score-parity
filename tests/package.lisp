;;;; SC5 tests: helpers. The suite is the spec of slice SC5 (src/ file headers):
;;;; the corpus and its facts (corpus-test), the facet rules on small scores
;;;; (facets-test), every check on every piece it applies to (checks-test), the
;;;; external oracles (oracles-test) and the matrix (matrix-test). The test
;;;; system depends on both format backends, so they are loaded here and tests
;;;; may call them directly.

(defpackage #:score-parity/tests
  (:use #:cl #:rove #:score-parity)
  (:local-nicknames (#:sp #:score-protocol) (#:mt #:music-theory)
                    (#:mx #:score-backend-musicxml)))

(in-package #:score-parity/tests)

;;; Rows for DEFTEST-PARAMETRIZE (values, never quoted) -------------------------------

(defun piece-rows () (mapcar #'list (corpus-pieces)))
(defun hymn-rows () (mapcar #'list (hymn-pieces)))

;;; Reading -------------------------------------------------------------------------

(defun quietly (thunk)
  "THUNK's values, with every warning that offers MUFFLE-WARNING muffled."
  (handler-bind ((warning (lambda (c)
                            (when (find-restart 'muffle-warning c)
                              (muffle-warning c)))))
    (funcall thunk)))

(defvar *pieces* (make-hash-table :test 'equal))

(defun piece-score (piece)
  "The corpus PIECE as read by READ-MUSICXML, cached."
  (or (gethash piece *pieces*)
      (setf (gethash piece *pieces*) (mx:read-musicxml (corpus-path piece)))))

(defun result-message (result)
  "A one-line account of a PARITY-RESULT, for test output."
  (format nil "~(~A~) ~A: ~(~A~)~@[ ~A~]" (parity-result-check result) (parity-result-piece result)
          (parity-result-status result) (parity-result-reason result)))

;;; MusicXML snippets ---------------------------------------------------------------

(defun pitch-xml (pitch)
  (let ((p (mt:parse-pitch pitch)))
    (format nil "<pitch><step>~C</step>~@[<alter>~D</alter>~]<octave>~D</octave></pitch>"
            (char "CDEFGAB" (mt:spelled-pitch-letter p))
            (let ((a (mt:spelled-pitch-alter p))) (and (/= a 0) a))
            (mt:spelled-pitch-octave p))))

(defun lyric-xml (spec)
  "SPEC is (verse text syllabic)."
  (destructuring-bind (verse text syllabic) spec
    (format nil "<lyric number=\"~D\"><syllabic>~(~A~)</syllabic><text>~A</text></lyric>"
            verse syllabic text)))

(defun note (pitch duration &key chord grace tie (voice 1) staff lyrics measure-rest)
  "A <note>: PITCH a pitch name or :REST; DURATION in divisions (ignored for a
grace note); TIE NIL, :START, :STOP or :BOTH; LYRICS a list of (verse text
syllabic)."
  (with-output-to-string (s)
    (write-string "<note>" s)
    (when grace (write-string "<grace/>" s))
    (when chord (write-string "<chord/>" s))
    (if (eq pitch :rest)
        (write-string (if measure-rest "<rest measure=\"yes\"/>" "<rest/>") s)
        (write-string (pitch-xml pitch) s))
    (unless grace (format s "<duration>~D</duration>" duration))
    (when (member tie '(:stop :both)) (write-string "<tie type=\"stop\"/>" s))
    (when (member tie '(:start :both)) (write-string "<tie type=\"start\"/>" s))
    (format s "<voice>~D</voice>" voice)
    (when grace (write-string "<type>eighth</type>" s))
    (when staff (format s "<staff>~D</staff>" staff))
    (dolist (l lyrics) (write-string (lyric-xml l) s))
    (write-string "</note>" s)))

(defun backup (duration) (format nil "<backup><duration>~D</duration></backup>" duration))

(defun harmony (root kind)
  (format nil "<harmony><root><root-step>~A</root-step></root><kind>~A</kind></harmony>" root kind))

(defun cat (&rest strings) (apply #'concatenate 'string strings))

(defun snippet (measures &key (divisions 1) (time '(4 4)) (fifths 0) pickup (extra-parts '()))
  "A MusicXML partwise document: part P1 holding MEASURES (strings, each a
measure's content), the first with <attributes> (DIVISIONS, a key of FIFTHS,
TIME). PICKUP makes the first measure an implicit measure 0. EXTRA-PARTS is a
list of measure lists for parts P2, P3, ..., without attributes."
  (let ((parts (cons measures extra-parts)))
    (with-output-to-string (s)
      (format s "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%<score-partwise version=\"4.0\">")
      (format s "<work><work-title>Snippet</work-title></work><part-list>")
      (loop for i from 1 to (length parts)
            do (format s "<score-part id=\"P~D\"><part-name>Part ~D</part-name></score-part>" i i))
      (format s "</part-list>~%")
      (loop for ms in parts
            for p from 1
            do (format s "<part id=\"P~D\">~%" p)
               (loop for m in ms
                     for i from 0
                     do (if (and pickup (= i 0))
                            (format s "<measure number=\"0\" implicit=\"yes\">")
                            (format s "<measure number=\"~D\">" (if pickup i (1+ i))))
                        (when (= i 0)
                          (format s "<attributes><divisions>~D</divisions><key><fifths>~D</fifths></key>~
<time><beats>~D</beats><beat-type>~D</beat-type></time></attributes>"
                                  divisions fifths (first time) (second time)))
                        (format s "~A</measure>~%" m))
               (format s "</part>~%"))
      (format s "</score-partwise>~%"))))

(defun read-snippet (measures &rest keys)
  (mx:read-musicxml (apply #'snippet measures keys)))

;;; Scratch files and fake tools ------------------------------------------------------

(defmacro with-scratch-directory ((var) &body body)
  "Bind VAR to the pathname of a fresh temporary directory, removed afterwards."
  (let ((path (gensym "PATH")))
    `(cl-stack-pathlib:with-temp-directory (,path :prefix "score-parity-")
       (let ((,var (uiop:ensure-directory-pathname (cl-stack-pathlib:path-pathname ,path))))
         ,@body))))

(defun touch (pathname &optional (text ""))
  (ensure-directories-exist pathname)
  (with-open-file (out pathname :direction :output :if-exists :supersede :external-format :utf-8)
    (write-string text out))
  pathname)

(defun posix-shell-p ()
  "True where a fake tool can be a /bin/sh script."
  (and (not (stack-process:windows-p)) (probe-file "/bin/sh") t))

(defun fake-tool (directory name script)
  "An executable /bin/sh script NAME in DIRECTORY running SCRIPT; its native
namestring."
  (let ((path (merge-pathnames name directory)))
    (touch path (format nil "#!/bin/sh~%~A~%" script))
    (stack-process:run (list "chmod" "+x" (uiop:native-namestring path)) :output nil :error-output nil)
    (uiop:native-namestring path)))

;;; A fake MuseScore: called as  tool -o OUT IN  ($2 is OUT, $3 is IN).

(defparameter +strip-script+
  "sed -e '/<player /,/<\\/player>/d' -e 's/\\(<note[^>]*\\) id=\"[^\"]*\"/\\1/' -e 's/\\(<lyric[^>]*\\) id=\"[^\"]*\"/\\1/' -e 's/\\(<harmony[^>]*\\) id=\"[^\"]*\"/\\1/' \"$3\" > \"$2\""
  "Rewrites the file the way another program might: no players (so no voice
names), no ids on notes, lyrics and harmonies. Within the oracle's tolerance.")

(defparameter +repitch-script+
  "sed -e 's/<step>B</<step>C</' \"$3\" > \"$2\""
  "Turns every B into a C: outside the tolerance.")

(defparameter +failing-script+
  "echo 'cannot open the score' >&2; exit 3"
  "Fails the way a broken MuseScore does.")

(defparameter +silent-script+
  "exit 0"
  "Claims success and writes nothing.")
