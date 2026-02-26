import 'src/color.dart';
import 'src/status.dart';

void main() {
  final s = Status.active;
  print(s);

  // Using Color.values marks all members as used.
  for (final c in Color.values) {
    print(c);
  }
}
