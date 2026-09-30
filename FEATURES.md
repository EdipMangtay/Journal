# Platform Feature Checklist

The Mac app's original Swift source is preserved. The Windows application implements the same journal model and screen structure, using the original graphite, mint, amber, red and blue palette. Native fonts, controls and window chrome vary by OS.

| Area | macOS | Windows |
| --- | --- | --- |
| Dashboard | Periods, net PnL, R, expectancy, equity in $/R/%, process outcomes, execution score, heatmap, drawdown, rolling win rate, recent executions and statistics | Same views and calculations |
| Trades | Search, 20 analysis dimensions, date filters, sorting, detail view, edit, delete | Same workflows |
| Execution | Instrument, direction, entry/exit times, prices, size, fees, dollar/percent risk, manual/calculated R, session, setup, grade | All fields |
| Context | HTF bias/alignment, context timeframes, liquidity draw, liquidity taken, valid sweep | All fields |
| Models | QT, MMXM, PO3, SSMT, TSMO, CRT, entry timeframe and confirmations | All model fields and validity checks |
| Process | Plan compliance, built-in and custom broken rules, seven execution scores | Same classifications and grading |
| Reflection | Before/after emotion ratings, emotion tags, eight note fields, tags | All fields |
| Calendar | Month navigation, daily PnL/R, selected-day trades and summary | Same workflows |
| Research | Analytics, Setup Analysis, Statistics, cohort charts/tables, seven comparisons, model combinations, sample labels, monthly discipline, correlation, sessions, heatmap, definitions | Same calculations and views |
| Playbook | Setup CRUD, five rule sections, ideal example images, setup metrics | Same workflows |
| Mistakes | Per-rule counts, results and profitable-mistake warnings | Same calculations |
| Screenshots | PNG/JPEG/HEIC/TIFF, drag/drop, categories, original image preservation, zoom/pan, arrow/rectangle/text/liquidity annotations, undo and expanded viewer | Same workflows; also accepts WebP |
| Reviews | Daily/weekly/monthly live snapshots, date selection, five notes, CRUD | Same workflows |
| Preferences | Account, risk, currency, trading time zone, dark/light/system, animation, sessions/hours, instruments, custom rules | Same saved settings |
| Portability | JSON includes trades/images/annotations/playbooks/reviews/settings; CSV includes complete trade JSON; merge by ID | Version-1 compatible imports and exports |
| Privacy | Local persistent journal, isolated demo, no account or telemetry | Local atomic JSON storage, previous-state backup and isolated demo |

## Evidence

- Native tests exercise analytics, search, CSV, validation, persistence, relationships and backups.
- JavaScript tests compare calculations against a real Swift-generated demo fixture and exercise validation, CSV safety, images, time zones, search and atomic writes.
- The desktop test visits every screen, checks chart pixels, creates and reopens data, edits/cancels, annotates images, restores JSON and checks demo isolation.
- Windows-to-Mac validation restores the desktop-test backup into temporary SwiftData storage and compares every trade and screenshot, including annotations.
- CI installs the actual Windows EXE before running the desktop test. Test screenshots are available in the workflow artifacts.

These checks do not establish that every OS version, physical device, font renderer or enterprise security policy behaves identically. Distribution-signing limitations are documented in INSTALLATION.md.
