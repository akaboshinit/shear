import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

import '../core/issue.dart';
import 'shear_config.dart';

/// Provides sensible defaults based on project type detection.
class DefaultConfig {
  DefaultConfig._();

  /// Create default config for the given project root.
  static Future<ShearConfig> forProject(String projectRoot) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      return _pureDartDefaults('app');
    }

    final pubspecContent = await pubspecFile.readAsString();
    final pubspec = Pubspec.parse(pubspecContent);
    final isFlutter = _isFlutterProject(pubspec);

    if (isFlutter) {
      return _flutterDefaults(pubspec.name);
    }
    return _pureDartDefaults(pubspec.name);
  }

  static bool _isFlutterProject(Pubspec pubspec) {
    return pubspec.dependencies.containsKey('flutter');
  }

  static ShearConfig _pureDartDefaults(String packageName) {
    return ShearConfig(
      entry: [
        'bin/*.dart',
        'lib/$packageName.dart',
        'test/**_test.dart',
        'example/**.dart',
      ],
      project: [
        'lib/**.dart',
        'bin/**.dart',
        'test/**.dart',
        'example/**.dart',
      ],
      ignore: _defaultIgnorePatterns,
      ignoreDependencies: const [],
      rules: _defaultRules,
    );
  }

  static ShearConfig _flutterDefaults(String packageName) {
    return ShearConfig(
      entry: [
        'bin/*.dart',
        'lib/$packageName.dart',
        'lib/main.dart',
        'test/**_test.dart',
        'example/**.dart',
        'integration_test/**_test.dart',
      ],
      project: [
        'lib/**.dart',
        'bin/**.dart',
        'test/**.dart',
        'example/**.dart',
        'integration_test/**.dart',
      ],
      ignore: _defaultIgnorePatterns,
      ignoreDependencies: const [
        'flutter',
        'flutter_localizations',
        'flutter_web_plugins',
        'flutter_test',
        'integration_test',
      ],
      rules: _defaultRules,
    );
  }

  static const List<String> _defaultIgnorePatterns = [
    '**/*.g.dart',
    '**/*.freezed.dart',
    '**/*.mocks.dart',
    '**/*.config.dart',
    '**/*.chopper.dart',
    'build/**',
    '.dart_tool/**',
  ];

  static const Map<IssueType, Severity> _defaultRules = {
    IssueType.unusedFile: Severity.error,
    IssueType.unusedDependency: Severity.error,
    IssueType.unlistedDependency: Severity.error,
    IssueType.unusedExport: Severity.warn,
    IssueType.unusedEnumMember: Severity.warn,
    IssueType.unusedClassMember: Severity.warn,
  };
}
