import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

import '../analyzer/file_parser.dart';
import '../analyzer/uri_resolver.dart';
import '../config/config_loader.dart';
import '../config/shear_config.dart';
import '../detection/unused_dep_detector.dart';
import '../detection/unused_export_detector.dart';
import '../detection/unused_file_detector.dart';
import '../graph/graph_builder.dart';
import '../plugin/plugin.dart';
import '../plugin/plugin_registry.dart';
import 'entry_resolver.dart';
import 'issue.dart';
import 'project_scanner.dart';

/// Orchestrates the full shear analysis pipeline.
class ShearAnalyzer {
  const ShearAnalyzer();

  /// Run analysis on the project at [projectRoot].
  Future<AnalysisResult> analyze(
    String projectRoot, {
    ShearConfig? configOverride,
  }) async {
    final absoluteRoot = p.canonicalize(projectRoot);

    final config = configOverride ?? await ConfigLoader.load(absoluteRoot);
    final autoDetectedPlugins = await PluginRegistry.autoDetect(absoluteRoot);
    final plugins = autoDetectedPlugins
        .where((plugin) => config.plugins[plugin.name] ?? true)
        .toList();
    final effectiveConfig = _mergePluginConfig(config, plugins);

    final scanner = ProjectScanner(
      config: effectiveConfig,
      projectRoot: absoluteRoot,
    );
    final projectFiles = await scanner.scanProjectFiles();

    final packageName = await _readPackageName(absoluteRoot);
    final uriResolver = UriResolver(
      projectRoot: absoluteRoot,
      packageName: packageName,
    );
    final graphBuilder = GraphBuilder(
      fileParser: const FileParser(),
      uriResolver: uriResolver,
    );
    final graph = graphBuilder.build(projectFiles);

    final entryResolver = EntryResolver(
      config: effectiveConfig,
      projectRoot: absoluteRoot,
      plugins: plugins,
    );
    final entryFiles = await entryResolver.resolve(graph);

    final ignoreDeps = <String>{
      ...effectiveConfig.ignoreDependencies,
      for (final plugin in plugins) ...plugin.implicitDependencies,
    }.toList();

    final detectors = [
      UnusedFileDetector(),
      UnusedDepDetector(projectRoot: absoluteRoot),
      UnusedExportDetector(
        uriResolver: uriResolver,
        includeEntryExports: effectiveConfig.includeEntryExports,
      ),
    ];

    final issues = <Issue>[
      for (final detector in detectors)
        ...detector.detect(
          projectFiles: projectFiles,
          entryFiles: entryFiles,
          graph: graph,
          rules: effectiveConfig.rules,
          ignoreDependencies: ignoreDeps,
        ),
    ];

    return AnalysisResult(issues: issues, graph: graph);
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

  Future<String> _readPackageName(String projectRoot) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return 'app';

    final content = await pubspecFile.readAsString();
    final pubspec = Pubspec.parse(content);
    return pubspec.name;
  }
}
