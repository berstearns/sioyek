# UC-06: "I want to change input handling / keybindings"

Key handling, modifiers, hold-vs-press, mouse gestures, key config parsing.

## 0. Locate the seam

```
Key events       MainWidget::key_event(released, kevent, is_auto_repeat)
                 (main_widget.h:442 area) → InputHandler
Parse tree       parse_key_config_files() (input.cpp:7994) — keys.config +
                 keys_user.config merged into InputParseTreeNode
Dispatch         InputHandler walks the tree; leaf = command name →
                 CommandManager → Command::run (num_repeats honored)
Hold support     Command::is_holdable / on_key_hold (input.cpp:7180 area)
Mouse            handle_left_click / handle_right_click (overload set with
                 shift/control/command/alt) in main_widget.cpp
```

## 1. Choose the flow direction

**Semantics-first (a)**: input is a state machine — write the states and
transitions first (idle → prefix key → count → chord → dispatch; press vs
release vs hold; auto-repeat). Most input bugs are unwritten transitions,
not wrong code.

## 2. The cascade

```
wish
 → SEMANTICS: the transition table (event × state → action). Include the
   sad paths: auto-repeat, release-without-press, modifier released mid-hold.
 → branch: feature/input-<name>
 → COMMIT CHAIN:
     1. "Add <name> to the input parse/dispatch"   (new transition, default
        off or unbound — behavior-neutral)
     2. "Bind <name> in keys.config"               (only if a DEFAULT binding
        is justified; otherwise note keys_user.config line in the report)
     3. "Verify <name> end-to-end"
 → PROOF (see §3)
 → REPORT
```

## 3. Proof for this use case

- Synthetic key events: `xdotool key --window <id> <keysym>` against the
  focused test window, driven from a tracked script (the reading-stats
  verifier shows the pid-scoped focus pattern — reuse it; name-based window
  search is a known focus-stealing failure).
- Observe via IPC `get_state_json --wait-for-response` or the db/file
  artifact of the triggered command.
- Test the sad paths too: auto-repeat (`xdotool key --repeat`), and the
  unbound case (command absent → nothing happens, no crash).

## 4. Pitfalls

- Distinguish press/release/auto-repeat — Qt delivers all three; a handler
  that ignores the flag fires multiple times per physical press.
- Existing bindings: adding a default binding can shadow a user prefix
  (e.g. binding `x` kills `xa`, `xb` chords) — check the parse tree overlap.
- num_repeats (`5j`) flows through the same path; your change must not eat it.
