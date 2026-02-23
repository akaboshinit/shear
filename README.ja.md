# Shear

> Dart & Flutter プロジェクトの未使用ファイル、依存関係、エクスポートを検出。

[English](README.md) | [日本語](README.ja.md)

---

## 特徴

- **未使用ファイル検出** — グラフベースの到達可能性分析により、エントリーポイントから到達不能な Dart ファイルを検出
- **未使用依存関係検出** — `pubspec.yaml` に宣言されているがインポートされていないパッケージを特定（推移的依存関係を考慮）
- **未使用エクスポート検出** — 他のファイルからインポートされていないエクスポートシンボル（クラス、関数など）を発見（conditional import 対応）
- **自動削除** — `shear delete` で検出された未使用ファイル、依存関係、エクスポートを削除
- **設定不要** — 純粋な Dart プロジェクトと Flutter プロジェクトの両方にスマートデフォルトを提供
- **プラグインシステム** — Flutter と `build_runner` を自動検出し、フレームワークに対応した分析を実行
- **柔軟な設定** — `shear.yaml` でエントリーポイント、無視パターン、重大度ルールをカスタマイズ
- **複数の出力形式** — コンソール、JSON、またはグラフ・フィルタリング付きインタラクティブ HTML ダッシュボード
- **CI 対応** — ゼロ以外の終了コードと `--strict` モードでパイプライン統合が容易

## クイックスタート

```bash
# インストール
dart pub global activate shear

# プロジェクトで実行
shear analyze
```

これだけです。Shear はプロジェクトタイプを自動検出し、適切なデフォルト設定を適用します。

設定ファイルを生成してカスタマイズするには：

```bash
shear init
```

## インストール

### グローバルインストール（推奨）

```bash
dart pub global activate shear
```

### dev dependency として追加

```yaml
# pubspec.yaml
dev_dependencies:
  shear: ^0.1.0
```

実行方法：

```bash
dart run shear analyze
```

### Git から直接インストール

```yaml
# pubspec.yaml
dev_dependencies:
  shear:
    git:
      url: https://github.com/akaboshinit/shear.git
```

## 使い方

```bash
shear [グローバルオプション] <コマンド> [オプション]
```

### コマンド

| コマンド | 説明 |
|---|---|
| `analyze` | プロジェクトの未使用コードを分析 |
| `delete` | 検出された未使用コードをプロジェクトから削除 |
| `init` | プロジェクトのデフォルト設定で `shear.yaml` を生成 |

### グローバルオプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `-d, --directory <path>` | プロジェクトのルートディレクトリ | `.`（カレントディレクトリ） |

### init コマンド

プロジェクトタイプを自動検出し、コメント付きのデフォルト `shear.yaml` を生成します。

```bash
shear init [オプション]
```

| オプション | 説明 | デフォルト |
|---|---|---|
| `-f, --force` | 既存の設定ファイルを上書き | `false` |

```bash
# デフォルト設定ファイルを生成
shear init

# 既存ファイルを上書き
shear init --force

# 特定のプロジェクト用に生成
shear -d /path/to/project init
```

Shear はプロジェクトタイプ（純粋な Dart または Flutter）と `build_runner` の使用を検出し、適切なデフォルト値を含むコメント付き `shear.yaml` を生成します。

### delete コマンド

検出された未使用コードをプロジェクトから削除します。`analyze` と同じ分析パイプラインを使用し、検出された問題を実際に削除します。

```bash
shear delete [オプション]
```

| オプション | 説明 | デフォルト |
|---|---|---|
| `--include <type>` | 削除対象のカテゴリ: `files`, `dependencies`, `exports` | すべて |
| `--dry-run` | ファイルを変更せずにプレビュー表示 | `false` |
| `--force` | 確認プロンプトをスキップ | `false` |
| `--verbose` | 詳細な出力を表示 | `false` |

```bash
# 削除対象をプレビュー
shear delete --dry-run

# 未使用コードをすべて削除（確認プロンプトあり）
shear delete

# 確認なしで削除
shear delete --force

# 未使用ファイルのみ削除
shear delete --include files

# 未使用依存関係のみ削除
shear delete --include dependencies

# 特定のプロジェクトで実行
shear -d /path/to/project delete --force
```

#### 削除対象

- **未使用ファイル** — `.dart` ファイルと関連する `part` ファイルを削除
- **未使用依存関係** — `pubspec.yaml` からエントリを削除（コメントとフォーマットを保持）
- **未使用エクスポート** — AST パースによりシンボル宣言（クラス、関数、変数、enum、mixin、typedef）をソースファイルから削除

#### 出力例

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

### analyze オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `--include <type>` | 検出する問題の種類: `files`, `dependencies`, `exports` | すべて |
| `-r, --reporter <format>` | 出力形式: `console`, `json`, `html` | `console` |
| `-o, --output <path>` | レポートをファイルに出力（stdout の代わり） | — |
| `--strict` | 警告もエラーとして扱う（ゼロ以外の終了コード） | `false` |
| `--verbose` | 詳細な分析情報を表示 | `false` |

### 使用例

```bash
# カレントディレクトリを分析
shear analyze

# 特定のプロジェクトを分析
shear -d /path/to/project analyze

# 未使用ファイルと依存関係のみチェック
shear analyze --include files --include dependencies

# ツール連携用の JSON 出力
shear analyze --reporter json

# CI 用 strict モード（警告でも失敗）
shear analyze --strict

# デバッグ用の詳細出力
shear analyze --verbose

# HTML ダッシュボードレポート
shear analyze -r html -o report.html
```

## 出力例

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

### JSON 出力

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

### HTML ダッシュボード

```bash
$ shear analyze -r html -o report.html
```

自己完結型の HTML ファイルを生成します：

- **ヘルススコア** — エラー/警告数に基づくドーナツチャート（0〜100）
- **サマリーカード** — 合計 Issue 数、エラー数、警告数を一目で確認
- **カテゴリカード** — タイプ別の内訳（ファイル、依存関係、エクスポート）
- **SVG チャート** — タイプ別分布ドーナツチャートと Severity 別棒グラフ
- **インタラクティブフィルタ** — ファイルパス/シンボルで検索、Severity とタイプでフィルタ
- **ダークモード** — `prefers-color-scheme` による自動切替

外部依存なし — HTML ファイルをブラウザで開くだけで閲覧できます。

## 設定

プロジェクトルートに `shear.yaml`（または `shear.yml`、`.shear.yaml`、`.shear.yml`）を作成します。`shear init` で生成できます：

```yaml
# エントリーポイント — 分析はこれらのファイルから開始
entry:
  - bin/*.dart
  - lib/main.dart
  - test/**_test.dart

# プロジェクトスコープ — これらのファイルのみ分析対象
project:
  - lib/**.dart
  - bin/**.dart
  - test/**.dart

# 無視するファイル
ignore:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/*.mocks.dart"

# 暗黙的に使用されているとみなす依存関係
ignoreDependencies:
  - intl
  - flutter_gen

# 重大度ルール: error | warn | off
rules:
  unusedFiles: error
  unusedDependencies: error
  unusedExports: warn

# エントリーポイントファイルのエクスポートもチェックするか
includeEntryExports: false

# プラグイン設定
plugins:
  flutter: true
  build_runner: true
```

### デフォルト設定

Shear はプロジェクトタイプに基づいたスマートデフォルトを提供します。設定ファイルは特定の設定を上書きしたい場合のみ必要です。

#### 純粋な Dart プロジェクト

| 設定 | デフォルト値 |
|---|---|
| エントリーポイント | `bin/*.dart`, `lib/{package}.dart`, `test/**_test.dart`, `example/**.dart` |
| プロジェクトスコープ | `lib/**.dart`, `bin/**.dart`, `test/**.dart`, `example/**.dart` |
| 無視パターン | `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `*.gr.dart`, `*.config.dart`, `*.chopper.dart` |

#### Flutter プロジェクト

純粋な Dart のデフォルトに加えて：

| 設定 | 追加されるデフォルト値 |
|---|---|
| エントリーポイント | `lib/main.dart`, `integration_test/**_test.dart` |
| プロジェクトスコープ | `integration_test/**.dart` |
| 暗黙の依存関係 | `flutter`, `flutter_localizations`, `flutter_web_plugins` |

## 検出タイプ

### 未使用ファイル

エントリーポイントから**到達不能**な Dart ファイルを検出します。

Shear はプロジェクトの依存関係グラフを構築し、エントリーポイントから幅優先探索を行います。訪問されなかったファイルが未使用として報告されます。

- 重大度：**error**（デフォルト）
- `part` / `part of` の関係を考慮
- エントリーポイント自体は未使用として報告されない

### 未使用依存関係

`pubspec.yaml` に宣言されているが、どのファイルからも**インポートされていない**パッケージを検出します。

- 重大度：**error**（デフォルト）
- **推移的依存関係の考慮** — 使用パッケージが推移的に必要とする依存関係は誤検出しません。解決戦略（優先順）：
  1. `.dart_tool/package_graph.json`（`build_runner`）
  2. `.dart_tool/package_config.json`（標準 Dart ツーリング）
  3. Path dependency の走査（フォールバック）
- フレームワークが暗黙的に使用するパッケージ（例：`flutter`）は自動的に除外
- dev 依存関係は検出対象外（テストランナー等が誤検出されるため）

### 未使用エクスポート

他のファイルから**インポートされていない**公開エクスポートシンボル（クラス、関数、変数、typedef、mixin、enum、extension）を検出します。

- 重大度：**warning**（デフォルト）
- `show` / `hide` ディレクティブを分析して正確に検出
- **AST ベースの識別子収集** — bare import（`show`/`hide` なし）でもインポーター側の AST を走査し、実際に参照されているシンボルを特定
- **Conditional import 対応** — プラットフォーム別ターゲット（例：`if (dart.library.html)`）内のシンボルも正しく使用済みとして認識
- `export` ディレクティブによる推移的な再エクスポートを追跡
- エントリーポイントのエクスポートはデフォルトで除外（`includeEntryExports` で設定可能）

## プラグイン

プラグインは特定のフレームワークに合わせて Shear の動作を調整します。デフォルトで**自動検出**されます。

### Flutter プラグイン

`pubspec.yaml` の dependencies に `flutter` がある場合に有効化されます。

- `lib/main.dart` と `integration_test/**_test.dart` をエントリーポイントに追加
- プラットフォーム固有のディレクトリ（`ios/`、`android/`、`web/` など）を無視
- `flutter`、`flutter_localizations`、`flutter_web_plugins` を暗黙的に使用中としてマーク

### build_runner プラグイン

dev dependencies に `build_runner` がある場合に有効化されます。

- 生成ファイル（`*.g.dart`、`*.freezed.dart`、`*.config.dart` など）を無視

### プラグインの無効化

```yaml
# shear.yaml
plugins:
  flutter: false
  build_runner: false
```

## CI/CD 統合

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

### CI での JSON レポート

```yaml
      - name: Run Shear (JSON)
        run: shear analyze -r json -o shear-report.json

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: shear-report
          path: shear-report.json
```

### CI での HTML レポート

```yaml
      - name: Run Shear (HTML)
        run: shear analyze -r html -o shear-report.html

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: shear-html-report
          path: shear-report.html
```

## ベンチマーク

Shear には分析パイプラインの各フェーズを個別に計測するパフォーマンスベンチマークスクリプトが組み込まれています。

### 実行方法

```bash
dart run benchmark/performance_test.dart [オプション]
```

| オプション | 説明 | デフォルト |
|---|---|---|
| `--target=<dir>` | 対象プロジェクトディレクトリ | `.` |
| `--runs=<n>` | 計測回数（最小: 3） | `5` |
| `--warmup=<n>` | ウォームアップ回数（統計から除外） | `1` |
| `--all-fixtures` | `test/fixtures/*` の全プロジェクトも計測 | `false` |
| `--json` | JSON 形式で出力 | `false` |
| `-v, --verbose` | 各ランの個別結果を表示 | `false` |
| `-h, --help` | 使用方法を表示 | — |

### 計測フェーズ

分析パイプラインの各フェーズを独立して計測します：

| フェーズ | 説明 |
|---|---|
| `config` | 設定ファイルの読み込み（`ConfigLoader.load()`） |
| `plugin` | プラグインの自動検出と設定マージ |
| `scan` | プロジェクトファイルのスキャン（`ProjectScanner.scanProjectFiles()`） |
| `parse` * | 独立した `FileParser.parse()` ループ（参考値） |
| `graph` | ファイルパースを含むグラフ構築（`GraphBuilder.build()`） |
| `entry` | エントリーポイントの解決（`EntryResolver.resolve()`） |
| `fileDetect` | 未使用ファイルの検出 |
| `depDetect` | 未使用依存関係の検出 |
| `exportDetect` | 未使用エクスポートの検出 |

\* `parse` はプロファイリング用の独立計測パスです。`GraphBuilder.build()` が内部でファイルを再パースするため、二重計上を避けるために WALL TOTAL からは除外されます。

### 統計情報

各フェーズについて **min**、**avg**（平均）、**median**（中央値）、**p95**、**max**、**wall%**（全体に占める割合）を出力します。

ウォームアップは JIT のコールドスタートによるスキューを避けるため、統計から除外されます。

### 出力例

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

### JSON 出力

```bash
dart run benchmark/performance_test.dart --json
```

フェーズごとの統計値（`min_us`、`max_us`、`mean_us`、`median_us`、`p95_us`、単位: マイクロ秒）を含む構造化 JSON を出力します。CI でのパフォーマンス追跡やリグレッション検出に活用できます。

## 仕組み

```
                    ┌─────────────┐
                    │ shear.yaml  │
                    │   (設定)     │
                    └──────┬──────┘
                           │
                           ▼
┌──────────┐    ┌─────────────────────┐    ┌───────────────┐
│ ソース    │───▶│  ファイルパーサー     │───▶│ モジュール      │
│ ファイル  │    │  (AST 抽出)         │    │ グラフ          │
└──────────┘    └─────────────────────┘    │ (依存関係)     │
                                           └───────┬───────┘
                                                   │
                           ┌───────────────────────┼───────────────────────┐
                           │                       │                       │
                           ▼                       ▼                       ▼
                  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
                  │ 未使用ファイル    │   │ 未使用依存関係    │   │ 未使用エクスポート │
                  │ 検出             │   │ 検出             │   │ 検出             │
                  └────────┬────────┘   └────────┬────────┘   └────────┬────────┘
                           │                     │                     │
                           └──────────┬──────────┘─────────────────────┘
                                      │
                                      ▼
                             ┌─────────────────┐
                             │   レポーター       │
                             │(console/json/html)│
                             └─────────────────┘
```

1. **解析** — 各 Dart ファイルを AST に解析し、import、export、part、公開シンボル、参照識別子を抽出
2. **グラフ構築** — すべての import/export 関係から有向依存関係グラフを構築
3. **エントリー解決** — 設定、プラグイン、`main()` 関数からエントリーポイントを決定
4. **検出** — 3 つの検出器がグラフに対して独立に実行され、未使用コードを検出
5. **レポート** — 結果をフォーマットし、適切な終了コードとともに出力
6. **削除**（任意、`shear delete` 経由）— 検出された Issue を削除アクションに変換して実行：ファイル削除、pubspec.yaml 編集、AST ベースのシンボル削除

## 終了コード

| コード | 意味 |
|---|---|
| `0` | エラーなし（`--strict` 指定時を除き、警告は許容） |
| `1` | エラーが検出された、または `--strict` で警告が検出された |

## 必要環境

- Dart SDK `>=3.0.0 <4.0.0`

## コントリビューション

コントリビューションを歓迎します！お気軽に Pull Request を送ってください。

1. リポジトリをフォーク
2. フィーチャーブランチを作成（`git checkout -b feature/amazing-feature`）
3. テストを実行（`dart test`）
4. 変更をコミット
5. ブランチにプッシュ
6. Pull Request を作成

## ライセンス

詳細は [LICENSE](LICENSE) を参照してください。
