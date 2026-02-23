import 'package:shear/src/graph/module_graph.dart';
import 'package:shear/src/model/file_analysis.dart';
import 'package:test/test.dart';

void main() {
  group('ModuleGraph', () {
    late ModuleGraph graph;

    setUp(() {
      graph = ModuleGraph();
    });

    group('addFile / addEdge', () {
      test('stores file analysis', () {
        graph.addFile(FileAnalysis.empty('/a.dart'));
        expect(graph.files, contains('/a.dart'));
      });

      test('creates forward and reverse edges', () {
        graph.addEdge('/a.dart', '/b.dart');
        expect(graph.edges['/a.dart'], contains('/b.dart'));
        expect(graph.reverseEdges['/b.dart'], contains('/a.dart'));
      });
    });

    group('addPartRelation', () {
      test('records part-to-library and library-to-parts', () {
        graph.addPartRelation('/lib.dart', '/part.dart');
        expect(graph.partToLibrary['/part.dart'], equals('/lib.dart'));
        expect(graph.libraryToParts['/lib.dart'], contains('/part.dart'));
      });
    });

    group('addExternalPackage', () {
      test('records external package usage', () {
        graph.addExternalPackage('http', '/a.dart');
        expect(graph.externalPackageUsage['http'], contains('/a.dart'));
      });

      test('accumulates multiple files for same package', () {
        graph.addExternalPackage('http', '/a.dart');
        graph.addExternalPackage('http', '/b.dart');
        expect(graph.externalPackageUsage['http'], hasLength(2));
      });
    });

    group('computeReachable', () {
      test('returns entry files themselves', () {
        graph.addFile(FileAnalysis.empty('/a.dart'));
        final reachable = graph.computeReachable({'/a.dart'});
        expect(reachable, contains('/a.dart'));
      });

      test('follows forward edges via BFS', () {
        graph.addEdge('/a.dart', '/b.dart');
        graph.addEdge('/b.dart', '/c.dart');
        final reachable = graph.computeReachable({'/a.dart'});
        expect(reachable, containsAll(['/a.dart', '/b.dart', '/c.dart']));
      });

      test('handles circular references without infinite loop', () {
        graph.addEdge('/a.dart', '/b.dart');
        graph.addEdge('/b.dart', '/c.dart');
        graph.addEdge('/c.dart', '/a.dart');
        final reachable = graph.computeReachable({'/a.dart'});
        expect(reachable, containsAll(['/a.dart', '/b.dart', '/c.dart']));
      });

      test('includes part files of reachable libraries', () {
        graph.addEdge('/a.dart', '/lib.dart');
        graph.addPartRelation('/lib.dart', '/part.dart');
        final reachable = graph.computeReachable({'/a.dart'});
        expect(reachable, contains('/part.dart'));
      });

      test('includes parent library when part file is entry', () {
        graph.addPartRelation('/lib.dart', '/part.dart');
        final reachable = graph.computeReachable({'/part.dart'});
        expect(reachable, contains('/lib.dart'));
      });

      test('does not include unreachable files', () {
        graph.addEdge('/a.dart', '/b.dart');
        graph.addFile(FileAnalysis.empty('/isolated.dart'));
        final reachable = graph.computeReachable({'/a.dart'});
        expect(reachable, isNot(contains('/isolated.dart')));
      });

      test('handles multiple entry points', () {
        graph.addEdge('/a.dart', '/shared.dart');
        graph.addEdge('/b.dart', '/shared.dart');
        graph.addEdge('/b.dart', '/only_b.dart');
        final reachable = graph.computeReachable({'/a.dart', '/b.dart'});
        expect(
          reachable,
          containsAll(['/a.dart', '/b.dart', '/shared.dart', '/only_b.dart']),
        );
      });
    });

    group('externalPackagesFromFiles', () {
      test('returns packages used by given files', () {
        graph.addExternalPackage('http', '/a.dart');
        graph.addExternalPackage('path', '/b.dart');
        final packages = graph.externalPackagesFromFiles({'/a.dart'});
        expect(packages, contains('http'));
        expect(packages, isNot(contains('path')));
      });

      test('returns empty set when no packages used', () {
        final packages = graph.externalPackagesFromFiles({'/a.dart'});
        expect(packages, isEmpty);
      });

      test('includes package if any file in set uses it', () {
        graph.addExternalPackage('http', '/a.dart');
        graph.addExternalPackage('http', '/b.dart');
        final packages = graph.externalPackagesFromFiles({'/b.dart'});
        expect(packages, contains('http'));
      });
    });
  });
}
