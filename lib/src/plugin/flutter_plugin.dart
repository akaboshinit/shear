import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

import 'plugin.dart';

/// Plugin for Flutter projects.
///
/// Adds Flutter-specific entry points and implicit dependencies.
class FlutterPlugin extends ShearPlugin {
  @override
  String get name => 'flutter';

  @override
  Future<bool> isApplicable(String projectRoot) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return false;

    final content = await pubspecFile.readAsString();
    final pubspec = Pubspec.parse(content);
    return pubspec.dependencies.containsKey('flutter');
  }

  @override
  List<String> get additionalEntryPatterns => const [
        'lib/main.dart',
        'integration_test/**/*_test.dart',
      ];

  @override
  List<String> get additionalIgnorePatterns => const [
        'ios/**',
        'android/**',
        'macos/**',
        'windows/**',
        'linux/**',
        'web/**',
      ];

  @override
  List<String> get implicitDependencies => const [
        'flutter',
        'flutter_localizations',
        'flutter_web_plugins',
      ];
}
