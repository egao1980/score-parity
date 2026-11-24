;;;; SC5 the external oracles, run out of process through process-protocol
;;;; (STACK-PROCESS:RUN, with process-backend-uiop's backend): MuseScore, which
;;;; re-exports our MusicXML, and xmllint, which validates it against the
;;;; MusicXML 4.0 XSD. Neither is required: a check whose tool is missing is
;;;; skipped with the reason (checks.lisp).
;;;;
;;;; (FIND-MUSESCORE &key (bin (uiop:getenv "MUSESCORE_BIN"))
;;;;                      (path (uiop:getenv "PATH")))
;;;;   → the native namestring of a MuseScore executable, or NIL.
;;;;   BIN, when it is a non-empty string, decides alone: BIN itself when it names
;;;;   an existing file that isn't a directory, else NIL (a wrong MUSESCORE_BIN
;;;;   is not overridden by PATH).
;;;;   Otherwise PATH is split at ";" on Windows (STACK-PROCESS:WINDOWS-P) and at
;;;;   ":" elsewhere; empty entries are skipped. For each directory in order, and
;;;;   in it each name of +MUSESCORE-NAMES+ in order (on Windows each name with
;;;;   ".exe" appended), the first that names an existing file that isn't a
;;;;   directory wins: (uiop:native-namestring (merge-pathnames name dir)), with
;;;;   dir (uiop:ensure-directory-pathname (uiop:parse-native-namestring entry)).
;;;;   NIL when BIN is empty or NIL and nothing on PATH matches; PATH NIL is an
;;;;   empty PATH. Whether the file is executable isn't checked.
;;;;
;;;; (MUSESCORE-CONVERT input output &key (musescore (find-musescore))
;;;;                                     (timeout 300))
;;;;   → OUTPUT. Runs (list MUSESCORE "-o" out in) with out and in the
;;;;   UIOP:NATIVE-NAMESTRINGs of OUTPUT and INPUT (pathnames): MuseScore's
;;;;   command-line conversion, the format from OUTPUT's type (".musicxml").
;;;;   The child's stdout is discarded, its stderr kept as a string; its
;;;;   environment is the inherited one plus QT_QPA_PLATFORM=offscreen when that
;;;;   variable isn't set (MuseScore 4 needs it without a display); TIMEOUT
;;;;   seconds as STACK-PROCESS:RUN takes it (PROCESS-TIMEOUT-ERROR reaches the
;;;;   caller). Exit code 0 and a file at OUTPUT: OUTPUT is returned. Otherwise
;;;;   ORACLE-FAILED, TOOL "MuseScore", EXIT-CODE the code, OUTPUT the stderr
;;;;   text. MUSESCORE NIL is a TYPE-ERROR.
;;;;
;;;; (MUSICXML-SCHEMA &key (xsd (uiop:getenv "MUSICXML_XSD")))
;;;;   → (xsd catalog) or NIL. XSD names a local copy of the MusicXML 4.0
;;;;   musicxml.xsd (github.com/w3c/musicxml, schema/ at tag v4.0), with xml.xsd,
;;;;   xlink.xsd and, ideally, catalog.xml beside it. NIL unless XSD is a
;;;;   non-empty string naming an existing file and (stack-process:run
;;;;   '("xmllint" "--version") :output nil :error-output nil) returns 0; a
;;;;   STACK-PROCESS:PROCESS-ERROR from that run (no xmllint) is NIL too.
;;;;   Otherwise the list of the native namestring of XSD's truename and that of
;;;;   the catalog.xml in its directory, or NIL in the second place when there is
;;;;   no such file.
;;;;
;;;; (XMLLINT-VALIDATE text schema) → (values valid-p message). SCHEMA is a list
;;;;   MUSICXML-SCHEMA returned. Runs
;;;;   (list "xmllint" "--nonet" "--noout" "--schema" xsd "-") with TEXT, a
;;;;   string, on stdin (UTF-8), stdout discarded, stderr as a string, and
;;;;   XML_CATALOG_FILES set to the catalog when there is one: --nonet keeps
;;;;   xmllint off the network, the catalog maps the schema's imports to the
;;;;   local files, as score-backend-musicxml's tests run it. VALID-P is true for
;;;;   exit code 0; MESSAGE is NIL then, else the stderr text with whitespace
;;;;   trimmed at both ends. A STACK-PROCESS:PROCESS-ERROR reaches the caller.

(in-package #:score-parity)

(defparameter +musescore-names+ '("mscore" "musescore" "MuseScore4" "mscore4")
  "The executable names FIND-MUSESCORE looks for on PATH, in order. Data.")

(defun find-musescore (&key (bin (uiop:getenv "MUSESCORE_BIN")) (path (uiop:getenv "PATH")))
  "The MuseScore executable to use, or NIL (file header)."
  (declare (ignore bin path))
  (%sc5-pending 'find-musescore))

(defun musescore-convert (input output &key (musescore (find-musescore)) (timeout 300))
  "Convert INPUT to OUTPUT with MuseScore; OUTPUT, or ORACLE-FAILED (file header)."
  (declare (ignore input output musescore timeout))
  (%sc5-pending 'musescore-convert))

(defun musicxml-schema (&key (xsd (uiop:getenv "MUSICXML_XSD")))
  "(xsd catalog) when the MusicXML 4.0 schema and xmllint are at hand, else NIL
(file header)."
  (declare (ignore xsd))
  (%sc5-pending 'musicxml-schema))

(defun xmllint-validate (text schema)
  "(values valid-p message): TEXT validated against SCHEMA by xmllint (file header)."
  (declare (ignore text schema))
  (%sc5-pending 'xmllint-validate))
