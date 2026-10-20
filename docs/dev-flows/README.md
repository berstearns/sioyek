# Dev Flows — combinatorial, hyper-granular development

This directory documents the granular development flows used to build features
in this repository under the AUTO- worker discipline. Each file is one flow:
what it is, when to use it, its ordered steps, and its gates.

The flows were applied end-to-end on branch `feature/reading-time-tracking`
(see `reading-stats-worked-example.md` for the concrete run, commit chain, and
evidence).

## Index

| Flow | File | Use when |
|---|---|---|
| Tracked-program execution | `tracked-program-execution.md` | Any command that builds, mutates, or verifies — always |
| Combinatorial commit chain | `combinatorial-commit-chain.md` | Any nontrivial change landing as git history |
| Feature branch end-to-end | `feature-branch-end-to-end.md` | A whole feature, from plan to verified branch |

## Governing rule sources (external)

- `/home/b/p/all-my-tiny-projects/claude-rules/auto-rules/from-me/every-command-is-a-tracked-local-program-never-an-inline-snippet.md`
- `/home/b/p/all-my-tiny-projects/claude-rules/auto-rules/combinatorial-commits/` (`_OVERVIEW.md` + all rule files)
- `/home/b/p/all-my-tiny-projects/claude-rules/auto-rules/feature-branch-end-to-end/` (`_OVERVIEW.md` + p1–p6)

## One-line contract

> Every execution is a tracked `scripts/AUTO-*.sh` program; every commit is a
> small, green, independently reviewable save point; every feature ends with
> observed end-to-end evidence, not a claim.
