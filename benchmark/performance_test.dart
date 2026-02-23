import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:shear/src/analyzer/file_parser.dart';
import 'package:shear/src/analyzer/uri_resolver.dart';
import 'package:shear/src/config/config_loader.dart';
import 'package:shear/src/config/shear_config.dart';
import 'package:shear/src/core/entry_resolver.dart';
import 'package:shear/src/core/project_scanner.dart';
import 'package:shear/src/detection/detector.dart';
import 'package:shear/src/detection/unused_dep_detector.dart';
import 'package:shear/src/detection/unused_export_detector.dart';
import 'package:shear/src/detection/unused_file_detector.dart';
import 'package:shear/src/graph/graph_builder.dart';
import 'package:shear/src/plugin/plugin.dart';
import 'package:shear/src/plugin/plugin_registry.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class BenchmarkConfig {
  const BenchmarkConfig({
    required this.target,
    required this.runs,
    required this.warmup,
    required this.allFixtures,
    required this.json,
    required this.verbose,
  });

  final String target;
  final int runs;
  final int warmup;
  final bool allFixtures;
  final bool json;
  final bool verbose;
}

class PhaseResult {
  const PhaseResult(this.name, this.microseconds);

  final String name;
  final int microseconds;
}

class RunResult {
  const RunResult(this.phases, this.fileCount);

  final List<PhaseResult> phases;
  final int fileCount;

  int get wallTotal => phases
      .where((p) => p.name != 'parse')
      .fold(0, (sum, p) => sum + p.microseconds);
}

class PhaseStats {
  const PhaseStats(this.name, this.values);

  final String name;
  final List<int> values;

  int get minVal => Stats.min(values);
  int get maxVal => Stats.max(values);
  int get mean => Stats.mean(values);
  int get median => Stats.median(values);
  int get p95 => Stats.p95(values);
}

class BenchmarkResult {
  const BenchmarkResult({
    required this.target,
    required this.packageName,
    required this.fileCount,
    required this.phaseStats,
    required this.wallStats,
    required this.runs,
    required this.warmup,
  });

  final String target;
  final String packageName;
  final int fileCount;
  final List<PhaseStats> phaseStats;
  final PhaseStats wallStats;
  final int runs;
  final int warmup;
}

// ---------------------------------------------------------------------------
// Statistics helpers
// ---------------------------------------------------------------------------

class Stats {
  static int min(List<int> v) => v.reduce((a, b) => a < b ? a : b);
  static int max(List<int> v) => v.reduce((a, b) => a > b ? a : b);
  static int mean(List<int> v) => v.fold(0, (s, e) => s + e) ~/ v.length;

  static int median(List<int> v) {
    final sorted = [...v]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) ~/ 2;
  }

  static int p95(List<int> v) {
    final sorted = [...v]..sort();
    final index = ((sorted.length - 1) * 0.95).ceil();
    return sorted[math.min(index, sorted.length - 1)];
  }
}

// ---------------------------------------------------------------------------
// Benchmark runner
// ---------------------------------------------------------------------------

class BenchmarkRunner {
  Future<RunResult> run(String projectPath) async {
    final absoluteRoot = p.canonicalize(projectPath);
    final phases = <PhaseResult>[];

    // Phase 1: config
    var sw = Stopwatch()..start();
    final config = await ConfigLoader.load(absoluteRoot);
    sw.stop();
    phases.add(PhaseResult('config', sw.elapsedMicroseconds));

    // Phase 2: plugin
    sw = Stopwatch()..start();
    final autoPlugins = await PluginRegistry.autoDetect(absoluteRoot);
    final plugins = autoPlugins
        .where((plugin) => config.plugins[plugin.name] ?? true)
        .toList();
    final effectiveConfig = _mergePluginConfig(config, plugins);
    sw.stop();
    phases.add(PhaseResult('plugin', sw.elapsedMicroseconds));

    // Phase 3: scan
    sw = Stopwatch()..start();
    final scanner =
        ProjectScanner(config: effectiveConfig, projectRoot: absoluteRoot);
    final projectFiles = await scanner.scanProjectFiles();
    sw.stop();
    phases.add(PhaseResult('scan', sw.elapsedMicroseconds));

    final packageName = _readPackageName(absoluteRoot);
    final uriResolver =
        UriResolver(projectRoot: absoluteRoot, packageName: packageName);
    const parser = FileParser();

    // Phase 4a: parse (isolated measurement, subsumed by graph)
    sw = Stopwatch()..start();
    for (final f in projectFiles) {
      parser.parse(f);
    }
    sw.stop();
    phases.add(PhaseResult('parse', sw.elapsedMicroseconds));

    // Phase 4b: graph (includes re-parse)
    sw = Stopwatch()..start();
    final graphBuilder =
        GraphBuilder(fileParser: parser, uriResolver: uriResolver);
    final graph = graphBuilder.build(projectFiles);
    sw.stop();
    phases.add(PhaseResult('graph', sw.elapsedMicroseconds));

    // Phase 5: entry
    sw = Stopwatch()..start();
    final entryResolver = EntryResolver(
      config: effectiveConfig,
      projectRoot: absoluteRoot,
      plugins: plugins,
    );
    final entryFiles = await entryResolver.resolve(graph);
    sw.stop();
    phases.add(PhaseResult('entry', sw.elapsedMicroseconds));

    final ignoreDeps = <String>{
      ...effectiveConfig.ignoreDependencies,
      for (final plugin in plugins) ...plugin.implicitDependencies,
    }.toList();

    // Phase 6: detection
    for (final (name, detector) in [
      ('fileDetect', UnusedFileDetector() as Detector),
      ('depDetect', UnusedDepDetector(projectRoot: absoluteRoot)),
      (
        'exportDetect',
        UnusedExportDetector(
          uriResolver: uriResolver,
          includeEntryExports: effectiveConfig.includeEntryExports,
        ),
      ),
    ]) {
      sw = Stopwatch()..start();
      detector.detect(
        projectFiles: projectFiles,
        entryFiles: entryFiles,
        graph: graph,
        rules: effectiveConfig.rules,
        ignoreDependencies: ignoreDeps,
      );
      sw.stop();
      phases.add(PhaseResult(name, sw.elapsedMicroseconds));
    }

    return RunResult(phases, projectFiles.length);
  }

  ShearConfig _mergePluginConfig(
    ShearConfig config,
    List<ShearPlugin> plugins,
  ) {
    final entrySet = config.entry.toSet();
    final additionalIgnore = plugins
        .expand((plugin) => plugin.additionalIgnorePatterns)
        .where((pattern) => !entrySet.contains(pattern))
        .toList();

    if (additionalIgnore.isEmpty) return config;

    return config.copyWith(
      ignore: [...config.ignore, ...additionalIgnore],
    );
  }
}

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

class TablePrinter {
  static void printResult(BenchmarkResult result, {required bool verbose}) {
    stdout.writeln('');
    stdout.writeln(
        'Phase            min       avg    median      p95      max   wall%');
    stdout.writeln(
        '─────────────────────────────────────────────────────────────────────');

    final wallMedian = result.wallStats.median;

    for (final ps in result.phaseStats) {
      final isIsolated = ps.name == 'parse';
      final label =
          isIsolated ? '[${ps.name}*]'.padRight(16) : ps.name.padRight(16);
      final pct = isIsolated
          ? '----'
          : '${(ps.median / wallMedian * 100).toStringAsFixed(1)}%';
      stdout.writeln(
        '$label'
        ' ${_fmt(ps.minVal).padLeft(8)}'
        ' ${_fmt(ps.mean).padLeft(8)}'
        ' ${_fmt(ps.median).padLeft(8)}'
        ' ${_fmt(ps.p95).padLeft(8)}'
        ' ${_fmt(ps.maxVal).padLeft(8)}'
        '   ${pct.padLeft(6)}',
      );
    }

    stdout.writeln(
        '─────────────────────────────────────────────────────────────────────');

    final ws = result.wallStats;
    stdout.writeln(
      '${'WALL TOTAL'.padRight(16)}'
      ' ${_fmt(ws.minVal).padLeft(8)}'
      ' ${_fmt(ws.mean).padLeft(8)}'
      ' ${_fmt(ws.median).padLeft(8)}'
      ' ${_fmt(ws.p95).padLeft(8)}'
      ' ${_fmt(ws.maxVal).padLeft(8)}'
      '   100.0%',
    );

    stdout.writeln('');
    stdout.writeln('* [parse] is an isolated measurement; subsumed by [graph].');
  }

  static Map<String, dynamic> toJson(BenchmarkResult result) {
    return {
      'target': result.target,
      'packageName': result.packageName,
      'fileCount': result.fileCount,
      'runs': result.runs,
      'warmup': result.warmup,
      'phases': {
        for (final ps in result.phaseStats) ps.name: _statsToJson(ps),
      },
      'wall': _statsToJson(result.wallStats),
    };
  }

  static Map<String, int> _statsToJson(PhaseStats ps) => {
        'min_us': ps.minVal,
        'max_us': ps.maxVal,
        'mean_us': ps.mean,
        'median_us': ps.median,
        'p95_us': ps.p95,
      };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _fmt(int microseconds) {
  if (microseconds < 1000) return '$microsecondsµs';
  if (microseconds < 1000000) return '${(microseconds / 1000).toStringAsFixed(0)}ms';
  return '${(microseconds / 1000000).toStringAsFixed(3)}s';
}

String _readPackageName(String projectRoot) {
  final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) return 'app';
  final content = pubspecFile.readAsStringSync();
  final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(content);
  return match?.group(1) ?? 'app';
}

List<String> _discoverFixtures() {
  final fixturesDir = Directory('test/fixtures');
  if (!fixturesDir.existsSync()) return [];
  return fixturesDir
      .listSync()
      .whereType<Directory>()
      .where((d) => File(p.join(d.path, 'pubspec.yaml')).existsSync())
      .map((d) => d.path)
      .toList()
    ..sort();
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('target', defaultsTo: '.', help: 'Target project directory')
    ..addOption('runs', defaultsTo: '5', help: 'Number of measurement runs')
    ..addOption('warmup', defaultsTo: '1', help: 'Number of warmup runs')
    ..addFlag('all-fixtures', help: 'Also benchmark test/fixtures/*')
    ..addFlag('json', help: 'Output results as JSON')
    ..addFlag('verbose', abbr: 'v', help: 'Show individual run results')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: $e');
    stderr.writeln('Usage: dart run benchmark/performance_test.dart [options]');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (args.flag('help')) {
    stdout.writeln(
        'Usage: dart run benchmark/performance_test.dart [options]\n');
    stdout.writeln(parser.usage);
    return;
  }

  final runs = int.tryParse(args.option('runs')!) ?? 5;
  if (runs < 3) {
    stderr.writeln('Error: --runs must be >= 3 for meaningful statistics.');
    exit(1);
  }

  final config = BenchmarkConfig(
    target: args.option('target')!,
    runs: runs,
    warmup: int.tryParse(args.option('warmup')!) ?? 1,
    allFixtures: args.flag('all-fixtures'),
    json: args.flag('json'),
    verbose: args.flag('verbose'),
  );

  final targets = <String>[config.target];
  if (config.allFixtures) {
    targets.addAll(_discoverFixtures());
  }

  final runner = BenchmarkRunner();
  final allResults = <BenchmarkResult>[];

  for (final target in targets) {
    final absoluteRoot = p.canonicalize(target);
    final packageName = _readPackageName(absoluteRoot);

    if (!config.json) {
      stdout.write(
          'Running $target ($packageName)');
    }

    // Warmup
    for (var i = 0; i < config.warmup; i++) {
      await runner.run(target);
      if (!config.json) stdout.write('.');
    }

    // Measurement runs
    final runResults = <RunResult>[];
    for (var i = 0; i < config.runs; i++) {
      final result = await runner.run(target);
      runResults.add(result);
      if (!config.json) stdout.write('.');
    }

    if (!config.json) stdout.writeln(' done');

    // Compute phase stats
    final phaseNames =
        runResults.first.phases.map((p) => p.name).toList();
    final phaseStats = phaseNames.map((name) {
      final values = runResults
          .map((r) => r.phases.firstWhere((p) => p.name == name).microseconds)
          .toList();
      return PhaseStats(name, values);
    }).toList();

    final wallValues = runResults.map((r) => r.wallTotal).toList();
    final wallStats = PhaseStats('WALL', wallValues);

    final benchResult = BenchmarkResult(
      target: target,
      packageName: packageName,
      fileCount: runResults.first.fileCount,
      phaseStats: phaseStats,
      wallStats: wallStats,
      runs: config.runs,
      warmup: config.warmup,
    );

    allResults.add(benchResult);

    if (config.verbose && !config.json) {
      _printVerbose(runResults);
    }

    if (!config.json) {
      stdout.writeln(
          '\nshear benchmark  target=$target  runs=${config.runs}'
          '  warmup=${config.warmup}  files=${benchResult.fileCount}');
      TablePrinter.printResult(benchResult, verbose: config.verbose);
    }
  }

  if (config.json) {
    final output = allResults.length == 1
        ? TablePrinter.toJson(allResults.first)
        : {'benchmarks': allResults.map(TablePrinter.toJson).toList()};
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
  }
}

void _printVerbose(List<RunResult> runs) {
  stdout.writeln('\n  Individual runs:');
  for (var i = 0; i < runs.length; i++) {
    final r = runs[i];
    final parts = r.phases
        .map((p) => '${p.name}=${_fmt(p.microseconds)}')
        .join(', ');
    stdout.writeln('    Run ${i + 1}: $parts  (wall=${_fmt(r.wallTotal)})');
  }
}
