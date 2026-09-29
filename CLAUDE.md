# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This directory holds shared dev tooling: `serial_monitor.html` and `usb_ports.sh`. The parent `../CLAUDE.md` describes what they do and the wider repo layout; this file covers how they're built.

`usb_ports.sh` is a standalone bash script with no dependencies. It is read-only: it walks `/sys/bus/usb/devices`, never opens a serial port, and classifies devices by vendor ID (bridge chips: `1a86`, `10c4`, `0403`, `067b`) and interface class (`02` = CDC-ACM). To add a bridge vendor, extend the first `case` pattern. The rest of this file is about `serial_monitor.html`.

## Running / testing

There is no build, package manager, linter or test suite. Don't try to test on Android: Chrome 153 on the user's phone listed no USB serial device (S3, P4, Pico W, Uno WiFi) on this page or on esptool-js, so it isn't a page bug. Open `serial_monitor.html` directly in desktop Chrome or Edge (`file://`). Web Serial only works there, so anything touching `connect()`/`readLoop()` needs a real board on USB. To exercise the parser, charts, library or import/export without hardware, use the Library tab with a JSON session file. Its shape is described below.

## Architecture (serial_monitor.html)

The file is a single page with inline CSS and one `<script>` IIFE, and no external dependencies. Charts are hand-drawn on `<canvas>`; don't add a charting library or a build step.

**Data flow.** Serial bytes go through `readLoop()`, which pipes them through `TextDecoderStream` and `LineBreakTransformer` to give one line at a time. Each line goes to `handleIncomingLine()`, which logs it and, if recording, calls `addSample()`. That calls `parseLine()`, which extracts numeric fields, and pushes `{t, raw, fields}` onto the session.

**Two live states.** After Connect, the app is idle: `liveSession === null`, and lines are only logged (a preview). Start creates a `liveSession` and begins sampling. Stop and Disconnect both go through `finalizeRecording()`, which sets `closedAt`. `resetLiveUi()` and `enterIdleState()` reset per-recording UI state and deliberately leave the raw log alone. Keep that distinction when changing the live tab.

**Line parser (`parseLine`).**
- Either flat single-line JSON, or `KV_RE` matches for `label: value`, `label -> value` or `label=value` (with `|` splitting segments).
- A label must start with a letter or underscore. A bare `temp 23` is not detected.
- Keys are lowercased for storage; the original casing is kept in `fieldDisplayNames`.
- Duplicate labels within one line become `label_2`, `label_3`, and so on.
- Fields are discovered as they first appear. `fieldOrder` grows during the session, and the checklist and colors are assigned lazily via `assignColor()` (`PALETTE` cycles).

**Session object** (this is also the persisted and exported JSON format):
`{id, name, projectLabel, baudRate, createdAt, updatedAt, closedAt, fieldOrder[], fieldDisplayNames{}, samples[{t, raw, fields{normKey: number}}]}`
- `t` is epoch ms.
- Import (`importInput` handler) only checks that `samples` and `fieldOrder` are arrays. It always assigns a fresh `id`, so importing never overwrites an existing session.
- Changing this shape means updating export (CSV and JSON), import, `getAllSessionsMeta()` and the library viewer together. Adding IndexedDB stores or indexes requires bumping `DB_VERSION` so `onupgradeneeded` runs.

**Persistence.**
- Sessions live in IndexedDB (`serial_monitor_db` / store `sessions`, keyPath `id`).
- The live session is autosaved every 5s when dirty, and also every 50 samples and on `beforeunload`.
- Only `serial_monitor_last_project_label` is kept in `localStorage`.

**Charting.**
- `drawChart()` is shared by three canvases: live, full-session and library viewer. Each is registered through `registerChart()` with a draw closure, so `redrawChart()` and the window `resize` handler cover all of them.
- `mode: 'live'` shows the last `liveWindow` (300) samples, indexed by position.
- `mode: 'full'` downsamples by stride and places points by timestamp.
- `normalize` scales each series 0–1 independently.
- If a redraw is skipped after showing or hiding a panel (see `switchTab`), the canvas is sized 0 and looks blank.

**Conventions to preserve.**
- Anything derived from serial data or user input that goes into `innerHTML` must go through `escapeHtml()`. Raw device output is untrusted.
- The library uses native `prompt()`/`confirm()` for rename and delete. This blocks browser-automation tooling (Claude in Chrome), so warn before triggering those buttons.
- The raw log keeps at most 400 lines (`logLine`/`logDivider`). Data lines are prefixed with the delta since the previous data line, tracked in the module-level `lastLogTime`.
