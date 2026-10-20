# Worked example: per-page reading-time tracking (feature/reading-time-tracking)

The full run of the three flows on a real feature, 2026-10-20. Use this as the
reference instantiation when applying the flows to a new feature.

## Assignment (brief)

`AUTO-worker-brief-reading-stats.md`: add per-page reading-time tracking +
page-progression recording keyed by content checksum, plus a `reading_stats`
command with CSV export. Design was pre-decided by the brief; code exploration
verified every assumption (line numbers, APIs, DB layout) before any edit.

## The commit chain and its gates

```
7c5ff34 Add tracked AUTO- programs for build, git, e2e proof
        gate: AUTO-build-sioyek.sh proven green on development baseline first
ba92214 Add page_visits and page_time tables to global db
        gate: build green (--skip-smoke)
dc016be Add DatabaseManager page-visit record and select methods
        gate: build green (--skip-package --skip-smoke)
c5dac59 Track per-page reading time in MainWidget
        gate: build green (--skip-package --skip-smoke)
42d1e58 Add reading_stats command with CSV export
        gate: full build + package + smoke green ("sioyek 2.0.0")
9139ce8 Repair e2e verifier focus targeting and checksum lookup
        gate: e2e run 2 exit 0, E2E PROOF GREEN
```

Dependency order: programs → schema → db methods → tracker (calls record) →
command (calls select) → verification. No commit references a symbol that
lands later.

## End-to-end proof (observed artifacts)

- Drove the packaged GUI via its own IPC: `--execute-command next_page` x3
  with 3 s dwell, window focus re-verified each turn, then `reading_stats`,
  then `quit` (which triggers the `persist()` flush).
- `~/.local/share/sioyek/shared.db`: `page_time` rows for pages 0–3 of
  tutorial.pdf (checksum 0bf8c44b…) with plausible totals; `page_visits`
  timeline with ascending `enter_time` (ids 4–8, 21:56:19 → 21:56:31 UTC).
- CSV written to `~/.local/share/sioyek/reading_stats_tutorial.pdf.csv`.
- All sqlite3 access read-only (`file:...?mode=ro`); no hand-mutation of the DB.

## Mistakes observed (and their rules)

1. **Red run 1 — wrong DB for the checksum.** `document_hash` lives in
   `local.db`, not `shared.db` (`create_document_hash_table()` executes on
   `local_db`). Fix: verifier reads the mapping from `local.db` by exact path.
   Rule illustrated: prove the claim against ground truth, not its proxy —
   the first run's failure *was* the ground truth speaking.
2. **Red run 1 — focus stolen.** `xdotool search --name sioyek` matched an
   unrelated window; the `isActiveWindow()`-gated tracker correctly recorded
   only the first dwell. Fix: search by `--pid`, re-verify with
   `getactivewindow` after every activation. Rule illustrated: a verifier that
   can only pass proves nothing — this red run showed the harness could fail.

Both fixes landed in one symptom-named commit (9139ce8) with the green
evidence in its body.

## Reproduce

```sh
git checkout feature/reading-time-tracking
./scripts/AUTO-build-sioyek.sh                       # build + package + smoke
./scripts/AUTO-verify-reading-stats-e2e.sh           # full e2e proof
# bind the command (unbound by default):
#   echo 'reading_stats <C-r>' >> ~/.config/sioyek/keys_user.config
```
