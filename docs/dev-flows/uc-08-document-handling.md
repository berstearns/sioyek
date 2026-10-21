# UC-08: "I want to change document handling" (mupdf / Document layer)

Opening/saving documents, page text extraction, annotations, synctex, TOC,
anything that talks to mupdf.

## 0. Locate the seam

```
Document         document.{h,cpp} — Document class wraps fz_document;
                 num_pages(), get_checksum(), page text/index caches
Checksum         CachedChecksummer; get_checksum() (full) vs
                 get_checksum_fast() (optional, cache-only) — know which
                 your feature can tolerate
Manager          DocumentManager — caches Document instances, tab registry
mupdf            mupdf/ submodule — PREBUILT static libs under
                 mupdf/build/release/. Do NOT rebuild or edit it as part of
                 an app feature; mupdf changes are their own project
fz_error         mupdf throws via exceptions/longjmp wrappers — match the
                 try/catch (fz_try) idiom of neighboring Document methods
```

## 1. Choose the flow direction

**Domain-first (a)**, strictly: document-layer work is where corrupt-a-file
bugs live. The "domain" is the Document method contract — inputs (page
numbers 0-based), errors (missing page, encrypted, unloaded), side effects
(disk writes, db writes), and invariants (offsets within page count).

## 2. The cascade

```
wish
 → SEMANTICS: the Document method contract + invariants (page indexing,
   error cases, whether it writes the file)
 → branch: feature/doc-<name>
 → COMMIT CHAIN:
     1. "Add Document::<name>"            (document-layer method; no callers)
     2. "Add <name> plumbing"             (DocumentView / DocumentManager
        exposure, if needed — separate from the app wiring)
     3. "Wire <name> into MainWidget/command"  (UC-02 cascade if a command)
     4. "Verify <name> end-to-end"
 → PROOF (see §3)
 → REPORT
```

## 3. Proof for this use case

- Use real fixture files: `tutorial.pdf` (in repo), plus a generated
  edge-case file if the feature touches malformed/multi-page inputs.
- Read-back proof: if the feature writes the PDF, reopen it (new process,
  tracked script) and assert the written state — a write you didn't re-read
  is unproven.
- Regression smoke on the basics: open, next_page, render, quit — the e2e
  harness pattern covers this.

## 4. Pitfalls

- Page numbers are 0-based internally, 1-based in UI/status — conversions at
  the boundary only (see reading_stats furthest-page display).
- `get_checksum()` can compute a hash of a large file (slow); inside
  per-frame or per-event paths use the fast/cached variant or hoist.
- Document instances are shared across windows (`windows` loop in
  main_widget.cpp) — mutating one affects every window showing it.
- Do not bump the mupdf submodule pointer inside a feature branch; that's a
  separate mechanical commit on its own branch.
