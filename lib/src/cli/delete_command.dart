import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/shear_analyzer.dart';
import '../deletion/delete_action.dart';
import '../deletion/delete_executor.dart';
import '../deletion/delete_planner.dart';
import '../deletion/delete_result.dart';

/// The 'delete' command that removes detected unused code.
class DeleteCommand extends Command<int> {
  DeleteCommand() {
    argParser
      ..addMultiOption(
        'include',
        help: 'Categories to delete.',
        allowed: ['files', 'dependencies', 'exports'],
        defaultsTo: ['files', 'dependencies', 'exports'],
      )
      ..addFlag(
        'dry-run',
        help: 'Preview changes without modifying files.',
        defaultsTo: false,
      )
      ..addFlag(
        'force',
        help: 'Skip confirmation prompt.',
        defaultsTo: false,
      )
      ..addFlag(
        'verbose',
        help: 'Show detailed output.',
        defaultsTo: false,
      );
  }

  @override
  String get name => 'delete';

  @override
  String get description => 'Delete detected unused code from the project.';

  @override
  Future<int> run() async {
    final projectRoot =
        globalResults?['directory'] as String? ?? Directory.current.path;
    final absolute = p.canonicalize(projectRoot);
    final verbose = argResults!['verbose'] as bool;
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final include = (argResults!['include'] as List<String>).toSet();

    if (verbose) {
      stderr.writeln('Analyzing $absolute...');
    }

    // 1. Run analysis.
    const analyzer = ShearAnalyzer();
    final result = await analyzer.analyze(absolute);

    if (result.graph == null) {
      stderr.writeln('Error: Analysis did not produce a module graph.');
      return 1;
    }

    // 2. Plan deletions.
    final planner = DeletePlanner(
      projectRoot: absolute,
      graph: result.graph!,
    );
    final actions = planner.plan(result.issues, include: include);

    if (actions.isEmpty) {
      stdout.writeln('No unused code found. Nothing to delete.');
      return 0;
    }

    // 3. Show plan.
    _printPlan(actions, verbose: verbose);

    // 4. Dry run stops here.
    if (dryRun) {
      stdout.writeln('\n(dry-run mode — no changes made)');
      return 0;
    }

    // 5. Confirm unless forced.
    if (!force) {
      stdout.write('\nProceed with deletion? [y/N] ');
      final input = stdin.readLineSync()?.trim().toLowerCase();
      if (input != 'y' && input != 'yes') {
        stdout.writeln('Aborted.');
        return 0;
      }
    }

    // 6. Execute.
    final executor = DeleteExecutor(
      projectRoot: absolute,
      graph: result.graph!,
    );
    final summary = await executor.execute(actions);

    // 7. Print summary.
    _printSummary(summary);

    return summary.hasFailures ? 1 : 0;
  }

  void _printPlan(List<DeleteAction> actions, {required bool verbose}) {
    final fileActions = actions.whereType<DeleteFileAction>().toList();
    final depActions = actions.whereType<RemoveDependencyAction>().toList();
    final symbolActions = actions.whereType<RemoveSymbolAction>().toList();

    stdout.writeln('Planned deletions:');

    if (fileActions.isNotEmpty) {
      stdout.writeln('\n  Files (${fileActions.length}):');
      for (final action in fileActions) {
        stdout.writeln('    - ${action.filePath}');
        if (verbose) {
          for (final part in action.partFilePaths) {
            stdout.writeln('      + $part');
          }
        }
      }
    }

    if (symbolActions.isNotEmpty) {
      stdout.writeln('\n  Unused exports (${symbolActions.length} files):');
      for (final action in symbolActions) {
        stdout.writeln(
          '    - ${action.filePath}: ${action.symbolNames.join(', ')}',
        );
      }
    }

    if (depActions.isNotEmpty) {
      stdout.writeln('\n  Dependencies (${depActions.length}):');
      for (final action in depActions) {
        final section = action.isDev ? 'dev_dependencies' : 'dependencies';
        stdout.writeln('    - ${action.packageName} ($section)');
      }
    }
  }

  void _printSummary(DeletionSummary summary) {
    stdout.writeln('\nDeletion complete:');
    if (summary.filesDeleted > 0) {
      stdout.writeln('  ${summary.filesDeleted} file(s) deleted');
    }
    if (summary.symbolsRemoved > 0) {
      stdout.writeln('  ${summary.symbolsRemoved} export(s) removed');
    }
    if (summary.depsRemoved > 0) {
      stdout.writeln('  ${summary.depsRemoved} dependency(ies) removed');
    }

    if (summary.hasFailures) {
      stderr.writeln('\nFailures:');
      for (final result in summary.results.where((r) => !r.success)) {
        stderr.writeln('  - ${result.action.description}: ${result.error}');
      }
    }
  }
}
