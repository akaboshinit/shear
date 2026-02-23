import 'package:shear/src/analyzer/uri_resolver.dart';
import 'package:shear/src/core/issue.dart';
import 'package:shear/src/detection/unused_export_detector.dart';
import 'package:shear/src/graph/module_graph.dart';
import 'package:shear/src/model/file_analysis.dart';
import 'package:shear/src/model/import_info.dart';
import 'package:shear/src/model/public_symbol.dart';
import 'package:test/test.dart';

import '../helpers/test_utils.dart';

void main() {
  group('UnusedExportDetector', () {
    group('with synthetic graph', () {
      const projectRoot = '/test_project';
      final uriResolver = UriResolver(
        projectRoot: projectRoot,
        packageName: 'test_project',
      );

      List<Issue> detect(
        ModuleGraph graph, {
        required Set<String> projectFiles,
        required Set<String> entryFiles,
        bool includeEntryExports = false,
        Severity severity = Severity.warn,
      }) {
        return UnusedExportDetector(
          uriResolver: uriResolver,
          includeEntryExports: includeEntryExports,
        ).detect(
          projectFiles: projectFiles,
          entryFiles: entryFiles,
          graph: graph,
          rules: {IssueType.unusedExport: severity},
          ignoreDependencies: [],
        );
      }

      /// Creates a [PublicSymbol] for the given file.
      PublicSymbol symbol(String name, String filePath,
              {SymbolKind kind = SymbolKind.classDecl}) =>
          PublicSymbol(name: name, kind: kind, filePath: filePath);

      test('bare import fallback: empty referencedNames treats all as used',
          () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        // FileAnalysis without referencedNames (backward compat fallback).
        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('Foo', definingFile),
              symbol('Bar', definingFile),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [ImportInfo(uri: 'src/models.dart')],
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        expect(issues, isEmpty,
            reason: 'Empty referencedNames = fallback to all symbols used');
      });

      test('bare import detects unused symbols via referencedNames', () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('Foo', definingFile),
              symbol('Bar', definingFile),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [ImportInfo(uri: 'src/models.dart')],
            referencedNames: {'Foo', 'print'},
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('Bar'));
        expect(unusedSymbols, isNot(contains('Foo')));
      });

      test('bare import detects unused function', () {
        const definingFile = '$projectRoot/lib/src/utils.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('helperFunction', definingFile,
                  kind: SymbolKind.function),
              symbol('unusedFunction', definingFile,
                  kind: SymbolKind.function),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [ImportInfo(uri: 'src/utils.dart')],
            referencedNames: {'helperFunction', 'print'},
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('unusedFunction'));
        expect(unusedSymbols, isNot(contains('helperFunction')));
      });

      test('bare import detects unused variable', () {
        const definingFile = '$projectRoot/lib/src/config.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('usedVar', definingFile, kind: SymbolKind.variable),
              symbol('globalConfig', definingFile, kind: SymbolKind.variable),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [ImportInfo(uri: 'src/config.dart')],
            referencedNames: {'usedVar'},
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('globalConfig'));
        expect(unusedSymbols, isNot(contains('usedVar')));
      });

      test('bare import with mixed class and function usage', () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('Foo', definingFile),
              symbol('unusedHelper', definingFile, kind: SymbolKind.function),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [ImportInfo(uri: 'src/models.dart')],
            referencedNames: {'Foo'},
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('unusedHelper'));
        expect(unusedSymbols, isNot(contains('Foo')));
      });

      test('prefixed bare import detects unused symbols', () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('myFunction', definingFile, kind: SymbolKind.function),
              symbol('MyClass', definingFile),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [
              ImportInfo(uri: 'src/models.dart', prefix: 'p'),
            ],
            prefixedReferences: {
              'p': {'myFunction'},
            },
            referencedNames: {'p'},
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('MyClass'));
        expect(unusedSymbols, isNot(contains('myFunction')));
      });

      test('bare import: union across multiple importers', () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerA = '$projectRoot/lib/a.dart';
        const importerB = '$projectRoot/lib/b.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('Foo', definingFile),
              symbol('Bar', definingFile),
              symbol('Baz', definingFile),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerA,
            imports: [ImportInfo(uri: 'src/models.dart')],
            referencedNames: {'Foo'},
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerB,
            imports: [ImportInfo(uri: 'src/models.dart')],
            referencedNames: {'Bar'},
          ))
          ..addEdge(importerA, definingFile)
          ..addEdge(importerB, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerA, importerB},
          entryFiles: {importerA, importerB},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('Baz'),
            reason: 'Baz is not used by any importer');
        expect(unusedSymbols, isNot(contains('Foo')),
            reason: 'Foo is used by importer A');
        expect(unusedSymbols, isNot(contains('Bar')),
            reason: 'Bar is used by importer B');
      });

      test('show import marks only specified symbols as used', () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('Foo', definingFile),
              symbol('Bar', definingFile),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [
              ImportInfo(uri: 'src/models.dart', showNames: ['Foo']),
            ],
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('Bar'));
        expect(unusedSymbols, isNot(contains('Foo')));
      });

      test('hide import marks all except hidden as used', () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('Foo', definingFile),
              symbol('Bar', definingFile),
              symbol('Baz', definingFile),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [
              ImportInfo(uri: 'src/models.dart', hideNames: ['Bar']),
            ],
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('Bar'));
        expect(unusedSymbols, isNot(contains('Foo')));
        expect(unusedSymbols, isNot(contains('Baz')));
      });

      test('skips part files', () {
        const partFile = '$projectRoot/lib/src/part.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: partFile,
            partOf: const PartOfInfo(uri: '../lib.dart'),
            publicSymbols: [symbol('PartClass', partFile)],
          ));

        final issues = detect(
          graph,
          projectFiles: {partFile},
          entryFiles: <String>{},
        );

        expect(issues, isEmpty, reason: 'Part files should be skipped');
      });

      test('skips entry files when includeEntryExports is false', () {
        const entryFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: entryFile,
            publicSymbols: [
              symbol('main', entryFile, kind: SymbolKind.function),
              symbol('SomeExport', entryFile),
            ],
          ));

        final issues = detect(
          graph,
          projectFiles: {entryFile},
          entryFiles: {entryFile},
        );

        expect(issues, isEmpty);
      });

      test('checks entry files when includeEntryExports is true', () {
        const entryFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: entryFile,
            publicSymbols: [symbol('NeverUsedExport', entryFile)],
          ));

        final issues = detect(
          graph,
          projectFiles: {entryFile},
          entryFiles: {entryFile},
          includeEntryExports: true,
        );

        expect(issues.map((i) => i.symbol), contains('NeverUsedExport'));
      });

      test('recognizes re-exported symbols as used', () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const reexporterFile = '$projectRoot/lib/barrel.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [symbol('MyModel', definingFile)],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: reexporterFile,
            exports: [ExportInfo(uri: 'src/models.dart')],
          ))
          ..addEdge(reexporterFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, reexporterFile},
          entryFiles: {reexporterFile},
        );

        expect(
          issues,
          isEmpty,
          reason: 'Re-exported symbols should be considered used',
        );
      });

      test('returns empty when severity is off', () {
        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: '$projectRoot/lib/models.dart',
            publicSymbols: [
              symbol('Orphan', '$projectRoot/lib/models.dart'),
            ],
          ));

        final issues = detect(
          graph,
          projectFiles: {'$projectRoot/lib/models.dart'},
          entryFiles: <String>{},
          severity: Severity.off,
        );

        expect(issues, isEmpty);
      });

      test('bare import marks extension as used when file is imported', () {
        const definingFile = '$projectRoot/lib/src/extensions.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              PublicSymbol(
                name: 'StringExt',
                kind: SymbolKind.extension,
                filePath: definingFile,
              ),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [ImportInfo(uri: 'src/extensions.dart')],
            referencedNames: {'isEmail'},
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        expect(issues, isEmpty,
            reason:
                'Extension imported via bare import should be considered used');
      });

      test(
          'bare import marks extension as used even with non-matching referenced names',
          () {
        const definingFile = '$projectRoot/lib/src/extensions.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              PublicSymbol(
                name: 'RaceScheduleStatusModelUIExt',
                kind: SymbolKind.extension,
                filePath: definingFile,
              ),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [ImportInfo(uri: 'src/extensions.dart')],
            referencedNames: {'label', 'statusText', 'l10n'},
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        expect(issues, isEmpty,
            reason:
                'Extension name never appears as identifier but is used implicitly');
      });

      test('extension with show import is only used if explicitly shown', () {
        const definingFile = '$projectRoot/lib/src/extensions.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              PublicSymbol(
                name: 'StringExt',
                kind: SymbolKind.extension,
                filePath: definingFile,
              ),
              symbol('OtherClass', definingFile),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [
              ImportInfo(
                  uri: 'src/extensions.dart', showNames: ['OtherClass']),
            ],
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('StringExt'),
            reason:
                'Extension not in show list should be reported as unused');
        expect(unusedSymbols, isNot(contains('OtherClass')));
      });

      test(
          'bare import with mixed extension and class: extension used, unused class detected',
          () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              PublicSymbol(
                name: 'ListExt',
                kind: SymbolKind.extension,
                filePath: definingFile,
              ),
              symbol('UnusedModel', definingFile),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [ImportInfo(uri: 'src/models.dart')],
            referencedNames: {'sortByName'},
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, isNot(contains('ListExt')),
            reason: 'Extension should be considered used via bare import');
        expect(unusedSymbols, contains('UnusedModel'),
            reason:
                'Non-extension symbol not in referencedNames should be unused');
      });

      test(
          'conditional import marks symbols in config target as used',
          () {
        const defaultFile = '$projectRoot/lib/src/adapter/default.dart';
        const browserFile = '$projectRoot/lib/src/adapter/browser.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: defaultFile,
            publicSymbols: [
              symbol('createAdapter', defaultFile, kind: SymbolKind.function),
            ],
          ))
          ..addFile(FileAnalysis(
            absolutePath: browserFile,
            publicSymbols: [
              symbol('createAdapter', browserFile, kind: SymbolKind.function),
            ],
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [
              ImportInfo(
                uri: 'src/adapter/default.dart',
                showNames: ['createAdapter'],
                configurations: [
                  ConditionalConfig(
                    name: 'dart.library.html',
                    uri: 'src/adapter/browser.dart',
                  ),
                ],
              ),
            ],
            referencedNames: {'createAdapter'},
          ))
          ..addEdge(importerFile, defaultFile)
          ..addEdge(importerFile, browserFile);

        final issues = detect(
          graph,
          projectFiles: {defaultFile, browserFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, isNot(contains('createAdapter')),
            reason:
                'Symbols in conditional import target should be considered used');
      });

      test('includes part file symbols in library check', () {
        const libFile = '$projectRoot/lib/my_lib.dart';
        const partFile = '$projectRoot/lib/src/my_part.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: libFile,
            publicSymbols: [symbol('LibClass', libFile)],
          ))
          ..addFile(FileAnalysis(
            absolutePath: partFile,
            partOf: const PartOfInfo(uri: '../my_lib.dart'),
            publicSymbols: [symbol('PartClass', partFile)],
          ))
          ..addPartRelation(libFile, partFile)
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [
              ImportInfo(
                uri: 'my_lib.dart',
                showNames: ['LibClass'],
              ),
            ],
          ))
          ..addEdge(importerFile, libFile);

        final issues = detect(
          graph,
          projectFiles: {libFile, partFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, contains('PartClass'));
        expect(unusedSymbols, isNot(contains('LibClass')));
      });

      test(
          'symbol referenced within same file should NOT be reported as unused',
          () {
        const definingFile = '$projectRoot/lib/src/state.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('MyState', definingFile),
              symbol('myStateProvider', definingFile,
                  kind: SymbolKind.variable),
            ],
            referencedNames: {'MyState', 'StateNotifierProvider'},
          ));

        final issues = detect(
          graph,
          projectFiles: {definingFile},
          entryFiles: <String>{},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, isNot(contains('MyState')),
            reason:
                'MyState is referenced within same file as type parameter');
        expect(unusedSymbols, contains('myStateProvider'),
            reason: 'myStateProvider is not referenced elsewhere');
      });

      test(
          'symbol only declared (not referenced) in same file SHOULD be reported',
          () {
        const definingFile = '$projectRoot/lib/src/dead_code.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [symbol('DeadClass', definingFile)],
            referencedNames: {'SomeOtherThing'},
          ));

        final issues = detect(
          graph,
          projectFiles: {definingFile},
          entryFiles: <String>{},
        );

        expect(issues.map((i) => i.symbol), contains('DeadClass'));
      });

      test('symbol referenced in part file should NOT be reported', () {
        const libFile = '$projectRoot/lib/my_lib.dart';
        const partFile = '$projectRoot/lib/src/my_part.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: libFile,
            publicSymbols: [
              symbol('SharedMixin', libFile),
              symbol('UnusedHelper', libFile),
            ],
            referencedNames: {'print'},
          ))
          ..addFile(FileAnalysis(
            absolutePath: partFile,
            partOf: const PartOfInfo(uri: '../my_lib.dart'),
            publicSymbols: const [],
            referencedNames: const {'SharedMixin'},
          ))
          ..addPartRelation(libFile, partFile);

        final issues = detect(
          graph,
          projectFiles: {libFile, partFile},
          entryFiles: <String>{},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, isNot(contains('SharedMixin')),
            reason: 'SharedMixin is referenced in part file');
        expect(unusedSymbols, contains('UnusedHelper'),
            reason: 'UnusedHelper is not referenced anywhere');
      });

      test(
          'symbol used both internally and externally should NOT be reported',
          () {
        const definingFile = '$projectRoot/lib/src/models.dart';
        const importerFile = '$projectRoot/lib/main.dart';

        final graph = ModuleGraph()
          ..addFile(FileAnalysis(
            absolutePath: definingFile,
            publicSymbols: [
              symbol('Foo', definingFile),
              symbol('Bar', definingFile),
              symbol('Baz', definingFile),
            ],
            referencedNames: {'Foo', 'Bar'},
          ))
          ..addFile(const FileAnalysis(
            absolutePath: importerFile,
            imports: [
              ImportInfo(uri: 'src/models.dart', showNames: ['Foo']),
            ],
          ))
          ..addEdge(importerFile, definingFile);

        final issues = detect(
          graph,
          projectFiles: {definingFile, importerFile},
          entryFiles: {importerFile},
        );

        final unusedSymbols = issues.map((i) => i.symbol).toSet();
        expect(unusedSymbols, isNot(contains('Foo')),
            reason: 'Foo is used both internally and externally');
        expect(unusedSymbols, isNot(contains('Bar')),
            reason: 'Bar is used internally');
        expect(unusedSymbols, contains('Baz'),
            reason: 'Baz is not used anywhere');
      });
    });

    group('with unused_exports fixture', () {
      late FixtureHelper fixture;

      setUp(() {
        fixture = FixtureHelper(
          fixtureName: 'unused_exports',
          packageName: 'unused_exports',
        );
      });

      test('detects unused exports in fixture project', () {
        final projectFiles = fixture.buildFileSet([
          'lib/unused_exports.dart',
          'lib/src/models.dart',
          'lib/src/reexported.dart',
          'bin/main.dart',
        ]);

        final graph = fixture.graphBuilder.build(projectFiles);

        final detector = UnusedExportDetector(
          uriResolver: fixture.uriResolver,
          includeEntryExports: false,
        );

        final issues = detector.detect(
          projectFiles: projectFiles,
          entryFiles: {
            fixture.filePath('lib/unused_exports.dart'),
            fixture.filePath('bin/main.dart'),
          },
          graph: graph,
          rules: {IssueType.unusedExport: Severity.warn},
          ignoreDependencies: [],
        );

        expect(issues, isEmpty);
      });
    });
  });
}
