import 'package:test/test.dart';

import 'diff_util.dart';

void main() {
  group('generateDiff', () {
    test('returns empty string for identical inputs', () {
      expect(generateDiff('hello\nworld', 'hello\nworld'), isEmpty);
    });

    test('shows added lines with + prefix', () {
      const expected = 'line1\nline2';
      const actual = 'line1\nline2\nline3';
      final diff = generateDiff(expected, actual);
      expect(diff, contains('+ line3'));
    });

    test('shows removed lines with - prefix', () {
      const expected = 'line1\nline2\nline3';
      const actual = 'line1\nline2';
      final diff = generateDiff(expected, actual);
      expect(diff, contains('- line3'));
    });

    test('shows both added and removed lines', () {
      const expected = 'line1\nold\nline3';
      const actual = 'line1\nnew\nline3';
      final diff = generateDiff(expected, actual);
      expect(diff, contains('- old'));
      expect(diff, contains('+ new'));
    });

    test('shows common lines with space prefix', () {
      const expected = 'line1\nold\nline3';
      const actual = 'line1\nnew\nline3';
      final diff = generateDiff(expected, actual);
      expect(diff, contains('  line1'));
      expect(diff, contains('  line3'));
    });

    test('handles empty expected', () {
      const expected = '';
      const actual = 'line1\nline2';
      final diff = generateDiff(expected, actual);
      expect(diff, contains('+ line1'));
      expect(diff, contains('+ line2'));
    });

    test('handles empty actual', () {
      const expected = 'line1\nline2';
      const actual = '';
      final diff = generateDiff(expected, actual);
      expect(diff, contains('- line1'));
      expect(diff, contains('- line2'));
    });

    test('handles completely different content', () {
      const expected = 'aaa\nbbb';
      const actual = 'xxx\nyyy';
      final diff = generateDiff(expected, actual);
      expect(diff, contains('- aaa'));
      expect(diff, contains('- bbb'));
      expect(diff, contains('+ xxx'));
      expect(diff, contains('+ yyy'));
    });
  });
}
