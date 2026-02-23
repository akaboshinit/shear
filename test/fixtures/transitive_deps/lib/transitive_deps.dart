import 'package:path/path.dart';
import 'package:local_pkg/local_pkg.dart';

class App {
  final model = LocalModel(null as dynamic);

  String dir() => join('a', 'b');
}
