import 'package:shear/src/core/issue.dart';
import 'package:shear/src/detection/unused_class_member_detector.dart';
import 'package:shear/src/graph/module_graph.dart';
import 'package:shear/src/model/file_analysis.dart';
import 'package:shear/src/model/import_info.dart';
import 'package:shear/src/model/public_symbol.dart';
import 'package:test/test.dart';

void main() {
  group('UnusedClassMemberDetector', () {
    const projectRoot = '/test_project';

    List<Issue> detect(
      ModuleGraph graph, {
      required Set<String> projectFiles,
      Set<String> entryFiles = const {},
      Severity severity = Severity.warn,
    }) {
      return const UnusedClassMemberDetector().detect(
        projectFiles: projectFiles,
        entryFiles: entryFiles,
        graph: graph,
        rules: {IssueType.unusedClassMember: severity},
        ignoreDependencies: [],
      );
    }

    test('detects unused static method', () {
      const definingFile = '$projectRoot/lib/src/utils.dart';
      const importerFile = '$projectRoot/lib/main.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Utils',
              kind: SymbolKind.classDecl,
              filePath: definingFile,
              memberNames: ['format', 'parse', 'unused'],
            ),
          ],
        ))
        ..addFile(const FileAnalysis(
          absolutePath: importerFile,
          prefixedReferences: {
            'Utils': {'format', 'parse'},
          },
          referencedNames: {'Utils'},
        ));

      final issues = detect(
        graph,
        projectFiles: {definingFile, importerFile},
        entryFiles: {importerFile},
      );

      final unusedMembers = issues.map((i) => i.symbol).toSet();
      expect(unusedMembers, contains('Utils.unused'));
      expect(unusedMembers, isNot(contains('Utils.format')));
      expect(unusedMembers, isNot(contains('Utils.parse')));
    });

    test('detects unused instance method by name', () {
      const definingFile = '$projectRoot/lib/src/service.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Service',
              kind: SymbolKind.classDecl,
              filePath: definingFile,
              memberNames: ['start', 'stop', 'neverCalled'],
            ),
          ],
          referencedNames: {'start', 'stop'},
        ));

      final issues = detect(
        graph,
        projectFiles: {definingFile},
      );

      final unusedMembers = issues.map((i) => i.symbol).toSet();
      expect(unusedMembers, contains('Service.neverCalled'));
      expect(unusedMembers, isNot(contains('Service.start')));
      expect(unusedMembers, isNot(contains('Service.stop')));
    });

    test('considers instance method used if name appears in another file', () {
      const definingFile = '$projectRoot/lib/src/service.dart';
      const importerFile = '$projectRoot/lib/main.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Service',
              kind: SymbolKind.classDecl,
              filePath: definingFile,
              memberNames: ['execute'],
            ),
          ],
        ))
        ..addFile(const FileAnalysis(
          absolutePath: importerFile,
          referencedNames: {'execute', 'Service'},
        ));

      final issues = detect(
        graph,
        projectFiles: {definingFile, importerFile},
        entryFiles: {importerFile},
      );

      expect(issues, isEmpty,
          reason:
              'Instance method name found in referencedNames should be used');
    });

    test('returns empty when severity is off', () {
      const definingFile = '$projectRoot/lib/src/utils.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Utils',
              kind: SymbolKind.classDecl,
              filePath: definingFile,
              memberNames: ['neverUsed'],
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
              name: 'Helper',
              kind: SymbolKind.classDecl,
              filePath: partFile,
              memberNames: ['doWork'],
            ),
          ],
        ));

      final issues = detect(
        graph,
        projectFiles: {partFile},
      );

      expect(issues, isEmpty, reason: 'Part files should be skipped');
    });

    test('detects unused mixin members', () {
      const definingFile = '$projectRoot/lib/src/mixins.dart';

      final graph = ModuleGraph()
        ..addFile(FileAnalysis(
          absolutePath: definingFile,
          publicSymbols: [
            const PublicSymbol(
              name: 'Loggable',
              kind: SymbolKind.mixin,
              filePath: definingFile,
              memberNames: ['log', 'unusedHelper'],
            ),
          ],
          referencedNames: {'log'},
        ));

      final issues = detect(
        graph,
        projectFiles: {definingFile},
      );

      final unusedMembers = issues.map((i) => i.symbol).toSet();
      expect(unusedMembers, contains('Loggable.unusedHelper'));
      expect(unusedMembers, isNot(contains('Loggable.log')));
    });
  });
}
