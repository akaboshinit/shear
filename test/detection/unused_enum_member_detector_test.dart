import 'package:shear/src/analyzer/uri_resolver.dart';
import 'package:shear/src/core/issue.dart';
import 'package:shear/src/detection/unused_enum_member_detector.dart';
import 'package:shear/src/graph/module_graph.dart';
import 'package:shear/src/model/file_analysis.dart';
import 'package:shear/src/model/import_info.dart';
import 'package:shear/src/model/public_symbol.dart';
import 'package:test/test.dart';

void main() {
  group('UnusedEnumMemberDetector', () {
    const projectRoot = '/test_project';
    final uriResolver = UriResolver(
      projectRoot: projectRoot,
      packageName: 'test_project',
    );

    List<Issue> detect(
      ModuleGraph graph, {
      required Set<String> projectFiles,
      Set<String> entryFiles = const {},
      Severity severity = Severity.warn,
    }) {
      return UnusedEnumMemberDetector(uriResolver: uriResolver).detect(
        projectFiles: projectFiles,
        entryFiles: entryFiles,
        graph: graph,
        rules: {IssueType.unusedEnumMember: severity},
        ignoreDependencies: [],
      );
    }

    test('detects unused enum members', () {
      const definingFile = '$projectRoot/lib/src/status.dart';
      const importerFile = '$projectRoot/lib/main.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Status',
              kind: SymbolKind.enumDecl,
              filePath: definingFile,
              memberNames: ['active', 'inactive', 'deleted'],
            ),
          ],
        ))
        ..addFile(const FileAnalysis(
          absolutePath: importerFile,
          imports: [ImportInfo(uri: 'src/status.dart')],
          prefixedReferences: {
            'Status': {'active'},
          },
        ))
        ..addEdge(importerFile, definingFile);

      final issues = detect(
        graph,
        projectFiles: {definingFile, importerFile},
        entryFiles: {importerFile},
      );

      final unusedMembers = issues.map((i) => i.symbol).toSet();
      expect(unusedMembers, contains('Status.inactive'));
      expect(unusedMembers, contains('Status.deleted'));
      expect(unusedMembers, isNot(contains('Status.active')));
    });

    test('marks all members as used when .values is referenced', () {
      const definingFile = '$projectRoot/lib/src/color.dart';
      const importerFile = '$projectRoot/lib/main.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Color',
              kind: SymbolKind.enumDecl,
              filePath: definingFile,
              memberNames: ['red', 'green', 'blue'],
            ),
          ],
        ))
        ..addFile(const FileAnalysis(
          absolutePath: importerFile,
          imports: [ImportInfo(uri: 'src/color.dart')],
          prefixedReferences: {
            'Color': {'values'},
          },
        ))
        ..addEdge(importerFile, definingFile);

      final issues = detect(
        graph,
        projectFiles: {definingFile, importerFile},
        entryFiles: {importerFile},
      );

      expect(issues, isEmpty,
          reason: 'All members should be used when .values is referenced');
    });

    test('considers members used when referenced in same file', () {
      const definingFile = '$projectRoot/lib/src/status.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Status',
              kind: SymbolKind.enumDecl,
              filePath: definingFile,
              memberNames: ['active', 'inactive'],
            ),
          ],
          prefixedReferences: {
            'Status': {'active', 'inactive'},
          },
        ));

      final issues = detect(
        graph,
        projectFiles: {definingFile},
      );

      expect(issues, isEmpty,
          reason: 'Members referenced in same file should be considered used');
    });

    test('considers members used when referenced in part file', () {
      const libFile = '$projectRoot/lib/my_lib.dart';
      const partFile = '$projectRoot/lib/src/my_part.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: libFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Status',
              kind: SymbolKind.enumDecl,
              filePath: libFile,
              memberNames: ['active', 'inactive'],
            ),
          ],
        ))
        ..addFile(FileAnalysis(
          absolutePath: partFile,
          partOf: const PartOfInfo(uri: '../my_lib.dart'),
          publicSymbols: const [],
          prefixedReferences: const {
            'Status': {'active', 'inactive'},
          },
        ))
        ..addPartRelation(libFile, partFile);

      final issues = detect(
        graph,
        projectFiles: {libFile, partFile},
      );

      expect(issues, isEmpty,
          reason: 'Members referenced in part file should be considered used');
    });

    test('returns empty when severity is off', () {
      const definingFile = '$projectRoot/lib/src/status.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Status',
              kind: SymbolKind.enumDecl,
              filePath: definingFile,
              memberNames: ['active', 'inactive'],
            ),
          ],
        ));

      final issues = detect(
        graph,
        projectFiles: {definingFile},
        severity: Severity.off,
      );

      expect(issues, isEmpty);
    });

    test('skips part files as defining file', () {
      const partFile = '$projectRoot/lib/src/part.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: partFile,
          partOf: const PartOfInfo(uri: '../lib.dart'),
          publicSymbols: [
            const PublicSymbol(
              name: 'Status',
              kind: SymbolKind.enumDecl,
              filePath: partFile,
              memberNames: ['active'],
            ),
          ],
        ));

      final issues = detect(
        graph,
        projectFiles: {partFile},
      );

      expect(issues, isEmpty, reason: 'Part files should be skipped');
    });

    test('combines references from multiple files', () {
      const definingFile = '$projectRoot/lib/src/status.dart';
      const importerA = '$projectRoot/lib/a.dart';
      const importerB = '$projectRoot/lib/b.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Status',
              kind: SymbolKind.enumDecl,
              filePath: definingFile,
              memberNames: ['active', 'inactive', 'deleted'],
            ),
          ],
        ))
        ..addFile(const FileAnalysis(
          absolutePath: importerA,
          imports: [ImportInfo(uri: 'src/status.dart')],
          prefixedReferences: {
            'Status': {'active'},
          },
        ))
        ..addFile(const FileAnalysis(
          absolutePath: importerB,
          imports: [ImportInfo(uri: 'src/status.dart')],
          prefixedReferences: {
            'Status': {'inactive'},
          },
        ))
        ..addEdge(importerA, definingFile)
        ..addEdge(importerB, definingFile);

      final issues = detect(
        graph,
        projectFiles: {definingFile, importerA, importerB},
        entryFiles: {importerA, importerB},
      );

      final unusedMembers = issues.map((i) => i.symbol).toSet();
      expect(unusedMembers, contains('Status.deleted'));
      expect(unusedMembers, isNot(contains('Status.active')));
      expect(unusedMembers, isNot(contains('Status.inactive')));
    });
  });
}
