import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:shear/src/analyzer/identifier_collector.dart';
import 'package:test/test.dart';

void main() {
  group('IdentifierCollector', () {
    /// Parse [code] and return an [IdentifierCollector] with results.
    IdentifierCollector collect(String code) {
      final tempDir = Directory.systemTemp.createTempSync('shear_test_');
      final tempFile = File('${tempDir.path}/test.dart');
      tempFile.writeAsStringSync(code);
      try {
        final result = parseFile(
          path: tempFile.absolute.path,
          featureSet: FeatureSet.latestLanguageVersion(),
          throwIfDiagnostics: false,
        );
        final collector = IdentifierCollector();
        result.unit.accept(collector);
        return collector;
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }

    group('referencedNames', () {
      test('collects class reference from constructor call', () {
        final c = collect('''
class Foo {}
void main() {
  Foo x = Foo();
}
''');
        expect(c.referencedNames, contains('Foo'));
      });

      test('collects function call reference', () {
        final c = collect('''
void formatDate() {}
void main() {
  formatDate();
}
''');
        expect(c.referencedNames, contains('formatDate'));
      });

      test('collects variable reference', () {
        final c = collect('''
const myConstant = 42;
void main() {
  print(myConstant);
}
''');
        expect(c.referencedNames, contains('myConstant'));
      });

      test('collects typedef reference', () {
        final c = collect('''
typedef MyCallback = void Function();
MyCallback? cb;
''');
        expect(c.referencedNames, contains('MyCallback'));
      });

      test('collects enum reference', () {
        final c = collect('''
enum Status { active, idle }
void main() {
  Status.active;
}
''');
        expect(c.referencedNames, contains('Status'));
      });

      test('collects mixin reference in with clause', () {
        final c = collect('''
mixin MyMixin {}
class X with MyMixin {}
''');
        expect(c.referencedNames, contains('MyMixin'));
      });

      test('collects annotation reference', () {
        final c = collect('''
@Deprecated('use other')
void oldFunc() {}
''');
        expect(c.referencedNames, contains('Deprecated'));
      });

      test('collects type annotation in generics', () {
        final c = collect('''
class Foo {}
class Bar {}
List<Foo> items = [];
Map<String, Bar> mapping = {};
''');
        expect(c.referencedNames, contains('Foo'));
        expect(c.referencedNames, contains('Bar'));
      });

      test('collects extends reference', () {
        final c = collect('''
class Base {}
class Child extends Base {}
''');
        expect(c.referencedNames, contains('Base'));
      });

      test('collects implements reference', () {
        final c = collect('''
class MyInterface {}
class Impl implements MyInterface {}
''');
        expect(c.referencedNames, contains('MyInterface'));
      });
    });

    group('declaration filtering', () {
      test('excludes class declaration name', () {
        final c = collect('class MyClass {}');
        expect(c.referencedNames, isNot(contains('MyClass')));
      });

      test('excludes function declaration name', () {
        final c = collect('void myFunc() {}');
        expect(c.referencedNames, isNot(contains('myFunc')));
      });

      test('excludes variable declaration name', () {
        final c = collect('final x = 1;');
        expect(c.referencedNames, isNot(contains('x')));
      });

      test('excludes enum declaration name', () {
        final c = collect('enum Color { red, green }');
        expect(c.referencedNames, isNot(contains('Color')));
      });

      test('excludes mixin declaration name', () {
        final c = collect('mixin Loggable {}');
        expect(c.referencedNames, isNot(contains('Loggable')));
      });

      test('excludes parameter names', () {
        final c = collect('void foo(int bar) {}');
        expect(c.referencedNames, isNot(contains('bar')));
      });
    });

    group('prefixedReferences', () {
      test('collects prefixed constructor call', () {
        final c = collect('''
import 'dart:core' as p;
void main() {
  p.Object();
}
''');
        expect(c.prefixedReferences['p'], contains('Object'));
      });

      test('collects prefixed function call', () {
        final c = collect('''
import 'dart:math' as math;
void main() {
  math.max(1, 2);
}
''');
        expect(c.prefixedReferences['math'], contains('max'));
      });

      test('collects prefixed type annotation', () {
        final c = collect('''
import 'dart:core' as core;
core.List<core.int> items = [];
''');
        expect(c.prefixedReferences['core'], contains('List'));
      });

      test('adds prefix name to referencedNames', () {
        final c = collect('''
import 'dart:math' as math;
void main() {
  math.max(1, 2);
}
''');
        expect(c.referencedNames, contains('math'));
      });

      test('collects multiple references under same prefix', () {
        final c = collect('''
import 'dart:core' as p;
void main() {
  p.Object();
  p.String;
}
''');
        expect(c.prefixedReferences['p'], containsAll(['Object', 'String']));
      });
    });

    group('mixed scenarios', () {
      test('distinguishes declarations from references', () {
        final c = collect('''
class Foo {}
class Bar {}
void main() {
  Foo x = Foo();
}
''');
        // Foo is referenced in the body
        expect(c.referencedNames, contains('Foo'));
        // Bar is only declared, never referenced
        expect(c.referencedNames, isNot(contains('Bar')));
      });

      test('handles complex file with multiple reference types', () {
        final c = collect('''
import 'dart:math' as math;

class Base {}
mixin Logger {}
typedef Callback = void Function();
enum Status { active }

class App extends Base with Logger {
  Callback? onDone;

  void run() {
    Status.active;
    math.max(1, 2);
  }
}
''');
        expect(
            c.referencedNames, containsAll(['Base', 'Logger', 'Callback', 'Status']));
        expect(c.prefixedReferences['math'], contains('max'));
      });
    });
  });
}
