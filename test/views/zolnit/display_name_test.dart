import 'package:fl_clash/views/zolnit/connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  test('the greeting name is the first word of the account email', () {
    expect(zolnitDisplayName({'email': 'lin@example.com'}, null), 'Lin');
    expect(zolnitDisplayName({'email': 'zhang.wei+tag@x.cn'}, null), 'Zhang');
    expect(zolnitDisplayName({'email': '.hidden_name@x.cn'}, null), 'Hidden');
  });

  test('it falls back to the subscription email and then to the brand', () {
    final usage = ZolnitUsage.fromSubscription({'email': 'mei@example.com'});
    expect(zolnitDisplayName(null, usage), 'Mei');
    expect(zolnitDisplayName({'email': ''}, usage), 'Mei');
    expect(zolnitDisplayName(null, null), 'ZolNit');
    expect(zolnitDisplayName({'email': '@example.com'}, null), 'ZolNit');
  });

  test('it never splits a character in the middle', () {
    expect(
      zolnitDisplayName({'email': '\u{1F600}smile@x.com'}, null),
      '\u{1F600}smile',
    );
  });
}
