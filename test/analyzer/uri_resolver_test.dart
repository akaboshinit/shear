import 'package:shear/src/analyzer/uri_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('UriResolver', () {
    late UriResolver resolver;

    setUp(() {
      resolver = UriResolver(
        projectRoot: '/project',
        packageName: 'my_app',
      );
    });

    test('returns null for dart: imports', () {
      final result = resolver.resolve('dart:io', '/project/lib/foo.dart');
      expect(result, isNull);
    });

    test('returns null for dart:core', () {
      final result = resolver.resolve('dart:core', '/project/lib/foo.dart');
      expect(result, isNull);
    });

    test('resolves self-referencing package import', () {
      final result = resolver.resolve(
        'package:my_app/src/bar.dart',
        '/project/lib/foo.dart',
      );
      expect(result, isA<InternalUri>());
      expect(
        (result! as InternalUri).filePath,
        '/project/lib/src/bar.dart',
      );
    });

    test('resolves external package import', () {
      final result = resolver.resolve(
        'package:http/http.dart',
        '/project/lib/foo.dart',
      );
      expect(result, isA<ExternalUri>());
      expect((result! as ExternalUri).packageName, 'http');
    });

    test('resolves relative import', () {
      final result = resolver.resolve(
        'bar.dart',
        '/project/lib/src/foo.dart',
      );
      expect(result, isA<InternalUri>());
      expect(
        (result! as InternalUri).filePath,
        '/project/lib/src/bar.dart',
      );
    });

    test('resolves relative import with ..', () {
      final result = resolver.resolve(
        '../models/user.dart',
        '/project/lib/src/utils/helper.dart',
      );
      expect(result, isA<InternalUri>());
      expect(
        (result! as InternalUri).filePath,
        '/project/lib/src/models/user.dart',
      );
    });

    test('resolves package import without path', () {
      final result = resolver.resolve(
        'package:other_pkg',
        '/project/lib/foo.dart',
      );
      expect(result, isA<ExternalUri>());
      expect((result! as ExternalUri).packageName, 'other_pkg');
    });
  });
}
