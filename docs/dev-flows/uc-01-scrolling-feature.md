# UC-01: "I want to add X in the scrolling part"

Scrolling, panning, smooth-scroll speed, wheel behavior, page flips driven by
scroll, kinetic flick in touch mode.

## 0. Locate the seam

```
Input event      MainWidget                    DocumentView
─────────────    ──────────────────────────    ─────────────────────────────
wheelEvent    →  wheelEvent()            →     move_vertical(amount)
(main_widget.cpp:3449)   move_vertical()       DocumentView::move() /
                         (main_widget.cpp:4392)        set_offset_y()
smooth scroll    smooth_scroll_mode /          get_center_page_number()
speed ramp       smooth_scroll_speed           (document_view.cpp:705)
                 (main_widget.h:288)
timer-driven     validation_interval_timer set to 16ms while smooth-scrolling,
scrolling        back to INTERVAL_TIME (200ms) when done (main_widget.cpp:6716)
```

Verify before editing: `grep -n "smooth_scroll\|move_vertical\|wheelEvent"
pdf_viewer/main_widget.{h,cpp} pdf_viewer/document_view.{h,cpp}`.

## 1. Choose the flow direction

```
DOMAIN-FIRST (a)                         SPIKE-FIRST (b)
"I know the rule: e.g. scroll speed      "Not sure how it should feel"
ramps exponentially, capped at X"
                                         1. Spike: hack wheelEvent locally,
1. Write the rule as a named policy         build, feel it (no commit)
   (pure function: speed(t, dt))         2. Observe: what config/limits
2. Commit chain: policy → wire into         emerged?
   timer/wheel                           3. Extract policy, THEN cascade
Best for: behavioral rules               Best for: feel/tuning work
```

Both directions end in the same cascade below; (b) only adds an uncommitted
spike step 0.

## 2. The cascade

```
wish
 → SEMANTICS (one paragraph in the commit body or brief: what is a "scroll
   unit", what are the limits, what happens at document start/end)
 → PLAN: commit chain sketched BEFORE branch (see below)
 → branch:  ./scripts/AUTO-git-feature.sh start feature/scroll-<x> development
 → tracked programs first (reuse AUTO-build-sioyek.sh; add
   AUTO-verify-scroll-<x>.sh if the proof needs driving)
 → COMMIT CHAIN (each green via AUTO-build-sioyek.sh before the next):
     1. "Add <name> scroll policy constants/config"     (provider, no caller)
     2. "Add <name> to DocumentView movement"           (pure geometry)
     3. "Wire <name> into wheelEvent/timer"             (first caller)
     4. "Add keys/config binding for <name>"            (optional, own commit)
     5. "Verify <name> end-to-end"                      (evidence in body)
 → PROOF (see §3)
 → REPORT
```

## 3. Proof for this use case

Scrolling is visual, so pair the build gate with an observable:

- Drive via IPC: `--execute-command next_page` / `move_down` etc. from a
  tracked script (pattern: `scripts/AUTO-verify-reading-stats-e2e.sh`).
- Observe position changes: `get_center_page_number()` is queryable through
  the `get_state_json` command with `--wait-for-response`; assert the offset/
  page moved by the expected amount.
- For smoothness claims, record wall-clock deltas between position samples —
  a screenshot proves pixels, not motion.

## 4. Pitfalls

- `validation_interval_timer` is dual-purpose (200 ms idle / 16 ms smooth
  scroll). Anything you add to its lambda runs at BOTH rates — cheap checks
  only (see how `track_reading_time()` was added: O(1), no allocation).
- Wheel events carry pixel + angle deltas; num_repeats scaling already exists
  at main_widget.cpp:3550 — reuse it, don't add a second multiplier.
- Page boundaries: commit 78b94e2 (base of this branch) fixed out-of-bounds
  next/previous page — respect the clamp pattern, don't bypass it.
