import 'package:shear/src/plugin/build_runner_plugin.dart';
import 'package:test/test.dart';

void main() {
  group('BuildRunnerPlugin', () {
    late BuildRunnerPlugin plugin;

    setUp(() {
      plugin = BuildRunnerPlugin();
    });

    test('name is build_runner', () {
      expect(plugin.name, 'build_runner');
    });

    test('ignores common generated file patterns', () {
      expect(plugin.additionalIgnorePatterns, contains('**/*.g.dart'));
      expect(plugin.additionalIgnorePatterns, contains('**/*.freezed.dart'));
      expect(plugin.additionalIgnorePatterns, contains('**/*.config.dart'));
      expect(plugin.additionalIgnorePatterns, contains('**/*.chopper.dart'));
    });

    test('does not ignore .gr.dart files', () {
      // .gr.dart files (auto_route) import page files, so ignoring them
      // breaks the dependency graph and causes false positives.
      expect(plugin.additionalIgnorePatterns, isNot(contains('**/*.gr.dart')));
    });

  });
}
