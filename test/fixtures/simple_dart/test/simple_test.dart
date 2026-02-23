import 'package:simple_dart/simple_dart.dart';
import 'package:test/test.dart';

void main() {
  test('joinPaths works', () {
    expect(joinPaths('a', 'b'), contains('b'));
  });
}
