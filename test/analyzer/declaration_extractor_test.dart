import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:shear/src/analyzer/declaration_extractor.dart';
import 'package:shear/src/model/public_symbol.dart';
import 'package:test/test.dart';

void main() {
  group('DeclarationExtractor', () {
    List<PublicSymbol> extractDecls(String code) {
      final tempDir = Directory.systemTemp.createTempSync('shear_test_');
      final tempFile = File('${tempDir.path}/test.dart');
      tempFile.writeAsStringSync(code);
      try {
        final result = parseFile(
          path: tempFile.absolute.path,
          featureSet: FeatureSet.latestLanguageVersion(),
          throwIfDiagnostics: false,
        );
        final extractor = DeclarationExtractor(tempFile.absolute.path);
        for (final declaration in result.unit.declarations) {
          declaration.accept(extractor);
        }
        return extractor.symbols;
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }

    test('extracts public class', () {
      final symbols = extractDecls('class MyClass {}');
      expect(symbols, hasLength(1));
      expect(symbols.first.name, 'MyClass');
      expect(symbols.first.kind, SymbolKind.classDecl);
    });

    test('skips private class', () {
      final symbols = extractDecls('class _PrivateClass {}');
      expect(symbols, isEmpty);
    });

    test('extracts public function', () {
      final symbols = extractDecls('void doSomething() {}');
      expect(symbols, hasLength(1));
      expect(symbols.first.name, 'doSomething');
      expect(symbols.first.kind, SymbolKind.function);
    });

    test('extracts public enum', () {
      final symbols = extractDecls('enum Color { red, green, blue }');
      expect(symbols, hasLength(1));
      expect(symbols.first.name, 'Color');
      expect(symbols.first.kind, SymbolKind.enumDecl);
    });

    test('extracts public mixin', () {
      final symbols = extractDecls('mixin Loggable {}');
      expect(symbols, hasLength(1));
      expect(symbols.first.name, 'Loggable');
      expect(symbols.first.kind, SymbolKind.mixin);
    });

    test('extracts public top-level variable', () {
      final symbols = extractDecls('final greeting = "hello";');
      expect(symbols, hasLength(1));
      expect(symbols.first.name, 'greeting');
      expect(symbols.first.kind, SymbolKind.variable);
    });

    test('extracts public typedef', () {
      final symbols = extractDecls('typedef Callback = void Function(int);');
      expect(symbols, hasLength(1));
      expect(symbols.first.name, 'Callback');
      expect(symbols.first.kind, SymbolKind.typedef);
    });

    test('extracts named extension', () {
      final symbols = extractDecls('extension StringExt on String {}');
      expect(symbols, hasLength(1));
      expect(symbols.first.name, 'StringExt');
      expect(symbols.first.kind, SymbolKind.extension);
    });

    test('skips unnamed extension', () {
      final symbols = extractDecls('extension on String {}');
      expect(symbols, isEmpty);
    });

    test('extracts mixed declarations', () {
      final symbols = extractDecls('''
class Foo {}
class _Bar {}
void publicFunc() {}
void _privateFunc() {}
enum Status { active, inactive }
final count = 0;
''');
      final names = symbols.map((s) => s.name).toList();
      expect(names, containsAll(['Foo', 'publicFunc', 'Status', 'count']));
      expect(names, isNot(contains('_Bar')));
      expect(names, isNot(contains('_privateFunc')));
    });
  });
}
