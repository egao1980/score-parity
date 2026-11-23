(defsystem "score-parity"
  :version "0.0.1"
  :description "Parity corpus for score-protocol backends: round-trip and interop checks"
  :author "egao1980"
  :license "MIT"
  :pathname "src"
  :serial t
  :components ((:file "package"))
  :in-order-to ((test-op (test-op "score-parity/tests"))))

(defsystem "score-parity/tests"
  :depends-on ("score-parity" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "score-parity-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
