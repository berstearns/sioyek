# Flow: feature branch end-to-end

**Rule source:** `auto-rules/feature-branch-end-to-end/` (`_OVERVIEW.md`, p1–p6; STRICT)

## What

How a feature goes from a one-line brief to a verified branch: plan before
branch, branch before code, granular commits on the branch, device/machine
proof before "done".

## Phases (adapted to this repo — desktop Qt app, no maestro)

| Phase | Artifact | Gate |
|---|---|---|
| P2 Plan | The worker brief (`AUTO-worker-brief-reading-stats.md`) is the plan: design, commit chain, build/verify steps, constraints. Cited in commit bodies. | Brief read; assumptions verified against the actual code before acting |
| P4 Execution | `feature/<name>` branched from green `development`; commits via `scripts/AUTO-git-feature.sh` only | every commit green via `scripts/AUTO-build-sioyek.sh` before the next is stacked |
| P5 Machine proof | `scripts/AUTO-verify-reading-stats-e2e.sh` | observed artifacts: sqlite3 rows, ascending timeline, CSV file — exit 0 |
| P6 Evidence | final commit body carries the verification results | no artifacts/DB files/brief committed |

(P1 semantics docs, P3 use-case matrices, and maestro flows from the generic
workflow target Compose/Android projects; for this repo the brief's Design
section plays the P1 role and the e2e script plays P5.)

## Branch lifecycle

1. **Verify the base is green** — run the tracked build on `development`
   before branching (observed: `BUILD GREEN`, smoke `sioyek 2.0.0`).
2. **Start the branch** — `./scripts/AUTO-git-feature.sh start feature/<name> development`.
   The script refuses if tracked working-tree changes exist.
3. **Tracked programs first** — commit 1 is the `scripts/AUTO-*.sh` set, so
   every later commit's gate is itself versioned.
4. **Execute the chain** per `combinatorial-commit-chain.md`: edit → build
   gate → read diff → commit with subject + rationale body → next.
5. **Prove end-to-end** with the tracked verifier; a red run fixes the
   harness or the feature in a named fix commit, never a silent retry.
6. **Report**: branch, `git log --oneline`, TRACKED RUN blocks, observed
   evidence, config notes (e.g. the unbound `reading_stats` keybinding line).

## Constraints observed on this branch

- Additive DB changes only (`CREATE TABLE IF NOT EXISTS` in `create_tables()`);
  no migrations, no version bumps, no edits to existing tables.
- Never committed: build artifacts (`build/`, `*.o`, `Makefile`, binary),
  database files, the worker brief, run logs.
- The global hook blocks `rm -rf` and destructive git ops; use targeted
  deletes and non-destructive git only.
- "Green" per commit = compiles via the tracked build program; the final
  commit additionally carries the end-to-end proof.
