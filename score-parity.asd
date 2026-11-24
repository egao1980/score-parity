(defsystem "score-parity"
  :version "0.1.0"
  :description "Public-domain score corpus and parity checks for score-protocol backends: MusicXML and .mxl round trips, the hymnal voice split, MIDI round trips, MuseScore and XSD oracles"
  :author "egao1980"
  :license "MIT"
  :depends-on ((:version "score-protocol" "0.2.0") (:version "music-theory" "0.5.1") "fset"
               "process-backend-uiop" "cl-stack-pathlib")
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "conditions")
               (:file "corpus")
               (:file "backends")
               (:file "facets")
               (:file "oracles")
               (:file "checks")
               (:file "matrix"))
  :in-order-to ((test-op (test-op "score-parity/tests"))))

(defsystem "score-parity/tests"
  :depends-on ("score-parity" (:version "rove" "0.11.1")
               (:version "score-backend-musicxml" "0.1.0") (:version "score-backend-midi" "0.1.0"))
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "corpus-test")
               (:file "facets-test")
               (:file "checks-test")
               (:file "oracles-test")
               (:file "matrix-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
