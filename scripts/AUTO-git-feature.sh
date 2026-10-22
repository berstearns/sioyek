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
#            publish <remote> <upstream-owner/repo> <branch...>
#                                    fork <upstream-owner/repo> on GitHub into
#                                    the authenticated gh account (idempotent,
#                                    --clone=false), point <remote> at the fork,
#                                    and `git push -u <remote>` each <branch>;
#                                    fork network shares objects so only new
#                                    commits are uploaded
# OUTPUTS: mutates git state (branch creation, commits, remotes, pushes) and
#          GitHub state (fork creation on `publish`); prints the commands it
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
#   ./scripts/AUTO-git-feature.sh publish mine ahrm/sioyek development feature/reading-time-tracking
#       # fork ahrm/sioyek to your account if needed, add remote `mine`, push both branches
# RE-RUN SAFETY: `start` fails (non-destructively) if the branch already exists;
#          `commit` is naturally one-shot — a second run with the same paths
#          fails with "nothing to commit"; `publish` is idempotent — gh repo
#          fork reuses an existing fork, an existing remote is kept (its URL is
#          verified against the fork), pushed branches just fast-forward.
#          No destructive git ops are used.
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
    publish)
        [ $# -ge 3 ] || { echo "usage: $0 publish <remote> <upstream-owner/repo> <branch...>" >&2; exit 64; }
        REMOTE="$1"; UPSTREAM="$2"; shift 2
        GH_USER="$(gh api user --jq .login)"
        FORK="$GH_USER/$(basename "$UPSTREAM")"
        FORK_URL="https://github.com/$FORK.git"
        if ! gh repo view "$FORK" >/dev/null 2>&1; then
            echo "+ gh repo fork $UPSTREAM --clone=false"
            gh repo fork "$UPSTREAM" --clone=false
        else
            echo "fork $FORK already exists; reusing"
        fi
        if git remote get-url "$REMOTE" >/dev/null 2>&1; then
            EXISTING="$(git remote get-url "$REMOTE")"
            [ "$EXISTING" = "$FORK_URL" ] || { echo "error: remote '$REMOTE' exists with unexpected URL $EXISTING (want $FORK_URL)" >&2; exit 1; }
            echo "remote '$REMOTE' already points at $FORK_URL"
        else
            echo "+ git remote add $REMOTE $FORK_URL"
            git remote add "$REMOTE" "$FORK_URL"
        fi
        for BRANCH in "$@"; do
            echo "+ git push -u $REMOTE $BRANCH"
            git push -u "$REMOTE" "$BRANCH"
        done
        ;;
    *)
        echo "usage error: unknown subcommand '$SUB' (want start|commit|publish)" >&2
        exit 64 ;;
esac
