import 'package:path/path.dart' as p;

/// A utility function that is used.
String joinPaths(String a, String b) => p.join(a, b);

/// A function that is exported but never imported directly.
String formatDate(DateTime date) => date.toIso8601String();
