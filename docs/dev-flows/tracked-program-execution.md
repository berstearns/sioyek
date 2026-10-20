# Flow: tracked-program execution

**Rule source:** `auto-rules/from-me/every-command-is-a-tracked-local-program-never-an-inline-snippet.md` (STRICT)

## What

Anything the agent *runs as code* — builds, git mutations, verifications, data
processing — must first be saved as a tracked program in this repo, then that
file is executed. Inline shell snippets are forbidden.

## The three location tests (all must hold)

1. **Persistent** — no `/tmp`, no session scratchpad, no `mktemp`, no path with
   a session id or timestamp. The path must resolve next month on a fresh boot.
2. **Project-adjacent** — `<repo-root>/scripts/AUTO-<name>.sh`, beside the thing
   it acts on. Finding the project must mean finding the tooling.
3. **Marked** — the `AUTO-` prefix declares machine authorship. Never strip it.

## Mandatory header (sections, right after the shebang)

WHAT / WHY / INPUTS (every arg, flag, env var with defaults) / OUTPUTS & SIDE
EFFECTS (incl. exit codes) / USAGE-combinatorial (every meaningful flag
combination, including known-invalid ones) / RE-RUN SAFETY (idempotent or not,
what a second run does). If behavior changes, the header changes in the same edit.

## Sanctioned inline exceptions (the full list)

- Reading files: `ls`, `cat`, `head`, `tail`, `wc`, `stat`, `grep`/`rg`,
  `find` (no `-exec`/`-delete`), `diff`.
- Read-only git: `status`, `log`, `diff`, `show`, `branch`, `ls-tree`.
- `Edit`/`Write` of files (writing code/docs/scripts is not execution).

Everything else goes through a tracked program.

## Steps

1. Check whether a tracked program already covers the need → reuse it, or
   extend it with a flag (never clone a near-duplicate).
2. Write the program with the full header; parameterize anything that varies.
3. Execute only the program path + args — nothing else in the shell call.
4. Emit the TRACKED RUN report (below).
5. Never delete or gitignore the program afterwards. Logs derive from the
   program's own location (`scripts/logs/<ts>/`), never scratch dirs.

## Report format (per governed execution)

```
TRACKED RUN
  program:  scripts/AUTO-<name>.sh
  created:  new | reused | extended (+--flag)
  invoked:  ./scripts/AUTO-<name>.sh <args>
  exit:     <code>
  reproduce: same line, any checkout of <sha-or-branch>
```

## Programs in this repo (created for the reading-stats feature)

- `scripts/AUTO-build-sioyek.sh` — qmake (if needed) + `make -jN` + package
  into `build/` + `--version` smoke. Flags: `-j N`, `--configure`,
  `--skip-package`, `--skip-smoke`.
- `scripts/AUTO-git-feature.sh` — `start <branch> [base]` and
  `commit <subject> <body> <path...>`; the only git mutation path on a feature
  branch. Body is mandatory so every commit carries its rationale.
- `scripts/AUTO-verify-reading-stats-e2e.sh` — launches the packaged app,
  drives page turns via `--execute-command next_page`, runs `reading_stats`,
  quits, and proves the result with read-only sqlite3 queries + CSV check.

## Failure modes observed

- `xdotool search --name sioyek` matched an unrelated window and stole focus;
  search by `--pid` of the launched process and re-verify with
  `getactivewindow` (see commit 9139ce8).
- Editing a script while a run of it is in flight can corrupt execution —
  bash reads scripts incrementally. Let the run finish first.
