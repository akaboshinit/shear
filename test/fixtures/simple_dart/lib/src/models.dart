import 'package:collection/collection.dart';

/// A model class that is used.
class User {
  const User({required this.name, required this.age});

  final String name;
  final int age;
}

/// A function that uses collection.
List<User> sortUsers(List<User> users) {
  return users.sortedBy((u) => u.name);
}
