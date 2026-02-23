import 'package:simple_dart/simple_dart.dart';

void main() {
  final result = joinPaths('hello', 'world');
  print(result);

  final users = [
    const User(name: 'Bob', age: 30),
    const User(name: 'Alice', age: 25),
  ];
  final sorted = sortUsers(users);
  print(sorted);
}
