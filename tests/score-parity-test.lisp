(defpackage #:score-parity/tests
  (:use #:cl #:rove))

(in-package #:score-parity/tests)

(deftest skeleton-loads
  (ok (find-package '#:score-parity)))
