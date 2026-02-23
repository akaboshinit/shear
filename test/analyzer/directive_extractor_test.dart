import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:shear/src/analyzer/directive_extractor.dart';
import 'package:test/test.dart';

void main() {
  group('DirectiveExtractor', () {
    DirectiveExtractor extractDirectives(String code) {
      final tempDir = Directory.systemTemp.createTempSync('shear_test_');
      final tempFile = File('${tempDir.path}/test.dart');
      tempFile.writeAsStringSync(code);
      try {
        final result = parseFile(
          path: tempFile.absolute.path,
          featureSet: FeatureSet.latestLanguageVersion(),
          throwIfDiagnostics: false,
        );
        final extractor = DirectiveExtractor();
        for (final directive in result.unit.directives) {
          directive.accept(extractor);
        }
        return extractor;
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }

    test('extracts simple import', () {
      final ext = extractDirectives("import 'dart:io';");
      expect(ext.imports, hasLength(1));
      expect(ext.imports.first.uri, 'dart:io');
      expect(ext.imports.first.prefix, isNull);
    });

    test('extracts import with prefix', () {
      final ext = extractDirectives("import 'package:path/path.dart' as p;");
      expect(ext.imports, hasLength(1));
      expect(ext.imports.first.uri, 'package:path/path.dart');
      expect(ext.imports.first.prefix, 'p');
    });

    test('extracts import with show', () {
      final ext = extractDirectives("import 'dart:io' show File, Directory;");
      expect(ext.imports.first.showNames, ['File', 'Directory']);
      expect(ext.imports.first.hideNames, isEmpty);
    });

    test('extracts import with hide', () {
      final ext = extractDirectives("import 'dart:io' hide File;");
      expect(ext.imports.first.hideNames, ['File']);
      expect(ext.imports.first.showNames, isEmpty);
    });

    test('extracts deferred import', () {
      final ext =
          extractDirectives("import 'package:foo/foo.dart' deferred as foo;");
      expect(ext.imports.first.isDeferred, isTrue);
      expect(ext.imports.first.prefix, 'foo');
    });

    test('extracts export directive', () {
      final ext = extractDirectives("export 'src/foo.dart' show Bar;");
      expect(ext.exports, hasLength(1));
      expect(ext.exports.first.uri, 'src/foo.dart');
      expect(ext.exports.first.showNames, ['Bar']);
    });

    test('extracts part directive', () {
      final ext = extractDirectives("part 'src/part_file.dart';");
      expect(ext.parts, hasLength(1));
      expect(ext.parts.first.uri, 'src/part_file.dart');
    });

    test('extracts part of directive with URI', () {
      final ext = extractDirectives("part of 'main_lib.dart';");
      expect(ext.partOf, isNotNull);
      expect(ext.partOf!.uri, 'main_lib.dart');
    });

    test('extracts library name', () {
      final ext = extractDirectives('library my_library;');
      expect(ext.libraryName, 'my_library');
    });

    test('extracts multiple directives', () {
      final ext = extractDirectives('''
import 'dart:io';
import 'package:path/path.dart' as p;
export 'src/models.dart';
part 'src/part.dart';
''');
      expect(ext.imports, hasLength(2));
      expect(ext.exports, hasLength(1));
      expect(ext.parts, hasLength(1));
    });
  });
}
