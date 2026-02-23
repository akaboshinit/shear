/// Generates a unified diff between [expected] and [actual] text.
///
/// Returns an empty string if the texts are identical.
/// Uses LCS (Longest Common Subsequence) for accurate line-by-line diff.
String generateDiff(String expected, String actual) {
  if (expected == actual) return '';

  final expectedLines = expected.split('\n');
  final actualLines = actual.split('\n');
  final lcs = _computeLcs(expectedLines, actualLines);

  final buffer = StringBuffer();
  var ei = 0;
  var ai = 0;
  var li = 0;

  while (ei < expectedLines.length || ai < actualLines.length) {
    final isCommon = li < lcs.length &&
        ei < expectedLines.length &&
        ai < actualLines.length &&
        expectedLines[ei] == lcs[li] &&
        actualLines[ai] == lcs[li];

    if (isCommon) {
      buffer.writeln('  ${expectedLines[ei]}');
      ei++;
      ai++;
      li++;
    } else if (ei < expectedLines.length &&
        (li >= lcs.length || expectedLines[ei] != lcs[li])) {
      buffer.writeln('- ${expectedLines[ei]}');
      ei++;
    } else if (ai < actualLines.length &&
        (li >= lcs.length || actualLines[ai] != lcs[li])) {
      buffer.writeln('+ ${actualLines[ai]}');
      ai++;
    }
  }

  return buffer.toString().trimRight();
}

/// Compute LCS of two lists of strings using dynamic programming.
List<String> _computeLcs(List<String> a, List<String> b) {
  final m = a.length;
  final n = b.length;

  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else if (dp[i - 1][j] > dp[i][j - 1]) {
        dp[i][j] = dp[i - 1][j];
      } else {
        dp[i][j] = dp[i][j - 1];
      }
    }
  }

  final result = <String>[];
  var i = m;
  var j = n;
  while (i > 0 && j > 0) {
    if (a[i - 1] == b[j - 1]) {
      result.add(a[i - 1]);
      i--;
      j--;
    } else if (dp[i - 1][j] > dp[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }

  return result.reversed.toList();
}
