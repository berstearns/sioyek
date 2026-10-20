#!/usr/bin/env bash
# WHAT:    Tracked git driver for feature-branch work: `start` a feature branch
#          from a base, and `commit` a staged-by-explicit-paths change with a
#          subject + rationale body.
# WHY:     The combinatorial-commits / feature-branch-end-to-end rules forbid
#          loose interactive git; every mutation must be a tracked, re-runnable
#          program so the exact commands that shaped history are recoverable.
# INPUTS:  subcommand:
#            start <branch> [base]   create+checkout <branch> from <base>
#                                    (default base: development); refuses if
#                                    tracked working-tree changes are present
#            commit <subject> <body> <path...>
#                                    `git add -- <path...>` then commit with
#                                    -m subject -m body; body is mandatory so
#                                    every commit carries its rationale
# OUTPUTS: mutates git state (branch creation, commits); prints the command it
#          runs and the resulting `git log -1 --stat`; exit 0 = ok,
#          1 = git failure, 2 = dirty tracked tree on `start`, 64 = usage error.
# USAGE (combinatorial):
#   ./scripts/AUTO-git-feature.sh start feature/reading-time-tracking
#       # branch from development (default base)
#   ./scripts/AUTO-git-feature.sh start feature/x main
#       # branch from an explicit base
#   ./scripts/AUTO-git-feature.sh commit "Add X" "Because Y" pdf_viewer/book.h
#       # stage exactly book.h and commit with subject+body
#   ./scripts/AUTO-git-feature.sh commit "Add X" "Because Y" scripts/AUTO-a.sh scripts/AUTO-b.sh
#       # multi-path commit, still explicit — never `git add -A`
#   ./scripts/AUTO-git-feature.sh commit "only subject" "" file.cpp
#       # INVALID: empty body rejected, exits 64
#   ./scripts/AUTO-git-feature.sh frobnicate
#       # INVALID: unknown subcommand, exits 64
# RE-RUN SAFETY: `start` fails (non-destructively) if the branch already exists;
#          `commit` is naturally one-shot — a second run with the same paths
#          fails with "nothing to commit". No destructive git ops are used.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$REPO_ROOT"

[ $# -ge 1 ] || { echo "usage: $0 start|commit ..." >&2; exit 64; }
SUB="$1"; shift

case "$SUB" in
    start)
        [ $# -ge 1 ] || { echo "usage: $0 start <branch> [base]" >&2; exit 64; }
        BRANCH="$1"; BASE="${2:-development}"
        if [ -n "$(git status --porcelain -uno)" ]; then
            echo "error: tracked working-tree changes present; commit or stash first" >&2
            exit 2
        fi
        git checkout "$BASE"
        git checkout -b "$BRANCH"
        git log -1 --oneline
        ;;
    commit)
        [ $# -ge 3 ] || { echo "usage: $0 commit <subject> <body> <path...>" >&2; exit 64; }
        SUBJECT="$1"; BODY="$2"; shift 2
        [ -n "$BODY" ] || { echo "usage error: commit body (rationale) is mandatory" >&2; exit 64; }
        git add -- "$@"
        git commit -m "$SUBJECT" -m "$BODY"
        git log -1 --stat
        ;;
    *)
        echo "usage error: unknown subcommand '$SUB' (want start|commit)" >&2
        exit 64 ;;
esac
