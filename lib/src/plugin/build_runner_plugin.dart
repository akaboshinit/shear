import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

import 'plugin.dart';

/// Plugin for projects using build_runner.
///
/// Excludes generated files and marks build_runner as implicitly used.
class BuildRunnerPlugin extends ShearPlugin {
  @override
  String get name => 'build_runner';

  @override
  Future<bool> isApplicable(String projectRoot) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return false;

    final content = await pubspecFile.readAsString();
    final pubspec = Pubspec.parse(content);
    return pubspec.devDependencies.containsKey('build_runner');
  }

  @override
  List<String> get additionalIgnorePatterns => const [
        '**/*.g.dart',
        '**/*.freezed.dart',
        '**/*.config.dart',
        '**/*.chopper.dart',
      ];
}
