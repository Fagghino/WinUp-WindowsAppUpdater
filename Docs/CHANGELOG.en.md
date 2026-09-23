# 📝 Changelog — WinUp — Windows App Updater (English)

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> 🇮🇹 Versione italiana disponibile in [`CHANGELOG.it.md`](CHANGELOG.it.md)

## [Unreleased]

### Added
- Search bar to quickly filter apps in the table.
- System notifications for available updates.
- Exclusion list to skip specific apps from updates.
- CSV/Excel export of app list and update history.
- Full multi-source support (winget + msstore + custom).
- Structured logging with file rotation.

## [2.1.0] - 2026-09-23

### Added
- **Dark theme UI:** Complete visual overhaul with modern dark color palette (`#1E1E2E` base, teal accent `#4ECCA3`).
- **Async update engine:** Streaming `System.Diagnostics.Process` with real-time UI logging — GUI stays responsive during updates.
- **Winget availability check:** Startup now verifies winget is installed and shows a clear error dialog if missing.
- **`config.json` integration:** `wingetSource`, `logLevel`, and `theme` settings read and applied at startup.
- **Status bar:** Bottom status bar showing current state (e.g., "X upgradable apps found").
- **Consistent typography:** Segoe UI font applied across all controls, Consolas in log console.
- **Bilingual documentation:** `README.md` (English) + `Docs/README.it.md` (Italian).
- **Separate changelogs:** `Docs/CHANGELOG.en.md` (English) + `Docs/CHANGELOG.it.md` (Italian).
- **`.gitattributes`:** Added for Git LF/CRLF normalization and Linguist hints.

### Changed
- **Modern button styling:** Replaced flat system colors with styled buttons and category accent colors.
- **`UpdateAppUtils.psm1` optimizations:** Documented as legacy/standalone; `$result +=` arrays replaced with generic `List[PSCustomObject]` for O(n) performance.
- **Regex parsing safety:** Header and separator lines explicitly skipped in `Get-UpgradableApps` to prevent false positives.
- **README documentation:** Rewritten in English, removed duplicate sections and obsolete cache claims.

### Fixed
- **Startup data duplication:** `Get-UpgradableApps` now called once after UI render and reused on refresh.
- **Array-to-string log output:** Fixed `$output` array string concatenation bug using proper newline join.
- **Redundant layout loop:** Removed ineffective AutoSizeMode loop in DataGridView setup.
- **Unreachable code in module:** Removed unreachable `return @()` after `finally` block in `UpdateAppUtils.psm1`.
- **PowerShell runspace isolation:** Replaced `BackgroundWorker` with timer-based UI initialization and process events to ensure thread safety in PowerShell.

## [2.0.0] - 2025-11-01

### Added
- **Tabular interface:** `DataGridView` replaces legacy `CheckedListBox`.
- **Data columns:** Select, Name, ID, Current Version, and Available Version.
- **Auto-sizing columns:** Width automatically adapts to cell contents.
- **Resizable window:** Minimum size enforcement and maximize support.
- **Interactive splitter:** Dynamic resizing between table and log console.
- **Dock layout:** Responsive layout container resizing.
- **Upgradable-first view:** Startup displays only upgradable applications.
- **Contextual controls:** Checkboxes and action buttons dynamically toggle in read-only mode.

### Changed
- **Version parser:** Corrected parsing logic for `winget list` output.
- **Header localization:** Automatic recognition for Italian and English winget column headers.
- **Column limits:** Positional substring calculation based on header offsets.

### Fixed
- **Window layering:** Removed `$form.Topmost = $true` so window no longer forces always-on-top.
- **All-apps version display:** Fixed missing version info in full installed apps list.
- **Null value handling:** Safe handling for empty cell values in DataGridView.
- **Panel overlap:** Clean docking layout preventing overlapping controls during resize.

## [1.0.0] - 2025-01-01

### Added
- CheckedListBox user interface for selecting packages.
- Installed application listing via `winget list`.
- Multi-selection and batch upgrade execution.
- Real-time logging textbox.
- Basic action buttons (Update, Select All, Deselect All).
- `config.json` configuration file support for source and log level.
- `UpdateAppUtils.psm1` utility helper module.
- Error handling with try/catch blocks.

[Unreleased]: https://github.com/Fagghino/BOT-AGGIORNA-APP/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/Fagghino/BOT-AGGIORNA-APP/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/Fagghino/BOT-AGGIORNA-APP/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/Fagghino/BOT-AGGIORNA-APP/releases/tag/v1.0.0
