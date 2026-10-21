# UC-07: "I want to add a menu / overlay / selector widget"

Fuzzy selectors, lists, tables, on-screen menus, prompts.

## 0. Locate the seam

```
Widget classes   ui.h — FilteredSelectWidget / FilteredSelectTableWindowClass
                 (templated on the item type), Touch* widgets for touch mode
Helper           set_filtered_select_menu<T>(main_widget, fuzzy, multiline,
                 columns, values, selected_index, on_select, on_delete, ...)
                 (main_widget.cpp:327 area) — the canonical way to push one
Stack            push/pop via pop_current_widget(); widgets stack over the
                 document view
Data source      whatever vector<T> you pass; strings render as-is, custom
                 types need their column mapping (see Highlight / BookState
                 instantiations)
```

## 1. Choose the flow direction

**App-first (b) is natural here**: the widget framework already exists, so the
"use case" is the data source + the on_select/on_delete callbacks. Write those
first (what shows, what happens on select/delete/edit), and the widget is
assembly. If a genuinely new widget *kind* is needed, switch to (a): its
contract (selection model, key handling, empty state) before its pixels.

## 2. The cascade

```
wish
 → SEMANTICS: item type, columns, select/delete/edit actions, empty-list
   behavior, fuzzy on/off
 → branch: feature/widget-<name>
 → COMMIT CHAIN:
     1. "Add <name> data source"          (the vector<T> producer; builds,
        pure, reviewable alone)
     2. "Add <name> selector widget"      (set_filtered_select_menu wiring +
        callbacks)
     3. "Add <name> command"              (UC-02 cascade to open it)
     4. "Verify <name> end-to-end"
 → PROOF (see §3)
 → REPORT
```

## 3. Proof for this use case

- Open via IPC command, then drive: `xdotool type` into the fuzzy filter,
  `key Return` to select; assert the on_select effect out-of-band (state
  json / db / file).
- Empty-list case: run against a document/profile with no items — the widget
  must open and dismiss cleanly.

## 4. Pitfalls

- Lifetime: callbacks fire after the widget is popped; capture by value or
  honor the existing `main_widget` capture pattern — don't capture locals by
  reference.
- The templated classes instantiate per T; a new T means reviewing the
  column-mapping code path for that type (compiler will force most of it).
- Touch mode has parallel Touch* widgets — if the feature must work in
  TOUCH_MODE, that's a second wiring commit, not a rider.
