import 'dart:io';

import 'package:shear/src/analyzer/file_parser.dart';
import 'package:test/test.dart';

void main() {
  group('FileParser', () {
    const parser = FileParser();
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('file_parser_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    File writeTemp(String name, String content) {
      final file = File('${tempDir.path}/$name');
      file.writeAsStringSync(content);
      return file;
    }

    test('parses imports', () {
      final file = writeTemp('test.dart', '''
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models.dart';
''');

      final analysis = parser.parse(file.path);
      expect(analysis.imports, hasLength(3));
      expect(analysis.imports[0].uri, equals('dart:io'));
      expect(analysis.imports[1].uri, equals('package:path/path.dart'));
      expect(analysis.imports[1].prefix, equals('p'));
      expect(analysis.imports[2].uri, equals('../models.dart'));
    });

    test('parses exports', () {
      final file = writeTemp('test.dart', '''
export 'src/models.dart';
export 'src/utils.dart' show joinPaths;
''');

      final analysis = parser.parse(file.path);
      expect(analysis.exports, hasLength(2));
      expect(analysis.exports[0].uri, equals('src/models.dart'));
      expect(analysis.exports[1].showNames, contains('joinPaths'));
    });

    test('parses public declarations', () {
      final file = writeTemp('test.dart', '''
class MyClass {}
void myFunction() {}
enum MyEnum { a, b }
mixin MyMixin {}
String myVariable = '';
typedef MyCallback = void Function();
''');

      final analysis = parser.parse(file.path);
      final names = analysis.publicSymbols.map((s) => s.name).toSet();
      expect(
          names,
          containsAll([
            'MyClass',
            'myFunction',
            'MyEnum',
            'MyMixin',
            'myVariable',
            'MyCallback',
          ]));
    });

    test('parses part directive', () {
      final file = writeTemp('test.dart', '''
library my_lib;
part 'src/part_file.dart';
''');

      final analysis = parser.parse(file.path);
      expect(analysis.parts, hasLength(1));
      expect(analysis.parts[0].uri, equals('src/part_file.dart'));
      expect(analysis.libraryName, equals('my_lib'));
    });

    test('parses part-of directive with URI', () {
      final file = writeTemp('test.dart', '''
part of '../my_lib.dart';

class PartClass {}
''');

      final analysis = parser.parse(file.path);
      expect(analysis.partOf, isNotNull);
      expect(analysis.partOf!.uri, equals('../my_lib.dart'));
      expect(analysis.isPartFile, isTrue);
    });

    test('parses part-of directive with library name', () {
      final file = writeTemp('test.dart', '''
part of my_lib;

class PartClass {}
''');

      final analysis = parser.parse(file.path);
      expect(analysis.partOf, isNotNull);
      expect(analysis.partOf!.libraryName, equals('my_lib'));
      expect(analysis.isPartFile, isTrue);
    });

    test('handles empty file', () {
      final file = writeTemp('empty.dart', '');

      final analysis = parser.parse(file.path);
      expect(analysis.imports, isEmpty);
      expect(analysis.exports, isEmpty);
      expect(analysis.parts, isEmpty);
      expect(analysis.partOf, isNull);
      expect(analysis.publicSymbols, isEmpty);
    });

    test('handles file with syntax errors gracefully', () {
      final file = writeTemp('bad.dart', '''
class Incomplete {
  void method( {
  }
''');

      final analysis = parser.parse(file.path);
      expect(analysis.absolutePath, equals(file.path));
    });

    test('parses import with show and hide combinators', () {
      final file = writeTemp('test.dart', '''
import 'models.dart' show User, Product;
import 'utils.dart' hide internalHelper;
''');

      final analysis = parser.parse(file.path);
      expect(analysis.imports[0].showNames, containsAll(['User', 'Product']));
      expect(analysis.imports[1].hideNames, contains('internalHelper'));
    });

    test('excludes private declarations', () {
      final file = writeTemp('test.dart', '''
class PublicClass {}
class _PrivateClass {}
void _privateFunction() {}
String _privateVar = '';
''');

      final analysis = parser.parse(file.path);
      final names = analysis.publicSymbols.map((s) => s.name).toSet();
      expect(names, contains('PublicClass'));
      expect(names, isNot(contains('_PrivateClass')));
      expect(names, isNot(contains('_privateFunction')));
      expect(names, isNot(contains('_privateVar')));
    });
  });
}
