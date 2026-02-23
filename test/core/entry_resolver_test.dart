import 'package:path/path.dart' as p;
import 'package:shear/src/config/shear_config.dart';
import 'package:shear/src/core/entry_resolver.dart';
import 'package:shear/src/graph/module_graph.dart';
import 'package:shear/src/model/file_analysis.dart';
import 'package:shear/src/model/public_symbol.dart';
import 'package:test/test.dart';

void main() {
  group('EntryResolver', () {
    late String fixtureRoot;

    setUp(() {
      fixtureRoot = p.canonicalize('test/fixtures/simple_dart');
    });

    EntryResolver createResolver({List<String> entry = const []}) {
      return EntryResolver(
        config: ShearConfig(entry: entry),
        projectRoot: fixtureRoot,
        plugins: [],
      );
    }

    void addFileWithSymbol(
      ModuleGraph graph, {
      required String path,
      required String name,
      required SymbolKind kind,
    }) {
      graph.addFile(FileAnalysis(
        absolutePath: path,
        publicSymbols: [
          PublicSymbol(name: name, kind: kind, filePath: ''),
        ],
      ));
    }

    test('resolves entry files matching glob patterns', () async {
      final resolver = createResolver(entry: ['bin/*.dart']);

      final entryFiles = await resolver.resolve(ModuleGraph());

      expect(
        entryFiles.any((f) => f.endsWith('main.dart')),
        isTrue,
        reason: 'Should match bin/main.dart',
      );
    });

    test('detects files with main() function as entry points', () async {
      final resolver = createResolver();
      final graph = ModuleGraph();
      final mainFilePath = p.join(fixtureRoot, 'bin', 'main.dart');
      addFileWithSymbol(
        graph,
        path: mainFilePath,
        name: 'main',
        kind: SymbolKind.function,
      );

      final entryFiles = await resolver.resolve(graph);
      expect(entryFiles, contains(mainFilePath));
    });

    test('combines pattern matches and main() detection', () async {
      final resolver = createResolver(entry: ['test/**_test.dart']);
      final graph = ModuleGraph();
      final mainFilePath = p.join(fixtureRoot, 'bin', 'main.dart');
      addFileWithSymbol(
        graph,
        path: mainFilePath,
        name: 'main',
        kind: SymbolKind.function,
      );

      final entryFiles = await resolver.resolve(graph);

      expect(
        entryFiles.any((f) => f.endsWith('simple_test.dart')),
        isTrue,
      );
      expect(entryFiles, contains(mainFilePath));
    });

    test('does not add non-main symbols as entry points', () async {
      final resolver = createResolver();
      final graph = ModuleGraph();
      addFileWithSymbol(
        graph,
        path: '/some/file.dart',
        name: 'helper',
        kind: SymbolKind.function,
      );

      final entryFiles = await resolver.resolve(graph);
      expect(entryFiles, isNot(contains('/some/file.dart')));
    });

    test('does not add main variable as entry point', () async {
      final resolver = createResolver();
      final graph = ModuleGraph();
      addFileWithSymbol(
        graph,
        path: '/some/file.dart',
        name: 'main',
        kind: SymbolKind.variable,
      );

      final entryFiles = await resolver.resolve(graph);
      expect(entryFiles, isNot(contains('/some/file.dart')));
    });
  });
}
