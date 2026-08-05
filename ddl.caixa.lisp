(defcaixa
  :name
  "ddl"
  :kind
  :Biblioteca
  :ecosystem
  :tlisp-library
  :package
  {:name "ddl"
   :version "0.1.0"
   :description "Fail-closed additive-only DDL classifier and sunset-lifecycle helper for shinka model delivery."
   :license "MIT"
   :repository "https://github.com/pleme-io/caixa-tlisp-ddl"}
  :depends-on
  ["pleme-io/caixa-tlisp-core@main"]
  :ci-config
  {:bump {:default-type "patch"}
   :publish {:no-verify true}}
  :workflows
  [:auto-release :pre-merge-gate :security-gate])
