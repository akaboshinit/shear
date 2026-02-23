import 'package:path/path.dart' as p;
import 'package:shear/src/analyzer/file_parser.dart';
import 'package:shear/src/analyzer/uri_resolver.dart';
import 'package:shear/src/graph/graph_builder.dart';

/// Helper for working with test fixtures.
class FixtureHelper {
  FixtureHelper({
    required this.fixtureName,
    String? packageName,
  })  : fixtureRoot = p.canonicalize('test/fixtures/$fixtureName'),
        _packageName = packageName ?? fixtureName;

  final String fixtureName;
  final String fixtureRoot;
  final String _packageName;

  /// URI resolver configured for this fixture.
  late final UriResolver uriResolver = UriResolver(
    projectRoot: fixtureRoot,
    packageName: _packageName,
  );

  /// Graph builder configured for this fixture.
  late final GraphBuilder graphBuilder = GraphBuilder(
    fileParser: const FileParser(),
    uriResolver: uriResolver,
  );

  /// Convert relative paths to absolute paths within this fixture.
  Set<String> buildFileSet(List<String> relativePaths) {
    return relativePaths.map((rel) => p.join(fixtureRoot, rel)).toSet();
  }

  /// Join a relative path with the fixture root.
  String filePath(String relativePath) => p.join(fixtureRoot, relativePath);
}
