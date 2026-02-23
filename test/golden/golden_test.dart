import 'package:test/test.dart';

import '../helpers/golden_test_runner.dart';

void main() {
  group('Golden tests', () {
    test('simple_dart', () => runGoldenTest('simple_dart'));
    test('part_files', () => runGoldenTest('part_files'));
    test('circular_imports', () => runGoldenTest('circular_imports'));
    test('conditional_import', () => runGoldenTest('conditional_import'));
    test('unused_exports', () => runGoldenTest('unused_exports'));
    test('empty_project', () => runGoldenTest('empty_project'));
    test('show_hide_export', () => runGoldenTest('show_hide_export'));
    test('multi_entry', () => runGoldenTest('multi_entry'));
    test('ignore_patterns', () => runGoldenTest('ignore_patterns'));
    test('generated_route', () => runGoldenTest('generated_route'));
    test('bare_import', () => runGoldenTest('bare_import'));
  });
}
