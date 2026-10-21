# Dev Flows — use-case map for combinatorial, hyper-granular development

A map from "I want to add X" to the detailed cascade that lands it: which
seam in the codebase, which flow direction, which commit chain, which proof.

Style follows `/home/b/dev-strategies/` (per-strategy files with (a)
domain-first / (b) app-first variants); the strategies here are adapted to a
Qt/C++ repo with no test suite: the red/green loop is the per-commit build
gate plus an observed end-to-end artifact.

## The map

| Your wish | Use-case file | Seam | Direction |
|---|---|---|---|
| "add X in the scrolling part" | `uc-01-scrolling-feature.md` | wheelEvent / move_vertical / smooth_scroll timer | (a) rules known, (b) if tuning feel |
| "add a new command" | `uc-02-new-command.md` | input.cpp Command class + registration | (a) |
| "track / persist X" | `uc-03-persisted-state.md` | database.cpp + book.h structs | (a), schema-first mandatory |
| "add a config option" | `uc-04-config-option.md` | config.cpp + prefs.config | (a) |
| "change how pages render" | `uc-05-rendering-shader.md` | pdf_view_opengl_widget + shaders/ | (b) spike → extract |
| "change input / keybindings" | `uc-06-input-keybinding.md` | key_event + parse tree | (a) state machine first |
| "add a menu / selector widget" | `uc-07-ui-widget.md` | ui.h + set_filtered_select_menu | (b), framework exists |
| "change document handling" | `uc-08-document-handling.md` | document.cpp (mupdf seam) | (a), strictly |

## The universal cascade (every use case)

```
WISH → SEMANTICS → PLAN → BRANCH → PROGRAMS → COMMIT CHAIN → PROOF → REPORT
```

Details: `conceptual-guide.md`.

## Flow libraries (the reusable machinery each cascade runs on)

- `tracked-program-execution.md` — every execution is a versioned
  `scripts/AUTO-*.sh` program; headers, TRACKED RUN reports.
- `combinatorial-commit-chain.md` — the commit discipline: small green save
  points, provider-before-consumer, imperative subjects, rationale bodies.
- `feature-branch-end-to-end.md` — the branch lifecycle: plan before branch,
  granular commits, machine proof, evidence in the final commit.

## Worked example

`reading-stats-worked-example.md` — the reading-time feature on
`feature/reading-time-tracking`, run through UC-03 + UC-02 with all gates and
the two observed harness mistakes.

## Governing rule sources (external)

- `/home/b/p/all-my-tiny-projects/claude-rules/auto-rules/from-me/every-command-is-a-tracked-local-program-never-an-inline-snippet.md`
- `/home/b/p/all-my-tiny-projects/claude-rules/auto-rules/combinatorial-commits/`
- `/home/b/p/all-my-tiny-projects/claude-rules/auto-rules/feature-branch-end-to-end/`
- `/home/b/dev-strategies/` — strategy idiom these docs adapt

## One-line contract

> Every execution is a tracked `scripts/AUTO-*.sh` program; every commit is a
> small, green, independently reviewable save point; every feature ends with
> observed end-to-end evidence, not a claim.
