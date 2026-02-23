import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';

class LocalModel {
  final Int64 id;
  LocalModel(this.id);

  List<int> sorted(List<int> items) => items.sorted();
}
