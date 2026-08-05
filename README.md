# caixa-tlisp-ddl

A fail-closed, additive-only DDL classifier and sunset-lifecycle helper for
shinka model delivery. Depends on caixa-tlisp-core for the result accessors.

Ninth member of the `caixa-tlisp-*` family (`stdlib`, `core`, `git`, `cargo`,
`helm`, `handoff`, `gha`, `rollout`).

The contract, from `theory/SHINKA-MODEL-EVOLUTION.md` §IV.5: a model grows and
is never cut. Columns are tagged and sunset, drained and sealed. They are not
dropped.

## Why a classifier and not a review checklist

shinka's `EvolutionOp` has two arms and no destructive variant, so a mold file
naming one is rejected at the wire boundary. That is a real guarantee about the
*op vocabulary*. It says nothing about the SQL inside a `RawAdditive`, whose own
doc comment is explicit: additive **by intent, not by type guarantee**. This
library is the layer that reads that SQL.

## Four verdicts

| verdict | disposition |
|---|---|
| `:additive` | permit |
| `:blocking` | permit, report a warning |
| `:data-destructive` | refuse unless the caller declares sunset step 4 (`drain`) |
| `:schema-destructive` | refuse, no waiver |
| `:unknown` | refuse (fail-closed) |

Unmatched statements are `:unknown` and refused, so a novel statement shape is a
refusal rather than a silent permit. A dollar-quoted body (`$$ … $$`) refuses the
whole document: its semicolons survive literal-blanking, so the splitter cannot
be trusted on it.

## Provides

- `(ddl:gate doc sunset-step)` — the entry point. Returns an alist with `ok`,
  `statements`, `violations`, `warnings`. `sunset-step` is the caller's
  declaration; only `"drain"` unlocks the data-destructive verdicts, and nothing
  unlocks the schema-destructive or unknown ones.
- `(ddl:report g)` — renders a gate result as plain text.
- `(ddl:classify-document doc)` / `(ddl:classify stmt)` — per-statement verdicts.
- `(ddl:split-statements doc)` / `(ddl:sanitize doc)` — the scanner, exposed
  because it is the part most worth testing against your own corpus.
- `(ddl:sunset-comment table column replacement on-date)` and
  `(ddl:seal-comment table column on-date)` — the two lifecycle markers. Both
  emit `COMMENT ON COLUMN`, which is itself additive.
- `ddl:sunset-steps` — `deprecate`, `dual-write`, `backfill`, `drain`, `seal`.
  Five, and deliberately no sixth: a sealed column stays in the table forever,
  empty.

## The scanner, and what it refuses to be fooled by

Keyword matching on raw SQL is wrong in the one direction that matters. Three
stages run before any rule is tested:

1. `--` comments are stripped **quote-aware**. A naive split-at-`--` deletes the
   tail of `SELECT '--' ; DROP TABLE t`, hiding a destructive statement. A `--`
   only opens a comment when the text before it holds an even number of single
   quotes.
2. `/* */` blocks are stripped after the lines are joined, since they span lines.
3. Single-quoted literal *contents* are blanked, keeping the quotes. This is what
   makes splitting on `;` safe. SQL's doubled-quote escape (`''`) toggles twice
   and lands back outside, which is correct. Double-quoted identifiers are left
   alone — they carry the table and column names the rules need to read.

## Known limits, stated rather than discovered later

- A function call inside `SELECT` is not analysed. `^select` classifies as
  read-only; a volatile function invoked from one is not caught.
- `/* */` inside a string literal is stripped as a comment. Contrived, and it
  only ever removes SQL from view within a literal.
- The rule table is Postgres/MySQL-flavoured. A dialect with different
  destructive vocabulary needs its own rules, not a tweak to these.
- Rule order is load-bearing: destructive shapes are tested before the additive
  shapes that would otherwise swallow them.

## Use

Composition is by inlining, not `(require …)` — the family convention. Strip the
library's `(provide …)` form if one is ever added; at script top level it is an
error.

```lisp
(defcaixa my-gate
  :ecosystem :tlisp-library
  :depends-on ["pleme-io/caixa-tlisp-core@main"
               "pleme-io/caixa-tlisp-ddl@main"])
```

```bash
cat caixa-tlisp-core/stdlib.tlisp caixa-tlisp-ddl/stdlib.tlisp my-gate.tlisp \
  > /tmp/gate.tlisp && tatara-script /tmp/gate.tlisp schema.sql
```

## Tests

`tatara-script --test stdlib.tlisp` — 9 tests.

They assert with the built-in `assert` macro, and that detail is load-bearing.
`error` in tatara-lisp is a CONSTRUCTOR (`Arity::Range(2,3)`) that returns a
`Value::Error`; `deftest` fails only on a *thrown* error. So a hand-rolled
`(if c #t (error "tag" msg))` assert is inert and every test built on one passes
vacuously. Proven here by mutation: with the quote-aware comment stripper broken
so that a `DROP TABLE` passed the gate, a hand-rolled suite still reported 9/9.
With `assert`, the same mutation gives 8/9 and names the right test.

Re-run that mutation before trusting any change to the scanner.
