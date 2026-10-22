import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  group('ZolnitNode', () {
    test(
      'reads a flag prefix as the country and keeps it out of the title',
      () {
        final node = ZolnitNode.fromJson({
          'id': 7,
          'name': '\u{1F1ED}\u{1F1F0} 香港 · 轻风 01',
          'rate': '1.25',
          'tags': ['优选线路', ' ', 3],
          'is_online': 1,
        });
        expect(node.id, '7');
        expect(node.countryCode, 'HK');
        expect(node.region, '香港');
        expect(node.title, '香港 · 轻风 01');
        expect(node.flag, '\u{1F1ED}\u{1F1F0}');
        expect(node.rateText, '1.25');
        expect(node.tags, ['优选线路']);
        expect(node.online, isTrue);
      },
    );

    test('finds the region of an unflagged name', () {
      expect(ZolnitNode.fromJson({'name': 'Tokyo – Premium'}).region, '日本');
      expect(ZolnitNode.fromJson({'name': 'US West 02'}).countryCode, 'US');
      expect(ZolnitNode.fromJson({'name': 'Hong Kong 01'}).countryCode, 'HK');
      expect(ZolnitNode.fromJson({'name': '新加坡 · 狮城 02'}).countryCode, 'SG');
    });

    test('keeps an unknown region readable and claims nothing else', () {
      final node = ZolnitNode.fromJson({'id': 'n-1', 'name': 'Atlantis Prime'});
      expect(node.id, 'n-1');
      expect(node.region, 'Atlantis');
      expect(node.countryCode, isNull);
      expect(node.flag, isNull);
      expect(node.online, isNull);
      expect(node.rateText, '1');
      expect(
        ZolnitNode.fromJson({'name': 'x', 'is_online': 0}).online,
        isFalse,
      );
      expect(ZolnitNode.fromJson({'name': 'x', 'rate': 0.5}).rateText, '0.5');
    });
  });

  group('ZolnitPlan', () {
    test('keeps positive prices and reads the panel content as lines', () {
      final plan = ZolnitPlan.fromJson({
        'id': '3',
        'name': ' 轻享 ',
        'content': '<ul><li>每月 150 GB</li><li>2 台设备</li></ul>',
        'transfer_enable': 150,
        'device_limit': 2,
        'speed_limit': null,
        'month_price': 3800,
        'quarter_price': 0,
        'year_price': 36480,
        'onetime_price': null,
      });
      expect(plan.id, 3);
      expect(plan.name, '轻享');
      expect(plan.prices, {'month_price': 3800, 'year_price': 36480});
      expect(plan.transferGb, 150);
      expect(plan.deviceLimit, 2);
      expect(plan.speedLimitMbps, isNull);
      expect(plan.contentLines, ['每月 150 GB', '2 台设备']);
    });

    test('reads GB, legacy KB and byte quotas as gigabytes', () {
      double? gigabytes(num raw) =>
          ZolnitPlan.fromJson({'name': 'x', 'transfer_enable': raw}).transferGb;
      expect(gigabytes(100), 100);
      expect(gigabytes(10485760), 10);
      expect(gigabytes(107374182400), 100);
      expect(gigabytes(0), isNull);
    });

    test('works out the saving against monthly payments in whole numbers', () {
      final plan = ZolnitPlan.fromJson({
        'name': 'x',
        'month_price': 1000,
        'quarter_price': 2700,
        'year_price': 12000,
      });
      expect(plan.savingPercent('quarter_price'), 10);
      expect(plan.savingPercent('year_price'), isNull);
      expect(plan.savingPercent('month_price'), isNull);
      expect(plan.savingPercent('half_year_price'), isNull);
    });
  });

  group('plainLines', () {
    test('splits markup, entities and list markers', () {
      expect(plainLines('<p>香港节点已优化</p><p>订阅 &amp; 重连</p><p>- 第三行</p>'), [
        '香港节点已优化',
        '订阅 & 重连',
        '第三行',
      ]);
    });

    test('reads a JSON array and leaves bracketed text alone', () {
      expect(plainLines('["第一行", "第二行"]'), ['第一行', '第二行']);
      expect(plainLines('[重要] 维护通知'), ['[重要] 维护通知']);
    });

    test('limits the number of lines and their length', () {
      expect(plainLines('a' * 100, maxLength: 10), ['aaaaaaaaa…']);
      expect(plainLines('1\n2\n3\n4', maxLines: 2), ['1', '2']);
      expect(plainLines(null), isEmpty);
    });
  });

  group('ZolnitNotice', () {
    test('turns panel content into plain text with a UTC date', () {
      final notice = ZolnitNotice.fromJson({
        'id': 5,
        'title': '线路更新',
        'content': '<p>香港节点已优化</p><p>请重新连接</p>',
        'tags': ['线路动态'],
        'created_at': DateTime.utc(2025, 10, 20).millisecondsSinceEpoch ~/ 1000,
      });
      expect(notice.id, '5');
      expect(notice.title, '线路更新');
      expect(notice.body, '香港节点已优化\n请重新连接');
      expect(notice.tags, ['线路动态']);
      expect(notice.createdAt, DateTime.utc(2025, 10, 20));
    });
  });

  group('ZolnitUsage', () {
    final expires = DateTime.utc(2025, 11, 20);
    final subscription = {
      'plan_id': 3,
      'plan': {'id': 3, 'name': '轻享', 'device_limit': 2},
      'u': 1073741824,
      'd': '2147483648',
      'transfer_enable': 10737418240,
      'expired_at': expires.millisecondsSinceEpoch ~/ 1000,
      'alive_ip': 1,
      'email': 'lin@example.com',
    };

    test('sums both directions and rounds the days left up', () {
      final usage = ZolnitUsage.fromSubscription(subscription);
      expect(usage.usedBytes, 3221225472);
      expect(usage.totalBytes, 10737418240);
      expect(usage.remainingBytes, 7516192768);
      expect(usage.fraction, closeTo(0.3, 1e-9));
      expect(usage.expiresAt, expires);
      expect(usage.daysLeftAt(DateTime.utc(2025, 11, 18, 12)), 2);
      expect(usage.deviceLimit, 2);
      expect(usage.onlineDevices, 1);
      expect(usage.planName, '轻享');
      expect(usage.hasPlan, isTrue);
    });

    test('reports zero days after expiry and none without an expiry', () {
      final lapsed = ZolnitUsage.fromSubscription(subscription);
      expect(lapsed.daysLeftAt(DateTime.utc(2025, 12)), 0);
      final open = ZolnitUsage.fromSubscription({
        ...subscription,
        'expired_at': null,
      });
      expect(open.expiresAt, isNull);
      expect(open.daysLeftAt(DateTime.utc(2025, 11, 18)), isNull);
    });

    test('does not claim a plan or quota the panel did not send', () {
      final usage = ZolnitUsage.fromSubscription({'plan_id': null, 'u': -5});
      expect(usage.hasPlan, isFalse);
      expect(usage.usedBytes, 0);
      expect(usage.totalBytes, 0);
      expect(usage.fraction, 0);
      expect(usage.remainingBytes, 0);
      expect(usage.deviceLimit, isNull);
    });
  });

  test('formatBytes picks a unit and never prints a broken number', () {
    expect(formatBytes(0).toString(), '0.00 GB');
    expect(formatBytes(5 * 1048576).toString(), '5.00 MB');
    expect(formatBytes(3 * 1073741824).toString(), '3.00 GB');
    expect(formatBytes(2 * 1099511627776).toString(), '2.00 TB');
    expect(formatBytes(double.nan).toString(), '0.00 GB');
    expect(formatBytes(-5).toString(), '0.00 GB');
  });
}
