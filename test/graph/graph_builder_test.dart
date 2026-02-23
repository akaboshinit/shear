import 'package:test/test.dart';

import '../helpers/test_utils.dart';

void main() {
  group('GraphBuilder', () {
    group('simple_dart fixture', () {
      late FixtureHelper fixture;
      late Set<String> projectFiles;

      setUp(() {
        fixture = FixtureHelper(
          fixtureName: 'simple_dart',
          packageName: 'simple_dart',
        );
        projectFiles = fixture.buildFileSet([
          'lib/simple_dart.dart',
          'lib/src/used_util.dart',
          'lib/src/models.dart',
          'lib/src/unused_helper.dart',
          'bin/main.dart',
          'test/simple_test.dart',
        ]);
      });

      test('adds edges for imports', () {
        final graph = fixture.graphBuilder.build(projectFiles);

        final mainEdges = graph.edges[fixture.filePath('bin/main.dart')];
        expect(mainEdges, isNotNull);
        expect(mainEdges, contains(fixture.filePath('lib/simple_dart.dart')));
      });

      test('adds edges for exports', () {
        final graph = fixture.graphBuilder.build(projectFiles);

        final barrelEdges =
            graph.edges[fixture.filePath('lib/simple_dart.dart')];
        expect(barrelEdges, isNotNull);
        expect(
            barrelEdges, contains(fixture.filePath('lib/src/used_util.dart')));
        expect(barrelEdges, contains(fixture.filePath('lib/src/models.dart')));
      });

      test('records external package usage', () {
        final graph = fixture.graphBuilder.build(projectFiles);

        expect(graph.externalPackageUsage, contains('path'));
        expect(graph.externalPackageUsage, contains('collection'));
      });

      test('parses all project files', () {
        final graph = fixture.graphBuilder.build(projectFiles);
        expect(graph.files, hasLength(6));
      });
    });

    group('part_files fixture', () {
      late FixtureHelper fixture;
      late Set<String> projectFiles;

      setUp(() {
        fixture = FixtureHelper(
          fixtureName: 'part_files',
          packageName: 'part_files',
        );
        projectFiles = fixture.buildFileSet([
          'lib/part_files.dart',
          'lib/src/uri_based_lib.dart',
          'lib/src/uri_based_part.dart',
          'lib/src/name_based_lib.dart',
          'lib/src/name_based_part.dart',
          'lib/src/unused_lib_with_part.dart',
          'lib/src/unused_part.dart',
          'bin/main.dart',
        ]);
      });

      test('builds part relations for URI-based part-of', () {
        final graph = fixture.graphBuilder.build(projectFiles);

        expect(
          graph.partToLibrary[fixture.filePath('lib/src/uri_based_part.dart')],
          equals(fixture.filePath('lib/src/uri_based_lib.dart')),
        );
      });

      test('resolves legacy name-based part-of', () {
        final graph = fixture.graphBuilder.build(projectFiles);

        expect(
          graph.partToLibrary[fixture.filePath('lib/src/name_based_part.dart')],
          equals(fixture.filePath('lib/src/name_based_lib.dart')),
        );
      });
    });

    group('circular_imports fixture', () {
      late FixtureHelper fixture;

      setUp(() {
        fixture = FixtureHelper(
          fixtureName: 'circular_imports',
          packageName: 'circular_imports',
        );
      });

      test('handles circular references safely', () {
        final projectFiles = fixture.buildFileSet([
          'lib/circular_imports.dart',
          'lib/src/a.dart',
          'lib/src/b.dart',
          'lib/src/c.dart',
          'lib/src/isolated.dart',
          'bin/main.dart',
        ]);

        // Should not throw or hang
        final graph = fixture.graphBuilder.build(projectFiles);
        expect(graph.files, hasLength(6));

        // All cycle files should be in the graph
        expect(graph.files, contains(fixture.filePath('lib/src/a.dart')));
        expect(graph.files, contains(fixture.filePath('lib/src/b.dart')));
        expect(graph.files, contains(fixture.filePath('lib/src/c.dart')));
      });
    });

    group('conditional_import fixture', () {
      late FixtureHelper fixture;

      setUp(() {
        fixture = FixtureHelper(
          fixtureName: 'conditional_import',
          packageName: 'conditional_import',
        );
      });

      test('records edges for all conditional import paths', () {
        final projectFiles = fixture.buildFileSet([
          'lib/conditional_import.dart',
          'lib/src/platform.dart',
          'lib/src/platform_stub.dart',
          'lib/src/platform_io.dart',
          'lib/src/platform_web.dart',
          'bin/main.dart',
        ]);

        final graph = fixture.graphBuilder.build(projectFiles);
        final platformEdges =
            graph.edges[fixture.filePath('lib/src/platform.dart')];

        expect(platformEdges, isNotNull);
        // All conditional branches should create edges
        expect(
          platformEdges,
          contains(fixture.filePath('lib/src/platform_stub.dart')),
        );
        expect(
          platformEdges,
          contains(fixture.filePath('lib/src/platform_io.dart')),
        );
        expect(
          platformEdges,
          contains(fixture.filePath('lib/src/platform_web.dart')),
        );
      });
    });
  });
}
