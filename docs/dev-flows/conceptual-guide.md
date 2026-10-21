# Conceptual Guide: the universal cascade

Every use case in this repo — scrolling, commands, persistence, rendering,
input, widgets, document handling — cascades through the same pipeline. The
use-case files (uc-NN) only specialize the seams and the proof.

## The cascade

```
┌─────────────────────────────────────────────────────────────────┐
│ WISH          "I want to add X in the <area> part"              │
│               one sentence, user-visible intent                 │
├─────────────────────────────────────────────────────────────────┤
│ SEMANTICS     what is one unit of the thing? its rules/limits?  │
│               its invariants? written BEFORE code (commit body  │
│               or brief). The domain-first (a) flow writes these │
│               upfront; the spike-first (b) flow discovers them  │
│               in an uncommitted spike and extracts them.        │
├─────────────────────────────────────────────────────────────────┤
│ PLAN          the commit chain sketched before the branch:      │
│               providers → consumers → wiring → proof.           │
├─────────────────────────────────────────────────────────────────┤
│ BRANCH        feature/<name> from green development, via        │
│               scripts/AUTO-git-feature.sh start                 │
├─────────────────────────────────────────────────────────────────┤
│ PROGRAMS      tracked scripts/AUTO-*.sh FIRST: every later gate │
│               (build, e2e) must be a versioned program          │
├─────────────────────────────────────────────────────────────────┤
│ COMMIT CHAIN  i → i+1 save points, each green at its own HEAD   │
│               before the next is stacked (see                   │
│               combinatorial-commit-chain.md)                    │
├─────────────────────────────────────────────────────────────────┤
│ PROOF         observed artifact per use case: sqlite rows, a    │
│               file, a screenshot, a state-json response — never │
│               "it compiled" and never a self-report             │
├─────────────────────────────────────────────────────────────────┤
│ REPORT        branch, git log --oneline, TRACKED RUN blocks,    │
│               evidence, unbound-command binding hints           │
└─────────────────────────────────────────────────────────────────┘
```

## The two entry flows (from dev-strategies, adapted)

This repo has no test suite, so the classic Red→Green becomes
**Gate-Green**: the build gate plus an observed artifact play the red/green
roles. The (a)/(b) direction choice survives intact:

```
(a) SEMANTICS-FIRST                      (b) SPIKE-FIRST
rules known upfront                      rules discovered by building
1. Write the contract/invariants         1. Spike uncommitted, build, feel it
2. Commit chain starts at the provider   2. Extract the named rule
3. Wire consumers                        3. Then the SAME chain as (a)
scrolling rules, persistence,            shader tuning, UI feel
document layer
```

Both converge before the branch: no spike output is ever committed raw.

## Layer ↔ proof correspondence

| Layer touched | Seam (start here) | Proof artifact |
|---|---|---|
| Input (keys/mouse) | key_event / parse_key_config_files | xdotool-driven effect, state json |
| Command surface | input.cpp Command classes | IPC `--execute-command` + out-of-band artifact |
| App behavior | MainWidget methods | status + file/db artifact |
| Persistence | database.cpp, book.h structs | sqlite3 mode=ro queries |
| Document layer | document.cpp | read-back of written file |
| Rendering | pdf_view_opengl_widget, shaders/ | screenshot diff |
| Config | config.cpp + prefs.config | default + override runs both observed |
| UI widgets | ui.h, set_filtered_select_menu | driven selection effect |

## Golden rules (repo-adapted)

1. The build gate is per-commit; the proof is per-feature.
2. Provider lands before consumer — schema before writer before reader.
3. Additive-only to the DB; no migrations, no version bumps.
4. Never commit: artifacts, databases, the brief, run logs.
5. A verifier must be able to fail — watch it fail once (wrong window focus,
   wrong db) before trusting its green.
6. mupdf is prebuilt infrastructure, not part of your feature branch.
7. The spike, if any, is throwaway: its lesson is committed, its code is not.
