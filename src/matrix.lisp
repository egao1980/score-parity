;;;; SC5 the matrix: every check over the corpus, read per notation feature.
;;;;
;;;; (PARITY-MATRIX &key (pieces (corpus-pieces)) (checks (mapcar #'first +checks+))
;;;;                     (musescore (find-musescore)) (schema (musicxml-schema)))
;;;;   → a list of PARITY-RESULTs: for each check of CHECKS in that order, and
;;;;   for each piece of PIECES in that order that (check-applies-p check piece),
;;;;   (run-check check piece . keys), KEYS (:musescore MUSESCORE) for
;;;;   :MUSESCORE, (:schema SCHEMA) for :XSD and () for the others. So the tools
;;;;   are looked up once.
;;;;
;;;; (MATRIX-CELLS results &key (features +features+))
;;;;   → one row per feature of FEATURES, in that order, then the summary row
;;;;   :ALL. A row is (LABEL cell ...): LABEL the feature (or :ALL), then one cell
;;;;   per check that occurs in RESULTS, in +CHECKS+ order. A cell is
;;;;   (CHECK PASS FAIL ERROR SKIP): how many results of that check, among those
;;;;   whose piece has the feature (PIECE-FEATURES; every result in the :ALL
;;;;   row), have status :PASS, :FAIL, :ERROR and :SKIP.
;;;;
;;;; (PRINT-MATRIX &optional (results (parity-matrix)) (stream *standard-output*))
;;;;   → RESULTS, after writing the matrix to STREAM. Each line is built, right-
;;;;   trimmed of spaces, and written followed by a newline:
;;;;     the header: "feature" padded to 15 characters, then the :LABEL of each
;;;;       check of the cells, each padded to 13 (~15A, ~13A: spaces on the
;;;;       right);
;;;;     one line per row of (matrix-cells results): the label in lower case
;;;;       ("chord-symbols", ..., "all") padded to 15, then each cell padded to
;;;;       13: "P/N" when N = PASS + FAIL + ERROR is positive ("33/34"), "skip"
;;;;       when N is 0 and SKIP is positive, "-" when both are 0;
;;;;     then one line per result whose status is :FAIL or :ERROR, in RESULTS
;;;;       order: "<label> <piece> <status>: <reason>", the status in lower case
;;;;       ("midi camptown-races fail: score, MIDI, score differs in :bars").
;;;;   With no results there are no cells: the header is "feature", and every
;;;;   row line is its label alone.

(in-package #:score-parity)

(defun parity-matrix (&key (pieces (corpus-pieces)) (checks (mapcar #'first +checks+))
                        (musescore (find-musescore)) (schema (musicxml-schema)))
  "Every check of CHECKS on every piece of PIECES it applies to (file header)."
  ;; The defaults are evaluated once per call: each tool is looked up once.
  (loop for check in checks
        for keys = (case check
                     (:musescore (list :musescore musescore))
                     (:xsd (list :schema schema))
                     (t '()))
        nconc (loop for piece in pieces
                    when (check-applies-p check piece)
                      collect (apply #'run-check check piece keys))))

(defun %result-checks (results)
  "The checks that occur in RESULTS, in +CHECKS+ order."
  (loop for (check) in +checks+
        when (find check results :key #'parity-result-check)
          collect check))

(defun %check-label (check)
  "CHECK's :LABEL in +CHECKS+."
  (or (getf (cdr (assoc check +checks+)) :label)
      (string-downcase (princ-to-string check))))

(defun matrix-cells (results &key (features +features+))
  "Per feature, then :ALL, the counts of RESULTS per check and status (file header)."
  (let ((checks (%result-checks results))
        ;; Each result with its piece's features, looked up once.
        (tagged (mapcar (lambda (result)
                          (cons result (piece-features (parity-result-piece result))))
                        results)))
    (flet ((row (label row-results)
             (cons label
                   (loop for check in checks
                         for mine = (remove-if-not (lambda (result)
                                                     (eq check (parity-result-check result)))
                                                   row-results)
                         collect (cons check
                                       (loop for status in '(:pass :fail :error :skip)
                                             collect (count status mine
                                                            :key #'parity-result-status)))))))
      (append (loop for feature in features
                    collect (row feature
                                 (loop for (result . features-of-piece) in tagged
                                       when (member feature features-of-piece)
                                         collect result)))
              (list (row :all results))))))

(defun %cell-text (cell)
  "\"P/N\", \"skip\" or \"-\" for the cell (CHECK PASS FAIL ERROR SKIP) (file header)."
  (destructuring-bind (pass fail errors skip) (rest cell)
    (let ((n (+ pass fail errors)))
      (cond ((plusp n) (format nil "~D/~D" pass n))
            ((plusp skip) "skip")
            (t "-")))))

(defun print-matrix (&optional (results (parity-matrix)) (stream *standard-output*))
  "Write the matrix of RESULTS to STREAM; RESULTS (file header)."
  (flet ((line (control &rest arguments)
           (write-line (string-right-trim " " (apply #'format nil control arguments)) stream)))
    (line "~15A~{~13A~}" "feature" (mapcar #'%check-label (%result-checks results)))
    (dolist (row (matrix-cells results))
      (line "~15A~{~13A~}" (string-downcase (symbol-name (first row)))
            (mapcar #'%cell-text (rest row))))
    (dolist (result results)
      (when (member (parity-result-status result) '(:fail :error))
        (line "~A ~A ~(~A~): ~A" (%check-label (parity-result-check result))
              (parity-result-piece result) (parity-result-status result)
              (parity-result-reason result)))))
  results)
