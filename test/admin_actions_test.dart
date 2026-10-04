import 'package:flutter_test/flutter_test.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_actions.dart';

void main() {
  test('nairaToCents converts typed naira amounts to cents', () {
    expect(nairaToCents('5000'), 500000);
    expect(nairaToCents('5,000'), 500000);
    expect(nairaToCents(' 1500.50 '), 150050);
  });

  test('nairaToCents rejects anything that is not a positive amount', () {
    expect(nairaToCents(''), isNull);
    expect(nairaToCents('0'), isNull);
    expect(nairaToCents('-20'), isNull);
    expect(nairaToCents('abc'), isNull);
  });

  test('firstValue returns the first non-empty field', () {
    expect(firstValue({'a': '', 'b': 'x'}, const ['a', 'b']), 'x');
    expect(firstValue({'a': null}, const ['a']), '');
  });
}
