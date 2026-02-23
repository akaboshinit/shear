class User {
  final String name;
  const User(this.name);
}

class Admin extends User {
  const Admin(super.name);
}

enum UserRole { admin, editor, viewer }
