import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shear/src/deletion/delete_action.dart';
import 'package:shear/src/deletion/export_deleter.dart';
import 'package:shear/src/graph/module_graph.dart';
import 'package:test/test.dart';

void main() {
  group('ExportDeleter', () {
    late Directory tempDir;
    late ModuleGraph graph;
    late ExportDeleter deleter;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('export_deleter_test_');
      graph = ModuleGraph();
      deleter = ExportDeleter(graph: graph);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    String writeDartFile(String name, String content) {
      final path = p.join(tempDir.path, name);
      File(path).writeAsStringSync(content);
      return path;
    }

    test('removes a class declaration', () async {
      final path = writeDartFile('models.dart', '''
class Foo {
  final int x;
  Foo(this.x);
}

class Bar {
  final String name;
  Bar(this.name);
}
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['Foo'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('class Foo')));
      expect(content, contains('class Bar'));
    });

    test('removes a function declaration', () async {
      final path = writeDartFile('utils.dart', '''
void doSomething() {
  print('hello');
}

int add(int a, int b) => a + b;
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['doSomething'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('doSomething')));
      expect(content, contains('add'));
    });

    test('removes a top-level variable', () async {
      final path = writeDartFile('constants.dart', '''
const maxRetries = 3;

const timeout = Duration(seconds: 30);
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['maxRetries'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('maxRetries')));
      expect(content, contains('timeout'));
    });

    test('removes an enum declaration', () async {
      final path = writeDartFile('types.dart', '''
enum Color { red, green, blue }

enum Size { small, medium, large }
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['Color'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('enum Color')));
      expect(content, contains('enum Size'));
    });

    test('removes a mixin declaration', () async {
      final path = writeDartFile('mixins.dart', '''
mixin Loggable {
  void log(String msg) => print(msg);
}

mixin Serializable {
  Map<String, dynamic> toJson();
}
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['Loggable'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('mixin Loggable')));
      expect(content, contains('mixin Serializable'));
    });

    test('removes a typedef', () async {
      final path = writeDartFile('typedefs.dart', '''
typedef Callback = void Function(int);

typedef Mapper<T> = T Function(String);
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['Callback'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('Callback')));
      expect(content, contains('Mapper'));
    });

    test('removes multiple symbols at once', () async {
      final path = writeDartFile('multi.dart', '''
class Alpha {}

class Beta {}

class Gamma {}
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['Alpha', 'Gamma'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('Alpha')));
      expect(content, isNot(contains('Gamma')));
      expect(content, contains('Beta'));
    });

    test('removes declaration with doc comment', () async {
      final path = writeDartFile('documented.dart', '''
/// This is a documented class.
///
/// It has multiple lines of docs.
class Documented {
  void method() {}
}

class Other {}
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['Documented'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('Documented')));
      expect(content, isNot(contains('documented class')));
      expect(content, contains('class Other'));
    });

    test('removes declaration with annotation', () async {
      final path = writeDartFile('annotated.dart', '''
@deprecated
class OldClass {
  void method() {}
}

class NewClass {}
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['OldClass'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync();
      expect(content, isNot(contains('OldClass')));
      expect(content, isNot(contains('@deprecated')));
      expect(content, contains('class NewClass'));
    });

    test('finds symbol in part file', () async {
      final libPath = writeDartFile('lib.dart', '''
part 'part.dart';

class LibClass {}
''');
      final partPath = writeDartFile('part.dart', '''
part of 'lib.dart';

class PartClass {}
''');

      graph.addPartRelation(libPath, partPath);

      final action = RemoveSymbolAction(
        filePath: libPath,
        symbolNames: ['PartClass'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final partContent = File(partPath).readAsStringSync();
      expect(partContent, isNot(contains('class PartClass')));
    });

    test('returns error when symbol not found', () async {
      final path = writeDartFile('empty.dart', '''
class Existing {}
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['NonExistent'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isFalse);
      expect(result.error, contains('NonExistent'));
    });

    test('handles file with only removed symbols', () async {
      final path = writeDartFile('single.dart', '''
class OnlyClass {}
''');

      final action = RemoveSymbolAction(
        filePath: path,
        symbolNames: ['OnlyClass'],
      );
      final result = await deleter.execute(action);

      expect(result.success, isTrue);
      final content = File(path).readAsStringSync().trim();
      expect(content, isEmpty);
    });
  });
}
