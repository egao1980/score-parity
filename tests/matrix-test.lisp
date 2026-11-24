;;;; SC5 the matrix (src/matrix.lisp): PARITY-MATRIX, MATRIX-CELLS and
;;;; PRINT-MATRIX, on made-up results and on the whole corpus.

(in-package #:score-parity/tests)

(defun results-fixture ()
  "Made-up results. jingle-bells has :lyrics :chord-symbols :lead-sheet :repeats
:endings; hymn-shared :lyrics :ties :shared-staff."
  (list (make-parity-result :check :midi :piece "jingle-bells" :status :error :reason "R3")
        (make-parity-result :check :musicxml :piece "jingle-bells" :status :pass)
        (make-parity-result :check :musicxml :piece "hymn-shared" :status :fail :reason "R2")
        (make-parity-result :check :musescore :piece "jingle-bells" :status :skip :reason "R4")))

(deftest matrix-cells-count-per-feature
  (ok (equal '((:lyrics (:musicxml 1 1 0 0) (:midi 0 0 1 0) (:musescore 0 0 0 1))
               (:ties (:musicxml 0 1 0 0) (:midi 0 0 0 0) (:musescore 0 0 0 0))
               (:parts (:musicxml 0 0 0 0) (:midi 0 0 0 0) (:musescore 0 0 0 0))
               (:all (:musicxml 1 1 0 0) (:midi 0 0 1 0) (:musescore 0 0 0 1)))
             (matrix-cells (results-fixture) :features '(:lyrics :ties :parts))))
  (ok (equal (append (mapcar #'list +features+) '((:all))) (matrix-cells '()))
      "no results: every row, no cells")
  (ok (equal (append +features+ '(:all)) (mapcar #'first (matrix-cells (results-fixture))))))

(deftest print-matrix-layout
  (let* ((results (results-fixture))
         returned
         (text (with-output-to-string (s) (setf returned (print-matrix results s))))
         (lines (uiop:split-string (string-right-trim '(#\Newline) text) :separator '(#\Newline))))
    (ok (eq results returned) "returns RESULTS")
    (ok (= (+ 1 (length +features+) 1 2) (length lines)) "header, a row per feature, the summary, two findings")
    (ok (equal "feature        musicxml     midi         musescore" (first lines)))
    (ok (equal "lyrics         1/2          0/1          skip" (second lines)))
    (ok (equal "chord-symbols  1/1          0/1          skip" (fourth lines)))
    (ok (equal "ties           0/1          -            -" (nth (1+ (position :ties +features+)) lines)))
    (ok (equal "parts          -            -            -" (nth (length +features+) lines)))
    (ok (equal "all            1/2          0/1          skip" (nth (1+ (length +features+)) lines)))
    (ok (equal '("midi jingle-bells error: R3" "musicxml hymn-shared fail: R2") (last lines 2)))
    (ok (every (lambda (line) (string= line (string-right-trim " " line))) lines) "no trailing spaces")
    (ok (equal (format nil "feature~%~{~(~A~)~%~}all~%" +features+)
               (with-output-to-string (s) (print-matrix '() s)))
        "no results: the labels alone")))

(deftest parity-matrix-order-and-tools
  (let ((results (parity-matrix :pieces '("jingle-bells" "hymn-shared") :checks '(:hymnal-split :musicxml)
                                :musescore nil :schema nil)))
    (ok (equal '((:hymnal-split "hymn-shared") (:musicxml "jingle-bells") (:musicxml "hymn-shared"))
               (mapcar (lambda (r) (list (parity-result-check r) (parity-result-piece r))) results))
        "checks in the order given, pieces in the order given, only where the check applies")
    (ok (every (lambda (r) (eq :pass (parity-result-status r))) results)))
  (let ((results (parity-matrix :pieces '("jingle-bells") :checks '(:musescore :xsd) :musescore nil :schema nil)))
    (ok (equal '(:skip :skip) (mapcar #'parity-result-status results)) "no tools: skips")))

(defvar *corpus-matrix* nil
  "The matrix of the whole corpus, computed once.")

(defun corpus-matrix ()
  (or *corpus-matrix* (setf *corpus-matrix* (parity-matrix))))

(deftest corpus-matrix-summary
  (let* ((results (corpus-matrix))
         (pieces (length (corpus-pieces)))
         (summary (rest (assoc :all (matrix-cells results)))))
    (ok (= (+ (* 6 pieces) (length (hymn-pieces))) (length results)) "every check on every piece it applies to")
    (dolist (check '(:musicxml :mxl :midi :midi-unfold))
      (ok (equal (list check pieces 0 0 0) (assoc check summary)) (format nil "~(~S~): all pass" check)))
    (ok (equal (list :hymnal-split (length (hymn-pieces)) 0 0 0) (assoc :hymnal-split summary)) ":hymnal-split: all pass")
    (dolist (check '(:musescore :xsd))
      (let ((cell (assoc check summary)))
        (ok (or (equal (list check pieces 0 0 0) cell) (equal (list check 0 0 0 pieces) cell))
            (format nil "~(~S~): all pass, or all skip without the tool: ~S" check cell))))
    ;; The matrix in the test log.
    (print-matrix results)))
