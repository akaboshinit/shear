import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

import '../graph/module_graph.dart';
import 'delete_action.dart';
import 'delete_result.dart';

/// Removes unused public symbol declarations from Dart files using AST parsing.
class ExportDeleter {
  const ExportDeleter({required this.graph});

  final ModuleGraph graph;

  /// Execute a [RemoveSymbolAction] by parsing and editing the source file(s).
  Future<DeleteResult> execute(RemoveSymbolAction action) async {
    try {
      final remaining = Set<String>.from(action.symbolNames);
      final edits = <_FileEdit>[];

      // Search in the main file first.
      await _collectEdits(action.filePath, remaining, edits);

      // If symbols remain, search in part files.
      if (remaining.isNotEmpty) {
        final parts = graph.libraryToParts[action.filePath];
        if (parts != null) {
          for (final partPath in parts) {
            if (remaining.isEmpty) break;
            await _collectEdits(partPath, remaining, edits);
          }
        }
      }

      if (remaining.isNotEmpty) {
        return DeleteResult(
          action: action,
          success: false,
          error: 'Symbols not found: ${remaining.join(', ')}',
        );
      }

      // Apply edits grouped by file.
      await _applyEdits(edits);

      return DeleteResult(action: action, success: true);
    } catch (e) {
      return DeleteResult(
        action: action,
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _collectEdits(
    String filePath,
    Set<String> remaining,
    List<_FileEdit> edits,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final source = await file.readAsString();
    final result = parseString(content: source);
    final unit = result.unit;

    for (final declaration in unit.declarations) {
      final name = _declarationName(declaration);
      if (name == null || !remaining.contains(name)) continue;

      remaining.remove(name);

      // Include preceding doc comments and annotations.
      final startOffset = declaration.metadata.isNotEmpty
          ? declaration.metadata.first.offset
          : (declaration.documentationComment?.offset ?? declaration.offset);
      final endOffset = declaration.end;

      edits.add(_FileEdit(
        filePath: filePath,
        startOffset: startOffset,
        endOffset: endOffset,
      ));
    }
  }

  Future<void> _applyEdits(List<_FileEdit> edits) async {
    // Group by file path.
    final grouped = <String, List<_FileEdit>>{};
    for (final edit in edits) {
      grouped.putIfAbsent(edit.filePath, () => []).add(edit);
    }

    for (final entry in grouped.entries) {
      final file = File(entry.key);
      var source = await file.readAsString();

      // Sort by offset descending to apply from end to start.
      entry.value.sort((a, b) => b.startOffset - a.startOffset);

      for (final edit in entry.value) {
        // Remove the declaration and any trailing whitespace/newlines.
        var end = edit.endOffset;
        while (end < source.length && source[end] == '\n') {
          end++;
        }
        source = source.substring(0, edit.startOffset) + source.substring(end);
      }

      // Clean up excessive blank lines and trim leading/trailing newlines.
      source = source
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .replaceFirst(RegExp(r'^\n+'), '')
          .replaceFirst(RegExp(r'\n+$'), '');
      if (source.isNotEmpty) source += '\n';

      await file.writeAsString(source);
    }
  }

  String? _declarationName(CompilationUnitMember member) {
    return switch (member) {
      final ClassDeclaration d => d.name.lexeme,
      final MixinDeclaration d => d.name.lexeme,
      final EnumDeclaration d => d.name.lexeme,
      final FunctionDeclaration d => d.name.lexeme,
      final TopLevelVariableDeclaration d =>
        d.variables.variables.first.name.lexeme,
      final TypeAlias d => d.name.lexeme,
      final ExtensionTypeDeclaration d => d.name.lexeme,
      _ => null,
    };
  }
}

class _FileEdit {
  const _FileEdit({
    required this.filePath,
    required this.startOffset,
    required this.endOffset,
  });

  final String filePath;
  final int startOffset;
  final int endOffset;
}
