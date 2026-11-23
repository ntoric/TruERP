import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truerp_mobile/core/api/json.dart';
import 'package:truerp_mobile/core/api/paged.dart';
import 'package:truerp_mobile/core/config/app_config.dart';
import 'package:truerp_mobile/core/utils/formatters.dart';
import 'package:truerp_mobile/core/utils/validators.dart';

String _name(JsonMap j) => asString(j['name']);

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));

  group('Paged.parse', () {
    test('bare array is a single complete page', () {
      final p = Paged.parse([
        {'name': 'a'},
        {'name': 'b'},
      ], _name);
      expect(p.items, ['a', 'b']);
      expect(p.total, 2);
      expect(p.hasMore, isFalse);
    });

    test('keyed envelope with paging', () {
      final p = Paged.parse({
        'invoices': [
          {'name': 'x'},
        ],
        'total': 60,
        'page': 2,
        'per_page': 25,
      }, _name);
      expect(p.items, ['x']);
      expect(p.page, 2);
      expect(p.hasMore, isTrue);
    });

    test('data envelope and unknown keys', () {
      expect(
        Paged.parse({
          'data': [
            {'name': 'd'},
          ],
          'total': 1,
        }, _name).items,
        ['d'],
      );
      expect(
        Paged.parse({
          'whatever': [
            {'name': 'w'},
          ],
          'total': 1,
        }, _name).items,
        ['w'],
      );
    });

    test('explicit key wins over data', () {
      final p = Paged.parse(
        {
          'data': [
            {'name': 'no'},
          ],
          'payment_outs': [
            {'name': 'yes'},
          ],
        },
        _name,
        key: 'payment_outs',
      );
      expect(p.items, ['yes']);
    });

    test('last page has no more', () {
      final p = Paged.parse({
        'parties': [
          {'name': 'z'},
        ],
        'total': 51,
        'page': 3,
        'per_page': 25,
      }, _name);
      expect(p.hasMore, isFalse);
    });

    test('null body yields empty list', () {
      expect(Paged.parse(null, _name).items, isEmpty);
    });
  });

  group('json helpers', () {
    test('numbers from strings and nulls', () {
      expect(asDouble('12.5'), 12.5);
      expect(asDouble(null, 3), 3);
      expect(asInt('7'), 7);
      expect(asInt('7.9'), 7);
      expect(asBool('true'), isTrue);
      expect(asBool(1), isTrue);
    });

    test('zero dates are null', () {
      expect(asDate('0001-01-01T00:00:00Z'), isNull);
      expect(asDate('2026-04-01T00:00:00Z'), isNotNull);
      expect(asDate(''), isNull);
    });

    test('pick walks nested maps', () {
      expect(
        pick({
          'party': {'name': 'Acme'},
        }, 'party.name'),
        'Acme',
      );
      expect(pick({'party': null}, 'party.name'), isNull);
    });

    test('ymd pads', () => expect(ymd(DateTime(2026, 3, 5)), '2026-03-05'));
  });

  group('apiDate sends the chosen calendar day like the web', () {
    test('UTC midnight of the local date, whatever the time of day', () {
      expect(apiDate(DateTime(2026, 11, 1)), '2026-11-01T00:00:00.000Z');
      expect(
        apiDate(DateTime(2026, 11, 1, 23, 59)),
        '2026-11-01T00:00:00.000Z',
      );
      expect(apiDate(DateTime(2026, 11, 1, 0, 1)), '2026-11-01T00:00:00.000Z');
    });

    test('date-only values read back as the same calendar day', () {
      expect(asDate('2026-11-05T00:00:00Z'), DateTime(2026, 11, 5));
      expect(asDate('2026-11-05'), DateTime(2026, 11, 5));
      expect(asDate(apiDate(DateTime(2026, 2, 28))), DateTime(2026, 2, 28));
      // Real timestamps still convert to local time.
      expect(asDate('2026-11-05T10:30:00Z')!.isUtc, isFalse);
    });

    test('never shifts to the previous day (the IST bug)', () {
      // Local midnight converted to UTC would be 2026-10-31T18:30Z in India.
      expect(apiDate(DateTime(2026, 11, 1)).startsWith('2026-11-01'), isTrue);
      expect(apiDateOrNull(null), isNull);
    });
  });

  group('formatters', () {
    test('Indian grouping', () {
      expect(money(1234567.5), '₹12,34,567.50');
      expect(moneyShort(1500), '₹1,500');
    });

    test('compact money', () {
      expect(moneyCompact(950), '₹950');
      expect(moneyCompact(12500), '₹13K');
      expect(moneyCompact(250000), '₹2.5L');
      expect(moneyCompact(31000000), '₹3.1Cr');
      expect(moneyCompact(-2500), '-₹2.5K');
    });

    test('qty trims zeros', () {
      expect(qty(2), '2');
      expect(qty(2.5), '2.5');
      expect(qty(0.125), '0.125');
    });

    test(
      'titleCase',
      () => expect(titleCase('bank_transfer'), 'Bank Transfer'),
    );
  });

  group('server url', () {
    test('normalises common inputs', () {
      expect(
        AppConfig.normalizeServerUrl('backend.truerp.co.in'),
        'https://backend.truerp.co.in/api/v1',
      );
      expect(
        AppConfig.normalizeServerUrl('192.168.1.20:8088'),
        'http://192.168.1.20:8088/api/v1',
      );
      expect(AppConfig.normalizeServerUrl(''), AppConfig.productionServerUrl);
      expect(AppConfig.defaultServerUrl, 'https://backend.truerp.co.in/api/v1');
      expect(
        AppConfig.normalizeServerUrl('https://erp.example.com/'),
        'https://erp.example.com/api/v1',
      );
      expect(
        AppConfig.normalizeServerUrl('http://10.0.2.2:8088/api/v1'),
        'http://10.0.2.2:8088/api/v1',
      );
    });
  });

  group('validators', () {
    test('gstin', () {
      expect(Validators.optionalGstin('29ABCDE1234F1Z5'), isNull);
      expect(Validators.optionalGstin('bad'), isNotNull);
      expect(Validators.optionalGstin(''), isNull);
    });

    test('email and password', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.password('12345'), isNotNull);
    });

    test('number', () {
      expect(Validators.number('-1'), isNotNull);
      expect(Validators.number('0', allowZero: false), isNotNull);
      expect(Validators.number('', required: true), isNotNull);
      expect(Validators.number('3.5'), isNull);
    });
  });
}
