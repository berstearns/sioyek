# UC-02: "I want to add a new command"

A new entry in the command palette / IPC surface: `sioyek --execute-command <x>`,
bindable in `keys_user.config`.

## 0. Locate the seam

```
Command class        input.cpp (~3500 command classes; NextPageCommand at 3471
                     is the canonical minimal pattern)
Registration         CommandManager::CommandManager (input.cpp:7198+),
                     register_command<YourCommand>()
Behavior             a MainWidget method (main_widget.{h,cpp}) — the command
                     class is a thin forwarder: widget->do_the_thing()
Binding (optional)   keys.config (defaults — do NOT ship user bindings here
                     unless upstream-worthy); keys_user.config for local use
```

Pattern (minimal command):

```cpp
class YourCommand : public Command {
public:
    static inline const std::string cname = "your_command";
    static inline const std::string hname = "Human description";
    YourCommand(MainWidget* w) : Command(cname, w) {};
    void perform() {
        widget->do_the_thing();
    }
};
```

## 1. Choose the flow direction

Almost always **semantics-first (a)**: a command is a named operation, so the
"domain" step is writing the MainWidget method's contract (preconditions: doc
open?; effect: what changes; observable: status message / db rows / file).

## 2. The cascade

```
wish
 → SEMANTICS: command name, preconditions, effect, observable outcome
 → branch: feature/<command-name>
 → COMMIT CHAIN (each green before the next):
     1. "Add MainWidget::do_the_thing"        (behavior, no caller — builds)
     2. "Add your_command command"            (class + registration: the wiring)
     3. "Verify your_command end-to-end"      (evidence in body)
 → PROOF (see §3)
 → REPORT: include the suggested keys_user.config line, e.g.
   `your_command <C-r>`  (leave the command unbound by default)
```

If the behavior needs new persisted state, chain UC-03 first (schema commit
before the MainWidget method that writes to it). If the command needs helper
programs for its proof, those land as commit 0 (tracked programs first).

## 3. Proof for this use case

Commands are directly drivable over IPC — the cheapest e2e surface in sioyek:

```
./build/sioyek tutorial.pdf &                    # via tracked script, detached
./build/sioyek --execute-command your_command
```

Then observe the effect out-of-band: sqlite3 row (mode=ro), CSV/file on disk,
or `--execute-command get_state_json --wait-for-response` for in-app state.
A status message alone is weak proof — back it with an artifact.

## 4. Pitfalls

- `perform()` runs on the GUI thread; long work blocks rendering. Heavy work
  belongs behind a Qt async pattern already used nearby — match it.
- Check `requires_document`-style guards: if the command is meaningless with
  no document open, handle `!widget->doc()` explicitly (status message, not a
  crash) — see `MainWidget::show_reading_stats`.
- `num_repeats` (`5j`-style counts) is available in the command — honor it if
  the action is repeatable.
- The command classes live in one huge input.cpp; place yours next to its
  semantic neighbors, registration line likewise.

## 5. Worked pointer

Commit `42d1e58` (`reading_stats`) on `feature/reading-time-tracking` is this
exact cascade: MainWidget method → command + registration → e2e via IPC →
CSV + sqlite evidence → unbound-by-default with the binding in the report.
