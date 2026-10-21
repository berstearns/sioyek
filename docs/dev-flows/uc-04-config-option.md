# UC-04: "I want to add a config option"

A new knob in `prefs.config` that users can override in `prefs_user.config`.

## 0. Locate the seam

```
Storage        a global in config.cpp (e.g. float PERSISTANCE_PERIOD = -1.0f;
               config.cpp:30)
Parsing        ConfigManager registration, e.g.
               add_float(L"persistance_period", &PERSISTANCE_PERIOD, extras)
               (config.cpp:962) — pick add_float/add_int/add_bool/add_string
               to match the type
Consumption    extern declaration in each .cpp that reads it
               (main_widget.cpp:118+ is the canonical block)
Defaults       pdf_viewer/prefs.config (shipped default + comment)
Docs           data/config_docs.json if the option is user-facing
```

## 1. Choose the flow direction

**Semantics-first (a)** and tiny: name, type, default, valid range, and the
behavioral difference between default and non-default. If you can't state the
behavioral difference, the option shouldn't exist yet (YAGNI).

## 2. The cascade

```
wish
 → SEMANTICS: name, type, default, range, who reads it, what changes
 → branch: feature/config-<name>
 → COMMIT CHAIN:
     1. "Add <name> config option"             (global + parser + prefs.config
        default + extern where consumed — one mechanical unit, builds)
     2. "Use <name> in <behavior>"             (the behavior change that reads
        it — separate commit: config plumbing vs behavior)
     3. "Verify <name> end-to-end"             (evidence in body)
 → PROOF (see §3)
 → REPORT
```

The split between commit 1 and 2 is the refactor-vs-behavior rule: commit 1 is
behavior-neutral (nothing reads the value differently yet), commit 2 changes
what the app does.

## 3. Proof for this use case

- Default run: build + smoke, behavior unchanged.
- Override run: write the override into a scratch `prefs_user.config` *pointed
  to by the test harness* (or the real user config path the app prints at
  startup: `~/.config/sioyek/prefs_user.config`), launch via tracked script,
  observe the changed behavior via the UC-appropriate proof.
- Both states must be observed — a config option proven only at its default
  is unproven.

## 4. Pitfalls

- Config read order: default prefs first, then user prefs override — match
  `persistance_period`'s extras pattern for clamping.
- The option is read at startup in most cases; runtime reload is a separate,
  larger feature — don't imply it.
- Don't ship a user-specific value in `prefs.config`; that file is the
  factory default.
