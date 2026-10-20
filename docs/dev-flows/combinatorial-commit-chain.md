# Flow: combinatorial commit chain

**Rule source:** `auto-rules/combinatorial-commits/` (all rule files; STRICT/PREFERRED mix)

## What

A nontrivial change lands as a *chain* of small, self-contained,
individually-buildable commits — not one monolithic drop. Each commit is a
save point: the smallest step that leaves the tree correct, compiling, and
describable in one imperative sentence. `i → i+1`, never `0 → done`.

## Why

Small commits compose: you can bisect them, cherry-pick them, revert one
without the rest, and review each in a single mental frame. A 2,000-line
blob is irreducible — revert, bisect, and review are all-or-nothing.

## Hard rules (distilled from the category)

1. **One logical thing per commit.** If the honest subject needs "and"/"also"/
   a comma-list, split it (`git add -p` or explicit-path staging).
2. **Every commit builds green at its own HEAD** — verified before the next
   commit is written. No forward references; no "works once the next commit
   lands". Never stack on an unverified commit.
3. **Provider before consumer.** Schema before writer, interface before first
   caller, wiring last. Draw the dependency edges, then sequence.
4. **Imperative subjects, ≤ ~50 chars** (hard 72), no trailing period, no "I/
   we/just". Test: "If applied, this commit will ___".
5. **Body = WHY, not what.** Rationale, rejected alternatives, accepted
   tradeoffs, and what was deliberately left out (and where the rest lives).
6. **Read your own diff line by line** (`git diff --cached`) before committing.
   Hunt: stray debug, wrong constants, inverted booleans, accidental files.
7. **Never mix**: refactor + behavior, formatting + logic, generated/vendored +
   hand-written, secrets/artifacts + anything, drive-by fixes + features.
8. **A fix commit names the symptom** — the error string, the trigger, the
   observable before/after. "Fix bug" is unfalsifiable.
9. **Noise commits** (typo/oops/fixup) are amended or autosquashed *before*
   push; never landed.
10. **File move ≠ file edit** — two commits, so rename detection survives.

## Gate commands

```sh
# every commit on the branch builds standalone (walk the chain):
git rev-list --reverse development..HEAD | while read sha; do
  git checkout -q "$sha" || exit 1
  ./scripts/AUTO-build-sioyek.sh --skip-package --skip-smoke \
    || { echo "BROKEN @ $sha"; git checkout -q -; exit 1; }
done; git checkout -q -

# hygiene scans:
git log --format='%s' development..HEAD | grep -iE 'wip|oops|typo|misc| and '
git diff --cached --name-only | grep -iE '\.env|token|\.key|/(build|dist)/'
```

## Worked shape (feature/reading-time-tracking)

```
7c5ff34 tracked AUTO- programs FIRST (the green gate for all later commits)
ba92214 schema: structs + create_tables wiring (provider, no callers yet)
dc016be DatabaseManager record/select methods (interface before caller)
c5dac59 MainWidget tracking hook (first caller of record_page_visit)
42d1e58 reading_stats command + CSV export (first caller of select_*)
9139ce8 verifier repair, symptom-named, evidence in body
```

Each link compiles alone, reverts alone, and reads alone. The verification
gate between commit N and N+1 is an observed artifact (build log line,
sqlite3 rows, CSV on disk) — never "the tests probably pass".
