# UC-05: "I want to change how pages render" (OpenGL / shaders)

Page rendering, highlight/annotation drawing, custom colors, dark mode,
anything in the GL pipeline.

## 0. Locate the seam

```
GL widget        pdf_view_opengl_widget.{h,cpp} — paint, buffers, draw calls
Shaders          pdf_viewer/shaders/*.frag/.vert — COPIED into build/shaders/
                 by the packaging step (AUTO-build-sioyek.sh); editing the
                 source without repackaging tests nothing
Renderer         pdf_renderer.{h,cpp} — mupdf → pixmap side (CPU)
Config colors    extern color globals (config.cpp) read by the GL widget
Proof surface    ScreenshotCommand (registered in CommandManager) — renders
                 to a file you can diff/assert on
```

## 1. Choose the flow direction

```
DOMAIN-FIRST (a)                         SPIKE-FIRST (b)
Color math, blending rules,              Visual tuning: spike the shader,
deterministic transforms                 look at it, then extract
```

For (b) the spike is legitimate (you can't reason your way to "looks right"),
but it stays uncommitted; the committed chain still starts with the extracted,
named rule.

## 2. The cascade

```
wish
 → SEMANTICS: the transform as a function (inputs: page pixmap, config
   colors, zoom; output: pixels) — shaders are pure functions, write the math
   in the commit body
 → branch: feature/render-<name>
 → COMMIT CHAIN:
     1. "Add <name> shader"                    (new file, unwired — builds)
     2. "Wire <name> into the GL widget"       (uniforms, draw path)
     3. "Add config for <name>"                (UC-04 cascade, if tunable)
     4. "Verify <name> end-to-end"             (screenshot evidence)
 → PROOF (see §3)
 → REPORT
```

A file-add and its wiring are separate commits (move/add ≠ modify rule).

## 3. Proof for this use case

- Package first: the app loads shaders from `build/shaders/` — run the full
  `./scripts/AUTO-build-sioyek.sh` (not --skip-package) or the shader change
  silently isn't loaded.
- Launch on a known PDF via tracked script, invoke the screenshot command via
  IPC, assert the PNG exists and (for strong proof) diff a pixel region
  against an expected value or the pre-change screenshot.
- GL crashes are often startup-time; the smoke step (`--version`) does NOT
  cover GL — the e2e launch does. Never call a shader change green on
  compile alone.

## 4. Pitfalls

- Stale `build/shaders/` masking your edit (packaging copies; it doesn't sync
  deletions — the build script recreates the dir for exactly this reason).
- sioyek renders text as distance fields; changing the page fragment shader
  can silently degrade text — screenshot a text page, not just graphics.
- High-DPI: verify on the actual display scale, offsets are in device pixels
  in parts of the GL path.
