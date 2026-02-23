# Shear

> Find unused files, dependencies, and exports in your Dart & Flutter projects.

[English](README.md) | [日本語](README.ja.md)

---

## Features

- **Unused file detection** — Finds Dart files unreachable from any entry point using graph-based reachability analysis
- **Unused dependency detection** — Identifies packages declared in `pubspec.yaml` but never imported, with transitive dependency awareness
- **Unused export detection** — Spots exported symbols (classes, functions, etc.) that no other file imports, with conditional import support
- **Auto-delete** — Remove detected unused files, dependencies, and exports with `shear delete`
- **Zero-config** — Smart defaults for both pure Dart and Flutter projects
- **Plugin system** — Auto-detects Flutter and `build_runner` for framework-aware analysis
- **Configurable** — Fine-tune with `shear.yaml` (entry points, ignore patterns, severity rules)
- **Multiple reporters** — Console, JSON, or interactive HTML dashboard with charts and filtering
- **CI-ready** — Non-zero exit codes and `--strict` mode for pipeline integration

## Quick Start

```bash
# Install
dart pub global activate shear

# Run in your project
shear analyze
```

That's it. Shear auto-detects your project type and applies sensible defaults.

To generate a config file for customization:

```bash
shear init
```

## Installation

### Global activation (recommended)

```bash
dart pub global activate shear
```

### As a dev dependency

```yaml
# pubspec.yaml
dev_dependencies:
  shear: ^0.1.0
```

Then run with:

```bash
dart run shear analyze
```

### From Git

```yaml
# pubspec.yaml
dev_dependencies:
  shear:
    git:
      url: https://github.com/akaboshinit/shear.git
```

## Usage

```bash
shear [global options] <command> [options]
```

### Commands

| Command | Description |
|---|---|
| `analyze` | Analyze the project for unused code |
| `delete` | Delete detected unused code from the project |
| `init` | Generate a `shear.yaml` config file with project defaults |

### Global Options

| Option | Description | Default |
|---|---|---|
| `-d, --directory <path>` | Project root directory | `.` (current directory) |

### Init Command

Generate a `shear.yaml` config file with auto-detected project defaults.

```bash
shear init [options]
```

| Option | Description | Default |
|---|---|---|
| `-f, --force` | Overwrite existing config file | `false` |

```bash
# Generate default config
shear init

# Overwrite existing config
shear init --force

# Generate for a specific project
shear -d /path/to/project init
```

Shear detects your project type (pure Dart or Flutter) and `build_runner` usage, then generates a fully commented `shear.yaml` with appropriate defaults.

### Delete Command

Remove detected unused code from your project. Uses the same analysis pipeline as `analyze`, then deletes the identified issues.

```bash
shear delete [options]
```

| Option | Description | Default |
|---|---|---|
| `--include <type>` | Categories to delete: `files`, `dependencies`, `exports` | all |
| `--dry-run` | Preview changes without modifying files | `false` |
| `--force` | Skip confirmation prompt | `false` |
| `--verbose` | Show detailed output | `false` |

```bash
# Preview what would be deleted
shear delete --dry-run

# Delete all unused code (with confirmation prompt)
shear delete

# Delete without confirmation
shear delete --force

# Only delete unused files
shear delete --include files

# Only remove unused dependencies
shear delete --include dependencies

# Delete from a specific project
shear -d /path/to/project delete --force
```

#### What gets deleted

- **Unused files** — Removes `.dart` files and their associated `part` files
- **Unused dependencies** — Removes entries from `pubspec.yaml` (preserves comments and formatting)
- **Unused exports** — Removes symbol declarations (classes, functions, variables, enums, mixins, typedefs) from source files using AST-based parsing

#### Output Example

```
$ shear delete --dry-run

Planned deletions:

  Files (1):
    - lib/src/unused_helper.dart

  Dependencies (2):
    - http (dependencies)
    - mockito (dev_dependencies)

(dry-run mode — no changes made)
```

```
$ shear delete --force

Planned deletions:
  ...

Deletion complete:
  1 file(s) deleted
  2 dependency(ies) removed
```

### Analyze Options

| Option | Description | Default |
|---|---|---|
| `--include <type>` | Issue types to check: `files`, `dependencies`, `exports` | all |
| `-r, --reporter <format>` | Output format: `console`, `json`, `html` | `console` |
| `-o, --output <path>` | Write report to a file instead of stdout | — |
| `--strict` | Treat warnings as errors (non-zero exit code) | `false` |
| `--verbose` | Show detailed analysis information | `false` |

### Examples

```bash
# Analyze current directory
shear analyze

# Analyze a specific project
shear -d /path/to/project analyze

# Only check unused files and dependencies
shear analyze --include files --include dependencies

# JSON output for tooling
shear analyze --reporter json

# Strict mode for CI (fail on warnings too)
shear analyze --strict

# Verbose output for debugging
shear analyze --verbose

# HTML dashboard report
shear analyze -r html -o report.html
```

## Output Example

```
$ shear analyze

Unused files (2)
  lib/src/unused_helper.dart
  lib/src/deprecated_util.dart

Unused dependencies (1)
  http

Unused exports (3)
  OldModel       lib/src/models.dart
  legacyParser   lib/src/parser.dart
  DEPRECATED_KEY lib/src/constants.dart

Summary: 6 issues (3 errors, 3 warnings)
```

### JSON Output

```bash
$ shear analyze --reporter json
```

```json
{
  "version": "0.1.0",
  "issues": [
    {
      "type": "unusedFile",
      "severity": "error",
      "filePath": "lib/src/unused_helper.dart",
      "message": "Unused file: not imported from any entry point"
    }
  ],
  "summary": {
    "total": 1,
    "errors": 1,
    "warnings": 0,
    "byType": {
      "unusedFile": 1,
      "unusedDependency": 0,
      "unusedExport": 0
    }
  }
}
```

### HTML Dashboard

```bash
$ shear analyze -r html -o report.html
```

Generates a self-contained HTML file with:

- **Health Score** — Donut chart (0–100) based on error/warning counts
- **Summary Cards** — Total issues, errors, and warnings at a glance
- **Category Cards** — Breakdown by type (files, dependencies, exports)
- **SVG Charts** — Type distribution donut chart and severity bar chart
- **Interactive Filters** — Search by file path/symbol, filter by severity and type
- **Dark Mode** — Automatic via `prefers-color-scheme`

No external dependencies — open the HTML file in any browser.

## Configuration

Create a `shear.yaml` (or `shear.yml`, `.shear.yaml`, `.shear.yml`) in your project root. You can generate one with `shear init`:

```yaml
# Entry point files — analysis starts from these files
entry:
  - bin/*.dart
  - lib/main.dart
  - test/**_test.dart

# Project scope — only these files are analyzed
project:
  - lib/**.dart
  - bin/**.dart
  - test/**.dart

# Files to ignore
ignore:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/*.mocks.dart"

# Dependencies to treat as implicitly used
ignoreDependencies:
  - intl
  - flutter_gen

# Severity rules: error | warn | off
rules:
  unusedFiles: error
  unusedDependencies: error
  unusedExports: warn

# Whether to check exports from entry point files
includeEntryExports: false

# Plugin configuration
plugins:
  flutter: true
  build_runner: true
```

### Default Configuration

Shear provides smart defaults based on your project type. You only need a config file to override specific settings.

#### Pure Dart Projects

| Setting | Default |
|---|---|
| Entry points | `bin/*.dart`, `lib/{package}.dart`, `test/**_test.dart`, `example/**.dart` |
| Project scope | `lib/**.dart`, `bin/**.dart`, `test/**.dart`, `example/**.dart` |
| Ignored patterns | `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `*.gr.dart`, `*.config.dart`, `*.chopper.dart` |

#### Flutter Projects

All pure Dart defaults, plus:

| Setting | Additional defaults |
|---|---|
| Entry points | `lib/main.dart`, `integration_test/**_test.dart` |
| Project scope | `integration_test/**.dart` |
| Implicit dependencies | `flutter`, `flutter_localizations`, `flutter_web_plugins` |

## Detection Types

### Unused Files

Finds Dart files that are **not reachable** from any entry point.

Shear builds a dependency graph of your project and performs breadth-first traversal from entry points. Any file not visited is reported as unused.

- Severity: **error** (default)
- Respects `part` / `part of` relationships
- Entry points are never reported as unused

### Unused Dependencies

Finds packages declared in `pubspec.yaml` that are **never imported** by any file.

- Severity: **error** (default)
- **Transitive dependency awareness** — Packages transitively required by used packages are not falsely reported. Resolution strategies (in priority order):
  1. `.dart_tool/package_graph.json` (`build_runner`)
  2. `.dart_tool/package_config.json` (standard Dart tooling)
  3. Path dependency walking (fallback)
- Framework-implicit packages (e.g., `flutter`) are automatically excluded
- Dev dependencies are not checked (test runners etc. cause false positives)

### Unused Exports

Finds publicly exported symbols (classes, functions, variables, typedefs, mixins, enums, extensions) that are **never imported** by other files.

- Severity: **warning** (default)
- Uses `show` / `hide` directive analysis for precise detection
- **AST-based identifier collection** — For bare imports (no `show`/`hide`), walks the importer's AST to determine which symbols are actually referenced
- **Conditional import support** — Symbols in platform-specific targets (e.g., `if (dart.library.html)`) are correctly recognized as used
- Transitive re-exports via `export` directives are tracked
- Entry point exports are excluded by default (configurable via `includeEntryExports`)

## Plugins

Plugins adapt Shear's behavior for specific frameworks. They are **auto-detected** by default.

### Flutter Plugin

Activated when `flutter` is found in `pubspec.yaml` dependencies.

- Adds `lib/main.dart` and `integration_test/**_test.dart` as entry points
- Ignores platform-specific directories (`ios/`, `android/`, `web/`, etc.)
- Marks `flutter`, `flutter_localizations`, `flutter_web_plugins` as implicitly used

### build_runner Plugin

Activated when `build_runner` is found in dev dependencies.

- Ignores generated files (`*.g.dart`, `*.freezed.dart`, `*.config.dart`, etc.)

### Disabling Plugins

```yaml
# shear.yaml
plugins:
  flutter: false
  build_runner: false
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Shear Analysis
on: [push, pull_request]

jobs:
  shear:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - name: Install dependencies
        run: dart pub get

      - name: Install Shear
        run: dart pub global activate shear

      - name: Run Shear
        run: shear analyze --strict
```

### JSON Report in CI

```yaml
      - name: Run Shear (JSON)
        run: shear analyze -r json -o shear-report.json

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: shear-report
          path: shear-report.json
```

### HTML Report in CI

```yaml
      - name: Run Shear (HTML)
        run: shear analyze -r html -o shear-report.html

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: shear-html-report
          path: shear-report.html
```

## Benchmark

Shear includes a built-in performance benchmark script to measure analysis pipeline performance phase by phase.

### Running Benchmarks

```bash
dart run benchmark/performance_test.dart [options]
```

| Option | Description | Default |
|---|---|---|
| `--target=<dir>` | Target project directory | `.` |
| `--runs=<n>` | Number of measurement runs (min: 3) | `5` |
| `--warmup=<n>` | Number of warmup runs (excluded from stats) | `1` |
| `--all-fixtures` | Also benchmark all `test/fixtures/*` projects | `false` |
| `--json` | Output results as JSON | `false` |
| `-v, --verbose` | Show individual run results | `false` |
| `-h, --help` | Show usage | — |

### Measurement Phases

The benchmark measures each phase of the analysis pipeline independently:

| Phase | Description |
|---|---|
| `config` | Configuration loading (`ConfigLoader.load()`) |
| `plugin` | Plugin auto-detection and config merging |
| `scan` | Project file scanning (`ProjectScanner.scanProjectFiles()`) |
| `parse` * | Isolated `FileParser.parse()` loop (reference only) |
| `graph` | Graph building including file parsing (`GraphBuilder.build()`) |
| `entry` | Entry point resolution (`EntryResolver.resolve()`) |
| `fileDetect` | Unused file detection |
| `depDetect` | Unused dependency detection |
| `exportDetect` | Unused export detection |

\* `parse` is measured in an isolated pass for profiling purposes. Since `GraphBuilder.build()` internally re-parses all files, `parse` is excluded from WALL TOTAL to avoid double-counting.

### Statistics

Each phase reports: **min**, **avg** (mean), **median**, **p95**, **max**, and **wall%** (percentage of wall-clock total).

Warmup runs are excluded from statistics to avoid JIT cold-start skew.

### Output Example

```
shear benchmark  target=.  runs=5  warmup=1  files=127

Phase            min       avg    median      p95      max   wall%
─────────────────────────────────────────────────────────────────────
config              1ms      1ms      1ms      1ms      1ms     1.7%
plugin              1ms      2ms      2ms      2ms      2ms     2.6%
scan                5ms      7ms      6ms     10ms     10ms     9.9%
[parse*]           25ms     31ms     30ms     36ms     36ms     ----
graph              25ms     30ms     29ms     35ms     35ms    46.6%
entry               3ms      3ms      3ms      3ms      3ms     4.7%
fileDetect          1ms      1ms      1ms      1ms      1ms     1.5%
depDetect           1ms      1ms      1ms      1ms      1ms     1.1%
exportDetect       20ms     21ms     21ms     21ms     21ms    32.9%
─────────────────────────────────────────────────────────────────────
WALL TOTAL         58ms     65ms     62ms     73ms     73ms   100.0%

* [parse] is an isolated measurement; subsumed by [graph].
```

### JSON Output

```bash
dart run benchmark/performance_test.dart --json
```

Returns a structured JSON object with per-phase statistics (`min_us`, `max_us`, `mean_us`, `median_us`, `p95_us` in microseconds), useful for CI tracking and performance regression detection.

## How It Works

```
                    ┌─────────────┐
                    │ shear.yaml  │
                    │  (config)   │
                    └──────┬──────┘
                           │
                           ▼
┌──────────┐    ┌─────────────────────┐    ┌───────────────┐
│  Source   │───▶│    File Parser      │───▶│  Module Graph  │
│  Files   │    │  (AST extraction)   │    │  (dependency   │
└──────────┘    └─────────────────────┘    │   graph)       │
                                           └───────┬───────┘
                                                   │
                           ┌───────────────────────┼───────────────────────┐
                           │                       │                       │
                           ▼                       ▼                       ▼
                  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
                  │  Unused File    │   │  Unused Dep     │   │  Unused Export  │
                  │  Detector       │   │  Detector       │   │  Detector       │
                  └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
                           │                     │                     │
                           └──────────┬──────────┘─────────────────────┘
                                      │
                                      ▼
                             ┌─────────────────┐
                             │    Reporter      │
                             │(console/json/html)│
                             └─────────────────┘
```

1. **Parse** — Each Dart file is parsed into an AST to extract imports, exports, parts, public symbols, and referenced identifiers
2. **Build Graph** — A directed dependency graph is constructed from all import/export relationships
3. **Resolve Entries** — Entry points are determined from configuration, plugins, and `main()` functions
4. **Detect** — Three detectors run independently against the graph to find unused code
5. **Report** — Results are formatted and output with appropriate exit codes
6. **Delete** (optional, via `shear delete`) — Detected issues are converted to delete actions and executed: file removal, pubspec.yaml editing, and AST-based symbol removal

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | No errors (warnings may exist unless `--strict`) |
| `1` | Errors found, or warnings found with `--strict` |

## Requirements

- Dart SDK `>=3.0.0 <4.0.0`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`dart test`)
4. Commit your changes
5. Push to the branch
6. Open a Pull Request

## License

See [LICENSE](LICENSE) for details.
