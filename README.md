# Code Metrics

A native macOS app that analyzes the complexity, maintainability and test coverage of a code base.
Supports **TypeScript, JavaScript and Go** (parsed with [tree-sitter](https://tree-sitter.github.io/)).
Everything runs locally — your code never leaves the machine.

*Русская версия: [README.ru.md](README.ru.md)*

## Features

- **Overview** — files, lines of code, comments, functions, maintainability, complex functions, test coverage and CRAP index at a glance, with color-graded cards and charts.
- **Files / Functions tables** — sortable, filterable, with a row of "?" hints explaining every column; double-click opens the file in your editor.
- **Folders** — directory tree with totals; exclude folders or files from the analysis (right-click). Dependencies and build artifacts (`node_modules`, `dist`, `vendor`, …) are skipped by default.
- **Architecture** — Martin metrics per package with a main-sequence chart, plus WMC / CBO per class.
- **Test coverage** — loads an existing report or runs the tests for you (play link on the *Test coverage* card).
- **Open in editor** — VS Code by default; Cursor, Windsurf, Zed, Sublime Text, WebStorm, IntelliJ IDEA, Xcode or the system default can be chosen in Settings.
- **English / Russian UI** — English by default, switch in Settings (⌘,).
- **CSV export** of per-file metrics (⌘E).

## Metrics

| Metric | Meaning |
|---|---|
| LOC / comments / blank | Line counts from the syntax tree (comment-only lines are not code) |
| **CC** — cyclomatic complexity | 1 + number of branches (`if`, loops, `case`, `catch`, `&&`, `||`, `??`, ternary). ≤ 10 normal, 11–20 elevated, > 20 high |
| **Cog** — cognitive complexity | Like CC, but nesting is penalized. ≤ 15 normal, 16–25 elevated, > 25 high |
| Length, parameters, nesting | Function size, parameter count, maximum nesting depth |
| **MI** — maintainability index | 0–100, Visual Studio formula (lines of code stand in for Halstead volume). ≥ 40 good, 20–40 warning, < 20 bad |
| **Cov** — line coverage | Share of lines executed by tests, per project / file / function |
| **Ca / Ce / I / A / D** (Martin) | Per package (folder): afferent / efferent coupling, instability `Ce/(Ca+Ce)`, abstractness (interfaces + abstract classes / all types), distance from the main sequence `\|A+I−1\|`. Import graph is built from relative imports, `@/…`, `src/…` and Go module paths; test files are excluded |
| **WMC** | Sum of CC of a class's methods (Go: methods of a struct). ≤ 20 normal, > 50 heavy |
| **CBO** (approximate) | Distinct imported modules/types used inside a class — computed from imports, without type resolution. ≤ 9 normal, > 14 high |
| **CRAP** | `CC² × (1 − coverage)³ + CC` — complex *and* poorly tested code. ≤ 5 safe, > 30 "crappy" |

## Test coverage

The app does not measure coverage itself; it reads a report produced by your test run:

| Format | Typical file |
|---|---|
| lcov | `coverage/lcov.info` |
| Istanbul JSON (jest, vitest, nyc, c8) | `coverage/coverage-final.json` |
| Go cover profile | `coverage.out` |

The report is found automatically in the project root, or pick one via **Test coverage → Choose report file…**.

The **play** link on the *Test coverage* card runs, in the project folder (through your login shell, so `node` / `go` from nvm or Homebrew are found):

- Go (`go.mod`): `go test -coverprofile=coverage.out ./...`
- vitest: `npx vitest run --coverage --coverage.reportsDirectory=coverage --coverage.reporter=lcov --coverage.reporter=json`
- otherwise jest: `npx jest --coverage --coverageDirectory=coverage --coverageReporters=lcov --coverageReporters=json`

A progress bar shows how many test files / packages have finished. If it fails, click the red message for details (command, exit code, likely cause, tail of the output). vitest needs `@vitest/coverage-v8` installed. If your project uses another runner, generate the report yourself and choose the file manually. The CRAP card stays inactive until a coverage report is loaded.

## Requirements

- macOS 14 or newer
- Swift 5.9+ toolchain (Xcode Command Line Tools are enough — full Xcode is not required)

## Build & run

```bash
./make-app.sh          # release build → CodeMetrics.app (ad-hoc signed)
open CodeMetrics.app
```

Other targets:

```bash
swift run cmetrics <folder>   # quick CLI report: totals, languages, top complex functions
swift run selftest            # self-checks of the analyzer, scanner and coverage parsers
swift build                   # debug build
```

The app is ad-hoc signed, not notarized: on first launch of a downloaded build use right-click → **Open**.

## Project layout

```
Sources/
  CodeMetricsCore/   scanner, tree-sitter analyzer, metrics models, coverage parsers
  CodeMetricsApp/    SwiftUI app (views, app model, localization, editor settings)
  cmetrics/          command-line report
  selftest/          executable self-tests
Vendor/              vendored tree-sitter-javascript grammar
Resources/           app icon
make-app.sh          builds and packages CodeMetrics.app without Xcode
```

Adding a language means creating a `LanguageSpec` (grammar plus node-type rules) in `Languages.swift` and registering it in `LanguageRegistry`.

## Localization

UI strings go through `tr("…")` in `Sources/CodeMetricsApp/Localization.swift`. The key is the Russian source text; English translations live in the `englishStrings` dictionary.

## Privacy

Files that look sensitive (`.env`, keys, credentials, …) are never read. Analysis and coverage runs happen on your machine only.
