/// HTML template constants for the HTML reporter.
abstract final class HtmlTemplate {
  /// Complete HTML template with placeholders for dynamic content.
  static const String template = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Shear Report</title>
  <style>
    :root {
      --color-bg: #f8fafc;
      --color-surface: #ffffff;
      --color-text: #0f172a;
      --color-text-secondary: #64748b;
      --color-border: #e2e8f0;
      --color-error: #ef4444;
      --color-error-bg: #fef2f2;
      --color-warn: #f59e0b;
      --color-warn-bg: #fffbeb;
      --color-success: #10b981;
      --color-success-bg: #ecfdf5;
      --color-unused-file: #6366f1;
      --color-unused-dep: #ec4899;
      --color-unused-export: #f97316;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --color-bg: #0f172a;
        --color-surface: #1e293b;
        --color-text: #f1f5f9;
        --color-text-secondary: #94a3b8;
        --color-border: #334155;
        --color-error: #f87171;
        --color-error-bg: #451a1a;
        --color-warn: #fbbf24;
        --color-warn-bg: #452a1a;
        --color-success: #34d399;
        --color-success-bg: #1a3a2a;
        --color-unused-file: #818cf8;
        --color-unused-dep: #f472b6;
        --color-unused-export: #fb923c;
      }
    }

    @media (prefers-reduced-motion: reduce) {
      *, *::before, *::after {
        animation-duration: 0.01ms !important;
        transition-duration: 0.01ms !important;
      }
    }

    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: var(--color-bg);
      color: var(--color-text);
      line-height: 1.6;
      padding: 2rem;
      max-width: 1200px;
      margin: 0 auto;
    }

    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(8px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .fade-in {
      animation: fadeIn 0.3s ease-out forwards;
    }

    header {
      text-align: center;
      margin-bottom: 2rem;
      padding-bottom: 1rem;
      border-bottom: 1px solid var(--color-border);
    }

    header h1 {
      font-size: 1.75rem;
      font-weight: 700;
      margin-bottom: 0.25rem;
    }

    header .generated-at {
      color: var(--color-text-secondary);
      font-size: 0.875rem;
    }

    /* Score + Summary Row */
    .dashboard {
      display: grid;
      grid-template-columns: 200px 1fr;
      gap: 1.5rem;
      margin-bottom: 2rem;
    }

    .health-score {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: var(--color-surface);
      border-radius: 12px;
      padding: 1.5rem;
      border: 1px solid var(--color-border);
    }

    .health-score .score-label {
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--color-text-secondary);
      margin-top: 0.5rem;
    }

    .summary-cards {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 0.75rem;
      margin-bottom: 0.75rem;
    }

    .summary-card {
      background: var(--color-surface);
      border-radius: 10px;
      padding: 1rem 1.25rem;
      border: 1px solid var(--color-border);
      text-align: center;
    }

    .summary-card .count {
      font-size: 2rem;
      font-weight: 700;
      line-height: 1.2;
    }

    .summary-card .label {
      font-size: 0.8rem;
      color: var(--color-text-secondary);
    }

    .summary-card.total .count { color: var(--color-text); }
    .summary-card.errors .count { color: var(--color-error); }
    .summary-card.warnings .count { color: var(--color-warn); }

    .category-cards {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 0.75rem;
    }

    .category-card {
      background: var(--color-surface);
      border-radius: 10px;
      padding: 0.875rem 1rem;
      border: 1px solid var(--color-border);
      border-left: 4px solid;
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }

    .category-card .icon {
      flex-shrink: 0;
      width: 32px;
      height: 32px;
    }

    .category-card .info .count {
      font-size: 1.375rem;
      font-weight: 700;
      line-height: 1.2;
    }

    .category-card .info .label {
      font-size: 0.7rem;
      color: var(--color-text-secondary);
    }

    .category-card.unused-file { border-left-color: var(--color-unused-file); }
    .category-card.unused-dep { border-left-color: var(--color-unused-dep); }
    .category-card.unused-export { border-left-color: var(--color-unused-export); }

    /* Charts Row */
    .charts {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1.5rem;
      margin-bottom: 2rem;
    }

    .chart-card {
      background: var(--color-surface);
      border-radius: 12px;
      padding: 1.5rem;
      border: 1px solid var(--color-border);
    }

    .chart-card h3 {
      font-size: 0.875rem;
      color: var(--color-text-secondary);
      margin-bottom: 1rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .chart-card .chart-container {
      display: flex;
      justify-content: center;
      align-items: center;
    }

    /* Filter Bar */
    .filters {
      display: flex;
      gap: 1rem;
      align-items: center;
      flex-wrap: wrap;
      margin-bottom: 1.5rem;
      padding: 1rem;
      background: var(--color-surface);
      border-radius: 10px;
      border: 1px solid var(--color-border);
    }

    .filters input[type="text"] {
      flex: 1;
      min-width: 200px;
      padding: 0.5rem 0.75rem;
      border: 1px solid var(--color-border);
      border-radius: 6px;
      font-size: 0.875rem;
      background: var(--color-bg);
      color: var(--color-text);
    }

    .filters input[type="text"]:focus {
      outline: none;
      border-color: #6366f1;
      box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.2);
    }

    .filter-group {
      display: flex;
      gap: 0.5rem;
      align-items: center;
    }

    .filter-group label {
      display: flex;
      align-items: center;
      gap: 0.25rem;
      font-size: 0.8rem;
      cursor: pointer;
      color: var(--color-text-secondary);
    }

    .filter-group .separator {
      width: 1px;
      height: 20px;
      background: var(--color-border);
      margin: 0 0.25rem;
    }

    /* Issue Sections */
    .issue-sections {
      display: flex;
      flex-direction: column;
      gap: 0.75rem;
    }

    details {
      background: var(--color-surface);
      border-radius: 10px;
      border: 1px solid var(--color-border);
      overflow: hidden;
    }

    summary {
      padding: 1rem 1.25rem;
      cursor: pointer;
      font-weight: 600;
      font-size: 0.95rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      user-select: none;
    }

    summary:hover {
      background: var(--color-bg);
    }

    summary .badge {
      font-size: 0.75rem;
      font-weight: 500;
      padding: 0.125rem 0.5rem;
      border-radius: 999px;
      color: white;
    }

    .issue-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.85rem;
    }

    .issue-table th {
      text-align: left;
      padding: 0.625rem 1.25rem;
      font-weight: 600;
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--color-text-secondary);
      border-bottom: 1px solid var(--color-border);
      background: var(--color-bg);
    }

    .issue-table td {
      padding: 0.5rem 1.25rem;
      border-bottom: 1px solid var(--color-border);
    }

    .issue-table tr:last-child td {
      border-bottom: none;
    }

    .issue-table .severity-badge {
      display: inline-block;
      padding: 0.125rem 0.5rem;
      border-radius: 4px;
      font-size: 0.75rem;
      font-weight: 600;
    }

    .severity-error .severity-badge {
      background: var(--color-error-bg);
      color: var(--color-error);
    }

    .severity-warn .severity-badge {
      background: var(--color-warn-bg);
      color: var(--color-warn);
    }

    .issue-table .file-path {
      font-family: 'SF Mono', SFMono-Regular, Consolas, monospace;
      font-size: 0.8rem;
    }

    .issue-table .symbol {
      font-family: 'SF Mono', SFMono-Regular, Consolas, monospace;
      font-size: 0.8rem;
      color: var(--color-text-secondary);
    }

    .no-issues {
      text-align: center;
      padding: 3rem;
      color: var(--color-success);
      font-size: 1.125rem;
    }

    .no-issues svg {
      margin-bottom: 0.5rem;
    }

    footer {
      text-align: center;
      margin-top: 2rem;
      padding-top: 1rem;
      border-top: 1px solid var(--color-border);
      font-size: 0.8rem;
      color: var(--color-text-secondary);
    }

    footer a {
      color: #6366f1;
      text-decoration: none;
    }

    footer a:hover {
      text-decoration: underline;
    }

    /* Responsive */
    @media (max-width: 768px) {
      body { padding: 1rem; }
      .dashboard { grid-template-columns: 1fr; }
      .category-cards { grid-template-columns: repeat(2, 1fr); }
      .charts { grid-template-columns: 1fr; }
      .filters { flex-direction: column; }
    }
  </style>
</head>
<body>
  <header class="fade-in">
    <h1>Shear Report</h1>
    <p class="generated-at">Generated at {{GENERATED_AT}}</p>
  </header>

  <div class="dashboard fade-in">
    <div class="health-score">
      {{HEALTH_DONUT_SVG}}
      <span class="score-label">Health Score</span>
    </div>
    <div>
      <div class="summary-cards">
        <div class="summary-card total">
          <div class="count">{{TOTAL_COUNT}}</div>
          <div class="label">Total Issues</div>
        </div>
        <div class="summary-card errors">
          <div class="count">{{ERROR_COUNT}}</div>
          <div class="label">Errors</div>
        </div>
        <div class="summary-card warnings">
          <div class="count">{{WARNING_COUNT}}</div>
          <div class="label">Warnings</div>
        </div>
      </div>
      <div class="category-cards">
        {{CATEGORY_CARDS_HTML}}
      </div>
    </div>
  </div>

  <div class="charts fade-in">
    <div class="chart-card">
      <h3>Issues by Type</h3>
      <div class="chart-container">
        {{TYPE_DONUT_SVG}}
      </div>
    </div>
    <div class="chart-card">
      <h3>Issues by Severity</h3>
      <div class="chart-container">
        {{SEVERITY_BAR_SVG}}
      </div>
    </div>
  </div>

  {{FILTER_AND_ISSUES_HTML}}

  <footer class="fade-in">
    <p>Generated by <a href="https://github.com/akaboshinit/shear">shear</a> v0.1.0</p>
  </footer>

  <script>
    var issuesData = {{ISSUES_JSON}};

    (function() {
      var searchInput = document.getElementById('search-input');
      var severityChecks = document.querySelectorAll('.severity-filter');
      var typeChecks = document.querySelectorAll('.type-filter');

      if (!searchInput) return;

      function applyFilters() {
        var query = searchInput.value.toLowerCase();
        var activeSeverities = [];
        severityChecks.forEach(function(cb) {
          if (cb.checked) activeSeverities.push(cb.value);
        });
        var activeTypes = [];
        typeChecks.forEach(function(cb) {
          if (cb.checked) activeTypes.push(cb.value);
        });

        var rows = document.querySelectorAll('.issue-row');
        rows.forEach(function(row) {
          var severity = row.getAttribute('data-severity');
          var type = row.getAttribute('data-type');
          var text = row.textContent.toLowerCase();

          var matchSearch = !query || text.indexOf(query) !== -1;
          var matchSeverity = activeSeverities.indexOf(severity) !== -1;
          var matchType = activeTypes.indexOf(type) !== -1;

          row.style.display = (matchSearch && matchSeverity && matchType) ? '' : 'none';
        });

        // Update section visibility and counts
        document.querySelectorAll('.issue-section').forEach(function(section) {
          var visibleRows = section.querySelectorAll('.issue-row[style=""], .issue-row:not([style])');
          var count = 0;
          section.querySelectorAll('.issue-row').forEach(function(r) {
            if (r.style.display !== 'none') count++;
          });
          var badge = section.querySelector('.visible-count');
          if (badge) badge.textContent = count;
        });
      }

      searchInput.addEventListener('input', applyFilters);
      severityChecks.forEach(function(cb) { cb.addEventListener('change', applyFilters); });
      typeChecks.forEach(function(cb) { cb.addEventListener('change', applyFilters); });
    })();
  </script>
</body>
</html>
''';
}
