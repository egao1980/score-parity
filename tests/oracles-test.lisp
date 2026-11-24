;;;; SC5 the external oracles (src/oracles.lisp) and their checks. MuseScore and
;;;; the MusicXML XSD are optional: with them, every piece must pass; without,
;;;; every check is skipped with the reason. Fake tools (/bin/sh scripts, not on
;;;; Windows) test the plumbing and the tolerance everywhere else.

(in-package #:score-parity/tests)

(defun exe (name)
  (if (stack-process:windows-p) (concatenate 'string name ".exe") name))

(defun path-of (&rest directories)
  (format nil (if (stack-process:windows-p) "~{~A~^;~}" "~{~A~^:~}")
          (mapcar #'uiop:native-namestring directories)))

(defun same-file-p (a b)
  (and a b (equal (truename a) (truename b))))

;;; Finding MuseScore --------------------------------------------------------------

(deftest find-musescore-on-path
  (with-scratch-directory (dir)
    (let ((one (merge-pathnames "one/" dir))
          (two (merge-pathnames "two/" dir)))
      (touch (merge-pathnames (exe "MuseScore4") one))
      (touch (merge-pathnames (exe "musescore") one))
      (touch (merge-pathnames (exe "mscore") two))
      (ensure-directories-exist (merge-pathnames (concatenate 'string (exe "mscore") "/") one))
      (testing "names in +MUSESCORE-NAMES+ order within a directory; a directory isn't a match"
        (ok (equal '("mscore" "musescore" "MuseScore4" "mscore4") +musescore-names+))
        (ok (same-file-p (merge-pathnames (exe "musescore") one) (find-musescore :bin nil :path (path-of one)))))
      (testing "PATH order first"
        (ok (same-file-p (merge-pathnames (exe "musescore") one) (find-musescore :bin nil :path (path-of one two))))
        (ok (same-file-p (merge-pathnames (exe "mscore") two) (find-musescore :bin nil :path (path-of two one)))))
      (testing "empty entries and an empty BIN are skipped"
        (ok (same-file-p (merge-pathnames (exe "mscore") two)
                         (find-musescore :bin "" :path (concatenate 'string (if (stack-process:windows-p) ";" ":")
                                                                     (path-of two))))))
      (testing "nothing found"
        (ok (null (find-musescore :bin nil :path (path-of dir))))
        (ok (null (find-musescore :bin nil :path "")))
        (ok (null (find-musescore :bin nil :path nil)))))))

(deftest find-musescore-from-musescore-bin
  (with-scratch-directory (dir)
    (let ((bin (uiop:native-namestring (touch (merge-pathnames "custom-musescore" dir))))
          (on-path (merge-pathnames "bin/" dir)))
      (touch (merge-pathnames (exe "mscore") on-path))
      (ok (equal bin (find-musescore :bin bin :path (path-of on-path))) "BIN itself")
      (ok (null (find-musescore :bin (uiop:native-namestring (merge-pathnames "missing" dir))
                                :path (path-of on-path)))
          "a BIN that names nothing is not overridden by PATH")
      (ok (null (find-musescore :bin (uiop:native-namestring dir) :path nil)) "a directory is no BIN"))))

;;; MuseScore conversions with fake tools ---------------------------------------------

(deftest musescore-convert-plumbing
  (if (not (posix-shell-p))
      (skip "fake tools are /bin/sh scripts")
      (with-scratch-directory (dir)
        (let ((in (touch (merge-pathnames "in.musicxml" dir) "<score-partwise/>"))
              (out (merge-pathnames "out.musicxml" dir)))
          (testing "a conversion that works returns OUTPUT"
            (let ((copy (fake-tool dir "copy" "cp \"$3\" \"$2\"")))
              (ok (equal out (musescore-convert in out :musescore copy)))
              (ok (equal "<score-partwise/>" (uiop:read-file-string out)))))
          (testing "a conversion that fails signals ORACLE-FAILED with the tool's words"
            (let* ((failing (fake-tool dir "failing" +failing-script+))
                   (c (handler-case (progn (musescore-convert in (merge-pathnames "x.musicxml" dir)
                                                              :musescore failing)
                                           nil)
                        (oracle-failed (c) c))))
              (ok (typep c 'oracle-failed))
              (ok (and c (equal "MuseScore" (oracle-failed-tool c))))
              (ok (and c (eql 3 (oracle-failed-exit-code c))))
              (ok (and c (search "cannot open the score" (oracle-failed-output c))))))
          (testing "a conversion that writes nothing fails too"
            (let ((silent (fake-tool dir "silent" +silent-script+)))
              (ok (signals (musescore-convert in (merge-pathnames "y.musicxml" dir) :musescore silent)
                           'oracle-failed))))
          (testing "MuseScore 4 runs without a display"
            (let ((env (fake-tool dir "env" "echo \"$QT_QPA_PLATFORM\" > \"$2\"")))
              (musescore-convert in (merge-pathnames "env.txt" dir) :musescore env)
              (ok (equal (or (uiop:getenv "QT_QPA_PLATFORM") "offscreen")
                         (string-trim '(#\Newline) (uiop:read-file-string (merge-pathnames "env.txt" dir)))))))
          (ok (signals (musescore-convert in out :musescore nil) 'type-error))))))

(deftest musescore-check-with-fake-tools
  (if (not (posix-shell-p))
      (skip "fake tools are /bin/sh scripts")
      (with-scratch-directory (dir)
        (testing "ids, players and voice names are outside the comparison"
          (let ((result (check-musescore "hymn-shared" :musescore (fake-tool dir "strip" +strip-script+))))
            (ok (eq :musescore (parity-result-check result)))
            (ok (eq :pass (parity-result-status result)) (result-message result))))
        (testing "a changed pitch is a failure, with the facet that shows it"
          (let ((result (check-musescore "jingle-bells" :musescore (fake-tool dir "repitch" +repitch-script+))))
            (ok (eq :fail (parity-result-status result)))
            (ok (equal '(:spelled) (mapcar #'first (parity-result-differences result))))
            (ok (equal "MuseScore's re-export differs in :spelled" (parity-result-reason result)))))
        (testing "a failing MuseScore is an error result through RUN-CHECK"
          (let ((result (run-check :musescore "jingle-bells"
                                   :musescore (fake-tool dir "failing" +failing-script+))))
            (ok (eq :error (parity-result-status result)))
            (ok (search "MuseScore" (parity-result-reason result)))))
        (testing "no MuseScore: a skip that says how to provide one"
          (let ((result (check-musescore "jingle-bells" :musescore nil)))
            (ok (eq :skip (parity-result-status result)))
            (ok (search "MUSESCORE_BIN" (parity-result-reason result))))))))

;;; The real MuseScore, when present ---------------------------------------------------

(deftest-parametrize musescore-oracle
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  (if (null (find-musescore))
      (skip "MuseScore not found: set MUSESCORE_BIN, or put mscore, musescore or MuseScore4 on PATH")
      (passes :musescore piece)))

;;; xmllint and the XSD ----------------------------------------------------------------

(defparameter +tiny-xsd+
  "<?xml version=\"1.0\"?>
<xs:schema xmlns:xs=\"http://www.w3.org/2001/XMLSchema\">
  <xs:element name=\"tiny\" type=\"xs:string\"/>
</xs:schema>
")

(defun xmllint-p ()
  (handler-case (zerop (stack-process:run '("xmllint" "--version") :output nil :error-output nil))
    (stack-process:process-error () nil)))

(deftest musicxml-schema-lookup
  (ok (null (musicxml-schema :xsd nil)))
  (ok (null (musicxml-schema :xsd "")))
  (ok (null (musicxml-schema :xsd "/no/such/dir/musicxml.xsd")))
  (if (not (xmllint-p))
      (skip "xmllint missing")
      (with-scratch-directory (dir)
        (let ((xsd (touch (merge-pathnames "tiny.xsd" dir) +tiny-xsd+)))
          (testing "no catalog beside the schema"
            (ok (equal (list (uiop:native-namestring (truename xsd)) nil)
                       (musicxml-schema :xsd (uiop:native-namestring xsd)))))
          (testing "a catalog beside it"
            (let ((catalog (touch (merge-pathnames "catalog.xml" dir) "<catalog xmlns=\"urn:oasis:names:tc:entity:xmlns:xml:catalog\"/>")))
              (ok (equal (list (uiop:native-namestring (truename xsd)) (uiop:native-namestring (truename catalog)))
                         (musicxml-schema :xsd (uiop:native-namestring xsd))))))))))

(deftest xmllint-validation
  (if (not (xmllint-p))
      (skip "xmllint missing")
      (with-scratch-directory (dir)
        (let* ((xsd (touch (merge-pathnames "tiny.xsd" dir) +tiny-xsd+))
               (schema (musicxml-schema :xsd (uiop:native-namestring xsd))))
          (multiple-value-bind (valid message) (xmllint-validate "<tiny>ok</tiny>" schema)
            (ok valid)
            (ok (null message)))
          (multiple-value-bind (valid message) (xmllint-validate "<other/>" schema)
            (ok (not valid))
            (ok (and (stringp message) (search "other" message)) message)
            (ok (and (stringp message) (string= message (string-trim '(#\Space #\Tab #\Newline) message)))
                "trimmed"))
          (let ((result (check-xsd "jingle-bells" :schema schema)))
            (ok (eq :fail (parity-result-status result)) "a score isn't <tiny>")
            (ok (stringp (parity-result-reason result))))))))

(deftest xsd-check-without-schema
  (let ((result (check-xsd "jingle-bells" :schema nil)))
    (ok (eq :xsd (parity-result-check result)))
    (ok (eq :skip (parity-result-status result)))
    (ok (search "MUSICXML_XSD" (parity-result-reason result)))))

(deftest-parametrize xsd-oracle
    ((piece) :ids (corpus-pieces) :rows (piece-rows))
  (if (null (musicxml-schema))
      (skip "MUSICXML_XSD unset, or xmllint missing")
      (passes :xsd piece)))
