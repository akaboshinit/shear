import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

import '../core/issue.dart';
import '../graph/module_graph.dart';
import 'detector.dart';

/// Detects packages imported in source code but not declared in pubspec.yaml.
class UnlistedDepDetector implements Detector {
  const UnlistedDepDetector({required this.projectRoot});

  final String projectRoot;

  @override
  List<Issue> detect({
    required Set<String> projectFiles,
    required Set<String> entryFiles,
    required ModuleGraph graph,
    required Map<IssueType, Severity> rules,
    required List<String> ignoreDependencies,
  }) {
    final severity = rules[IssueType.unlistedDependency];
    if (severity == null || severity == Severity.off) return const [];

    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return const [];

    final pubspec = Pubspec.parse(pubspecFile.readAsStringSync());

    final declared = <String>{
      ...pubspec.dependencies.keys,
      ...pubspec.devDependencies.keys,
      pubspec.name,
    };

    final imported = graph.externalPackageUsage.keys.toSet();
    final ignoredSet = ignoreDependencies.toSet();

    final unlisted = imported.difference(declared).difference(ignoredSet);

    final sorted = unlisted.toList()..sort();

    return [
      for (final pkg in sorted)
        Issue(
          type: IssueType.unlistedDependency,
          severity: severity,
          filePath: 'pubspec.yaml',
          symbol: pkg,
          message: 'Unlisted dependency: $pkg',
        ),
    ];
  }
}
