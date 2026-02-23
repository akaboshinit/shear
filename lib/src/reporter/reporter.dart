import '../core/issue.dart';

/// Interface for reporting analysis results.
abstract class Reporter {
  /// Report the analysis results.
  void report(AnalysisResult result);
}
