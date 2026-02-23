import 'package:shear/src/core/issue.dart';
import 'package:shear/src/deletion/delete_action.dart';
import 'package:shear/src/deletion/delete_planner.dart';
import 'package:shear/src/graph/module_graph.dart';
import 'package:test/test.dart';

void main() {
  group('DeletePlanner', () {
    late ModuleGraph graph;
    late DeletePlanner planner;

    setUp(() {
      graph = ModuleGraph();
      planner = DeletePlanner(
        projectRoot: '/project',
        graph: graph,
      );
    });

    group('unused files', () {
      test('converts unused file issue to DeleteFileAction', () {
        final issues = [
          const Issue(
            type: IssueType.unusedFile,
            severity: Severity.error,
            filePath: 'lib/src/unused.dart',
            message: 'Unused file',
          ),
        ];

        final actions = planner.plan(issues);

        expect(actions, hasLength(1));
        final action = actions.first as DeleteFileAction;
        expect(action.filePath, '/project/lib/src/unused.dart');
        expect(action.partFilePaths, isEmpty);
      });

      test('includes part files for library with parts', () {
        graph.addPartRelation(
          '/project/lib/src/unused_lib.dart',
          '/project/lib/src/unused_part.dart',
        );

        final issues = [
          const Issue(
            type: IssueType.unusedFile,
            severity: Severity.error,
            filePath: 'lib/src/unused_lib.dart',
            message: 'Unused file',
          ),
        ];

        final actions = planner.plan(issues);

        expect(actions, hasLength(1));
        final action = actions.first as DeleteFileAction;
        expect(action.filePath, '/project/lib/src/unused_lib.dart');
        expect(
          action.partFilePaths,
          ['/project/lib/src/unused_part.dart'],
        );
      });

      test('skips part file issues (handled by parent library)', () {
        graph.addPartRelation(
          '/project/lib/src/lib.dart',
          '/project/lib/src/part.dart',
        );

        final issues = [
          const Issue(
            type: IssueType.unusedFile,
            severity: Severity.error,
            filePath: 'lib/src/part.dart',
            message: 'Unused file',
          ),
        ];

        final actions = planner.plan(issues);

        expect(actions, isEmpty);
      });
    });

    group('unused dependencies', () {
      test('converts unused dependency to RemoveDependencyAction', () {
        final issues = [
          const Issue(
            type: IssueType.unusedDependency,
            severity: Severity.error,
            filePath: 'pubspec.yaml',
            message: 'Unused dependency: http',
            symbol: 'http',
          ),
        ];

        final actions = planner.plan(issues);

        expect(actions, hasLength(1));
        final action = actions.first as RemoveDependencyAction;
        expect(action.packageName, 'http');
        expect(action.isDev, isFalse);
      });

    });

    group('unused exports', () {
      test('converts unused export to RemoveSymbolAction', () {
        final issues = [
          const Issue(
            type: IssueType.unusedExport,
            severity: Severity.warn,
            filePath: 'lib/src/models.dart',
            message: 'Unused export: MyClass',
            symbol: 'MyClass',
          ),
        ];

        final actions = planner.plan(issues);

        expect(actions, hasLength(1));
        final action = actions.first as RemoveSymbolAction;
        expect(action.filePath, '/project/lib/src/models.dart');
        expect(action.symbolNames, ['MyClass']);
      });

      test('groups symbols from the same file', () {
        final issues = [
          const Issue(
            type: IssueType.unusedExport,
            severity: Severity.warn,
            filePath: 'lib/src/models.dart',
            message: 'Unused export: Foo',
            symbol: 'Foo',
          ),
          const Issue(
            type: IssueType.unusedExport,
            severity: Severity.warn,
            filePath: 'lib/src/models.dart',
            message: 'Unused export: Bar',
            symbol: 'Bar',
          ),
        ];

        final actions = planner.plan(issues);

        expect(actions, hasLength(1));
        final action = actions.first as RemoveSymbolAction;
        expect(action.filePath, '/project/lib/src/models.dart');
        expect(action.symbolNames, containsAll(['Foo', 'Bar']));
      });

      test('excludes export issues for files being deleted', () {
        final issues = [
          const Issue(
            type: IssueType.unusedFile,
            severity: Severity.error,
            filePath: 'lib/src/unused.dart',
            message: 'Unused file',
          ),
          const Issue(
            type: IssueType.unusedExport,
            severity: Severity.warn,
            filePath: 'lib/src/unused.dart',
            message: 'Unused export: Foo',
            symbol: 'Foo',
          ),
        ];

        final actions = planner.plan(issues);

        expect(actions, hasLength(1));
        expect(actions.first, isA<DeleteFileAction>());
      });
    });

    group('include filter', () {
      test('filters to files only', () {
        final issues = [
          const Issue(
            type: IssueType.unusedFile,
            severity: Severity.error,
            filePath: 'lib/src/unused.dart',
            message: 'Unused file',
          ),
          const Issue(
            type: IssueType.unusedDependency,
            severity: Severity.error,
            filePath: 'pubspec.yaml',
            message: 'Unused dependency: http',
            symbol: 'http',
          ),
        ];

        final actions = planner.plan(issues, include: {'files'});

        expect(actions, hasLength(1));
        expect(actions.first, isA<DeleteFileAction>());
      });

      test('filters to dependencies only', () {
        final issues = [
          const Issue(
            type: IssueType.unusedFile,
            severity: Severity.error,
            filePath: 'lib/src/unused.dart',
            message: 'Unused file',
          ),
          const Issue(
            type: IssueType.unusedDependency,
            severity: Severity.error,
            filePath: 'pubspec.yaml',
            message: 'Unused dependency: http',
            symbol: 'http',
          ),
        ];

        final actions = planner.plan(issues, include: {'dependencies'});

        expect(actions, hasLength(1));
        expect(actions.first, isA<RemoveDependencyAction>());
      });

      test('filters to exports only', () {
        final issues = [
          const Issue(
            type: IssueType.unusedFile,
            severity: Severity.error,
            filePath: 'lib/src/unused.dart',
            message: 'Unused file',
          ),
          const Issue(
            type: IssueType.unusedExport,
            severity: Severity.warn,
            filePath: 'lib/src/models.dart',
            message: 'Unused export: Foo',
            symbol: 'Foo',
          ),
        ];

        final actions = planner.plan(issues, include: {'exports'});

        expect(actions, hasLength(1));
        expect(actions.first, isA<RemoveSymbolAction>());
      });
    });

    test('returns empty list for empty issues', () {
      final actions = planner.plan([]);
      expect(actions, isEmpty);
    });

    test('deduplicates file actions', () {
      final issues = [
        const Issue(
          type: IssueType.unusedFile,
          severity: Severity.error,
          filePath: 'lib/src/unused.dart',
          message: 'Unused file',
        ),
        const Issue(
          type: IssueType.unusedFile,
          severity: Severity.warn,
          filePath: 'lib/src/unused.dart',
          message: 'Unused file (dup)',
        ),
      ];

      final actions = planner.plan(issues);

      expect(actions, hasLength(1));
    });

    test('skips dependency issues without symbol', () {
      final issues = [
        const Issue(
          type: IssueType.unusedDependency,
          severity: Severity.error,
          filePath: 'pubspec.yaml',
          message: 'Unused dependency',
        ),
      ];

      final actions = planner.plan(issues);
      expect(actions, isEmpty);
    });

    test('skips export issues without symbol', () {
      final issues = [
        const Issue(
          type: IssueType.unusedExport,
          severity: Severity.warn,
          filePath: 'lib/src/models.dart',
          message: 'Unused export',
        ),
      ];

      final actions = planner.plan(issues);
      expect(actions, isEmpty);
    });
  });
}
