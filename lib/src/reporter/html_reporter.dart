import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../core/issue.dart';
import 'html_template.dart';
import 'reporter.dart';

/// Dashboard-style HTML output reporter.
class HtmlReporter implements Reporter {
  const HtmlReporter({StringSink? sink}) : _sink = sink;

  final StringSink? _sink;

  StringSink get _out => _sink ?? stdout;

  @override
  void report(AnalysisResult result) {
    _out.write(_buildHtml(result));
  }

  String _buildHtml(AnalysisResult result) {
    final grouped = result.groupedByType;
    final typeCounts = {
      for (final type in IssueType.values)
        type: grouped[type]?.length ?? 0,
    };
    final score = _computeHealthScore(result);
    final color = _healthColor(score);

    var html = HtmlTemplate.template;
    html = html
        .replaceAll('{{GENERATED_AT}}', _escapeHtml(DateTime.now().toIso8601String()))
        .replaceAll('{{TOTAL_COUNT}}', '${result.totalCount}')
        .replaceAll('{{ERROR_COUNT}}', '${result.errorCount}')
        .replaceAll('{{WARNING_COUNT}}', '${result.warningCount}')
        .replaceAll('{{HEALTH_DONUT_SVG}}', _buildHealthDonutSvg(score, color))
        .replaceAll('{{HEALTH_SCORE}}', '$score')
        .replaceAll('{{HEALTH_COLOR}}', color)
        .replaceAll('{{CATEGORY_CARDS_HTML}}', _buildCategoryCards(typeCounts))
        .replaceAll('{{TYPE_DONUT_SVG}}', _buildTypeDonutSvg(typeCounts, result.totalCount))
        .replaceAll('{{SEVERITY_BAR_SVG}}', _buildSeverityBarSvg(result.errorCount, result.warningCount))
        .replaceAll('{{FILTER_AND_ISSUES_HTML}}', _buildFilterAndIssues(result, grouped))
        .replaceAll('{{ISSUES_JSON}}', _buildIssuesJson(result));

    return html;
  }

  int _computeHealthScore(AnalysisResult result) {
    return max(0, 100 - (result.errorCount * 5 + result.warningCount * 2));
  }

  String _healthColor(int score) {
    if (score >= 80) return '#10b981';
    if (score >= 50) return '#f59e0b';
    return '#ef4444';
  }

  String _buildHealthDonutSvg(int score, String color) {
    const radius = 45.0;
    const circumference = 2 * pi * radius;
    final offset = circumference * (1 - score / 100);

    return '''
<svg width="120" height="120" viewBox="0 0 120 120">
  <circle cx="60" cy="60" r="$radius" fill="none" stroke="var(--color-border)" stroke-width="10"/>
  <circle cx="60" cy="60" r="$radius" fill="none" stroke="$color" stroke-width="10"
    stroke-dasharray="${circumference.toStringAsFixed(2)}"
    stroke-dashoffset="${offset.toStringAsFixed(2)}"
    stroke-linecap="round"
    transform="rotate(-90 60 60)"/>
  <text x="60" y="56" text-anchor="middle" font-size="28" font-weight="700" fill="$color">$score</text>
  <text x="60" y="74" text-anchor="middle" font-size="12" fill="var(--color-text-secondary)">/100</text>
</svg>''';
  }

  String _buildTypeDonutSvg(Map<IssueType, int> counts, int total) {
    if (total == 0) {
      return '''
<svg width="200" height="200" viewBox="0 0 200 200">
  <circle cx="100" cy="100" r="70" fill="none" stroke="var(--color-border)" stroke-width="24"/>
  <text x="100" y="96" text-anchor="middle" font-size="28" font-weight="700" fill="var(--color-text)">0</text>
  <text x="100" y="116" text-anchor="middle" font-size="12" fill="var(--color-text-secondary)">issues</text>
</svg>''';
    }

    const radius = 70.0;
    const circumference = 2 * pi * radius;
    final segments = StringBuffer();
    var currentOffset = 0.0;

    for (final type in IssueType.values) {
      final count = counts[type] ?? 0;
      if (count == 0) continue;

      final fraction = count / total;
      final length = circumference * fraction;
      final gap = circumference - length;

      segments.writeln(
        '  <circle cx="100" cy="100" r="$radius" fill="none" '
        'stroke="${_cssColorForType(type)}" stroke-width="24" '
        'stroke-dasharray="${length.toStringAsFixed(2)} ${gap.toStringAsFixed(2)}" '
        'stroke-dashoffset="${(-currentOffset).toStringAsFixed(2)}" '
        'transform="rotate(-90 100 100)"/>',
      );
      currentOffset += length;
    }

    return '''
<svg width="200" height="200" viewBox="0 0 200 200">
$segments  <text x="100" y="96" text-anchor="middle" font-size="28" font-weight="700" fill="var(--color-text)">$total</text>
  <text x="100" y="116" text-anchor="middle" font-size="12" fill="var(--color-text-secondary)">issues</text>
</svg>''';
  }

  String _buildSeverityBarSvg(int errors, int warnings) {
    final total = errors + warnings;
    if (total == 0) {
      return '''
<svg width="400" height="60" viewBox="0 0 400 60">
  <rect x="0" y="15" width="400" height="30" rx="6" fill="var(--color-border)"/>
  <text x="200" y="35" text-anchor="middle" font-size="12" fill="var(--color-text-secondary)">No issues</text>
</svg>''';
    }

    final errorWidth = (errors / total * 360).round();
    final warnWidth = (warnings / total * 360).round();
    final errorRx = (errors > 0 && warnings == 0) ? 6 : 0;
    final warnRx = (warnings > 0 && errors == 0) ? 6 : 0;

    final buf = StringBuffer()
      ..writeln('<svg width="400" height="60" viewBox="0 0 400 60">')
      ..writeln('  <rect x="20" y="15" width="$errorWidth" height="30" rx="$errorRx" fill="var(--color-error)"/>')
      ..writeln('  <rect x="${20 + errorWidth}" y="15" width="$warnWidth" height="30" rx="$warnRx" fill="var(--color-warn)"/>');

    if (errors > 0) {
      final x = 20 + errorWidth / 2;
      buf.writeln('  <text x="$x" y="35" text-anchor="middle" font-size="12" font-weight="600" fill="white">$errors errors</text>');
    }
    if (warnings > 0) {
      final x = 20 + errorWidth + warnWidth / 2;
      buf.writeln('  <text x="$x" y="35" text-anchor="middle" font-size="12" font-weight="600" fill="white">$warnings warnings</text>');
    }

    buf.write('</svg>');
    return buf.toString();
  }

  String _buildCategoryCards(Map<IssueType, int> counts) {
    const configs = [
      (IssueType.unusedFile, 'unused-file', 'Files', _fileIcon),
      (IssueType.unusedDependency, 'unused-dep', 'Dependencies', _packageIcon),
      (IssueType.unusedExport, 'unused-export', 'Exports', _codeIcon),
    ];

    final buf = StringBuffer();
    for (final (type, cssClass, label, icon) in configs) {
      final count = counts[type] ?? 0;
      buf.writeln('''
        <div class="category-card $cssClass">
          <div class="icon">$icon</div>
          <div class="info">
            <div class="count">$count</div>
            <div class="label">$label</div>
          </div>
        </div>''');
    }
    return buf.toString();
  }

  String _buildFilterAndIssues(
    AnalysisResult result,
    Map<IssueType, List<Issue>> grouped,
  ) {
    if (result.issues.isEmpty) {
      return '''
  <div class="no-issues fade-in">
    <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--color-success)" stroke-width="2">
      <circle cx="12" cy="12" r="10"/>
      <path d="M8 12l2.5 2.5L16 9"/>
    </svg>
    <p>No issues found</p>
  </div>''';
    }

    final buf = StringBuffer();

    // Filter bar
    buf.writeln('''
  <div class="filters fade-in">
    <input type="text" id="search-input" placeholder="Search files and symbols...">
    <div class="filter-group">
      <label><input type="checkbox" class="severity-filter" value="error" checked> Error</label>
      <label><input type="checkbox" class="severity-filter" value="warn" checked> Warning</label>
      <div class="separator"></div>
      <label><input type="checkbox" class="type-filter" value="unusedFile" checked> Files</label>
      <label><input type="checkbox" class="type-filter" value="unusedDependency" checked> Deps</label>
      <label><input type="checkbox" class="type-filter" value="unusedExport" checked> Exports</label>
    </div>
  </div>''');

    // Issue sections
    buf.writeln('  <div class="issue-sections fade-in">');
    for (final type in IssueType.values) {
      final issues = grouped[type];
      if (issues == null || issues.isEmpty) continue;

      final badgeColor = _cssColorForType(type);
      buf.writeln('''
    <details open class="issue-section" data-type="${type.name}">
      <summary>
        ${_escapeHtml(type.label)}
        <span class="badge" style="background:$badgeColor"><span class="visible-count">${issues.length}</span></span>
      </summary>
      <table class="issue-table">
        <thead>
          <tr><th>Severity</th><th>File</th><th>Symbol</th><th>Message</th></tr>
        </thead>
        <tbody>''');

      for (final issue in issues) {
        buf.writeln('''
          <tr class="issue-row severity-${issue.severity.name}" data-severity="${issue.severity.name}" data-type="${issue.type.name}">
            <td><span class="severity-badge">${issue.severity.name}</span></td>
            <td class="file-path">${_escapeHtml(issue.filePath)}</td>
            <td class="symbol">${issue.symbol != null ? _escapeHtml(issue.symbol!) : '—'}</td>
            <td>${_escapeHtml(issue.message)}</td>
          </tr>''');
      }

      buf.writeln('''
        </tbody>
      </table>
    </details>''');
    }
    buf.writeln('  </div>');

    return buf.toString();
  }

  String _buildIssuesJson(AnalysisResult result) {
    final list = result.issues
        .map((i) => {
              'type': i.type.name,
              'severity': i.severity.name,
              'filePath': i.filePath,
              if (i.symbol != null) 'symbol': i.symbol,
              'message': i.message,
            })
        .toList();

    // Escape < to prevent XSS when JSON is embedded in <script> tags.
    return jsonEncode(list).replaceAll('<', r'\u003c');
  }

  static const _htmlEscape = HtmlEscape();

  String _escapeHtml(String input) => _htmlEscape.convert(input);

  static String _cssColorForType(IssueType type) {
    return switch (type) {
      IssueType.unusedFile => 'var(--color-unused-file)',
      IssueType.unusedDependency => 'var(--color-unused-dep)',
      IssueType.unusedExport => 'var(--color-unused-export)',
    };
  }

  static const _fileIcon = '''
<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/>
  <path d="M14 2v6h6"/>
</svg>''';

  static const _packageIcon = '''
<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
  <path d="m16.5 9.4-9-5.19M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
  <path d="M3.27 6.96 12 12.01l8.73-5.05M12 22.08V12"/>
</svg>''';

  static const _codeIcon = '''
<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
  <polyline points="16 18 22 12 16 6"/>
  <polyline points="8 6 2 12 8 18"/>
</svg>''';
}
