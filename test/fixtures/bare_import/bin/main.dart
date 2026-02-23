import 'package:bare_import/src/utils.dart';
import 'package:bare_import/src/models.dart';

void main() {
  final user = User('Alice');
  print(user.name);
  print(helperFunction());
  print(UserRole.admin);
}
