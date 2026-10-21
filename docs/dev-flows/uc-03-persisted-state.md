# UC-03: "I want to track / persist X"

Any feature that records state across sessions: reading stats, per-document
settings, history, caches keyed to a document.

## 0. Locate the seam

```
Row structs      book.h next to OpenedBookState (PageTimeEntry pattern)
Schema           DatabaseManager::create_*_table() + create_tables() wiring
                 (database.cpp:1254 area) — runs EVERY startup via
                 ensure_database_compatibility → additive IF NOT EXISTS only,
                 no DATABASE_VERSION bump, no migrations
Access methods   database.cpp idiom: db_mutex lock + wstringstream + esc() +
                 sqlite3_exec + handle_error (see update_book / record_page_visit)
Keying           content checksum (survives file moves) vs path:
                 checksum lives in page_time/page_visits (GLOBAL db,
                 shared.db); the path→checksum map (document_hash) lives in
                 the LOCAL db (local.db) — create_document_hash_table()
                 executes on local_db. Do not query it from shared.db.
Callers          MainWidget hooks: validation_interval_timer lambda for
                 periodic capture, persist() for flush-on-close
```

## 1. Choose the flow direction

Always **schema-first (a)** — provider before consumer is a hard ordering rule
here: the table commit must precede the writer commit, the writer commit the
reader/UI commit. There is no useful spike-first variant for persistence;
an unpersisted spike proves nothing about the feature.

## 2. The cascade

```
wish
 → SEMANTICS: what is one record? what is the aggregate? keyed by what?
   when is a record written (event), when flushed, what caps/limits?
 → PLAN: commit chain (below), proof queries written BEFORE coding
 → branch: feature/<name>
 → tracked programs first (build + an AUTO-verify-<name>.sh whose sqlite3
   assertions are the acceptance criteria)
 → COMMIT CHAIN:
     1. "Add <name> tables to global db"        (structs + create_tables; no callers)
     2. "Add DatabaseManager <name> methods"    (record/select; still no callers)
     3. "Track <name> in MainWidget"            (first writer)
     4. "Add <name>_stats command"              (first reader; optional)
     5. "Verify <name> end-to-end"              (evidence in body)
 → PROOF (see §3)
 → REPORT
```

## 3. Proof for this use case

The DB is the observable — query it, never trust the app:

- sqlite3 with `file:...?mode=ro` (read-only; the app holds the live handle).
- Assert: rows exist for the right checksum, aggregates match the timeline
  (SUM(page_visits.duration) == page_time.total per page), timestamps ascend,
  values within caps.
- Drive the app via IPC to create the records (UC-02 pattern), quit to fire
  the persist flush, THEN query.
- The full harness: `scripts/AUTO-verify-reading-stats-e2e.sh`.

## 4. Pitfalls (observed, not hypothetical)

- **local vs global db mixup** — the reading-stats verifier's first red run
  came from querying document_hash in shared.db. Check which `sqlite3*`
  handle the create/insert executes on before writing a query.
- datetime('now') is UTC — the timeline reads one hour off local time; don't
  "fix" it, it's the existing convention.
- Decide caps at write time (e.g. 300 s visit cap) — a left-open window
  otherwise pollutes aggregates silently.
- Focus gating: anything timed must accumulate only while `isActiveWindow()`.
- Never hand-mutate the db to set up a test — drive the app; a verifier that
  writes its own fixtures proves the fixture, not the feature.

## 5. Worked pointer

Branch `feature/reading-time-tracking`, commits `ba92214` → `dc016be` →
`c5dac59` → `42d1e58` → `9139ce8`; narrative in `reading-stats-worked-example.md`.
