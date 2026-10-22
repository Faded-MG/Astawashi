import 'package:astawash/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBirrToSantim & tryParseBirrToSantim', () {
    group('whole birr', () {
      test('parses positive whole birr amounts', () {
        expect(parseBirrToSantim('25'), equals(2500));
        expect(parseBirrToSantim('1'), equals(100));
        expect(parseBirrToSantim('100'), equals(10000));
        expect(parseBirrToSantim('+50'), equals(5000));
      });

      test('parses negative whole birr when allowNegative is true', () {
        expect(parseBirrToSantim('-25'), equals(-2500));
        expect(parseBirrToSantim('-1'), equals(-100));
      });

      test('parses numbers with leading zeros', () {
        expect(parseBirrToSantim('007'), equals(700));
        expect(parseBirrToSantim('05'), equals(500));
        expect(parseBirrToSantim('000'), equals(0));
      });

      test('trims surrounding whitespace', () {
        expect(parseBirrToSantim('  25  '), equals(2500));
        expect(parseBirrToSantim('\t100\n'), equals(10000));
      });
    });

    group('fractional birr', () {
      test('parses one decimal digit as tenths (multiplied by 10)', () {
        expect(parseBirrToSantim('25.5'), equals(2550));
        expect(parseBirrToSantim('0.5'), equals(50));
        expect(parseBirrToSantim('1.1'), equals(110));
        expect(parseBirrToSantim('-0.5'), equals(-50));
      });

      test('parses two decimal digits as hundredths', () {
        expect(parseBirrToSantim('25.50'), equals(2550));
        expect(parseBirrToSantim('25.05'), equals(2505));
        expect(parseBirrToSantim('0.01'), equals(1));
        expect(parseBirrToSantim('0.99'), equals(99));
        expect(parseBirrToSantim('+25.50'), equals(2550));
        expect(parseBirrToSantim('-25.50'), equals(-2550));
        expect(parseBirrToSantim('-0.05'), equals(-5));
        expect(parseBirrToSantim('-0.50'), equals(-50));
      });

      test('parses leading dot with omitted whole portion', () {
        expect(parseBirrToSantim('.5'), equals(50));
        expect(parseBirrToSantim('.50'), equals(50));
        expect(parseBirrToSantim('.05'), equals(5));
        expect(parseBirrToSantim('+.25'), equals(25));
        expect(parseBirrToSantim('-.50'), equals(-50));
        expect(parseBirrToSantim('-.05'), equals(-5));
      });

      test('parses trailing dot with omitted fraction portion', () {
        expect(parseBirrToSantim('25.'), equals(2500));
        expect(parseBirrToSantim('-25.'), equals(-2500));
        expect(parseBirrToSantim('0.'), equals(0));
      });
    });

    group('zero values', () {
      test('parses various zero representations to 0 santim', () {
        expect(parseBirrToSantim('0'), equals(0));
        expect(parseBirrToSantim('+0'), equals(0));
        expect(parseBirrToSantim('-0'), equals(0));
        expect(parseBirrToSantim('0.0'), equals(0));
        expect(parseBirrToSantim('0.00'), equals(0));
        expect(parseBirrToSantim('+0.00'), equals(0));
        expect(parseBirrToSantim('-0.00'), equals(0));
        expect(parseBirrToSantim('.0'), equals(0));
        expect(parseBirrToSantim('.00'), equals(0));
      });

      test('tryParseBirrToSantim succeeds on zero representations', () {
        expect(tryParseBirrToSantim('0'), equals(0));
        expect(tryParseBirrToSantim('-0.00'), equals(0));
      });
    });

    group('invalid input', () {
      test('throws on empty or whitespace-only strings', () {
        expect(
          () => parseBirrToSantim(''),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('   '),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('\t\n'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(tryParseBirrToSantim(''), isNull);
        expect(tryParseBirrToSantim('   '), isNull);
      });

      test('throws on sign-only or dot-only strings', () {
        expect(
          () => parseBirrToSantim('+'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('-'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('.'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('+लय'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('+.-'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('+.'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('-.'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(tryParseBirrToSantim('.'), isNull);
        expect(tryParseBirrToSantim('+'), isNull);
      });

      test('throws on multiple decimal points', () {
        expect(
          () => parseBirrToSantim('1.2.3'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('1..2'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('..5'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(tryParseBirrToSantim('1.2.3'), isNull);
      });

      test('throws on multiple signs', () {
        expect(
          () => parseBirrToSantim('--5'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('++5'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('+-5'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('-+5'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(tryParseBirrToSantim('--5'), isNull);
      });

      test('throws on non-digit characters', () {
        expect(
          () => parseBirrToSantim('abc'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('12a'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('12.3a'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('12.a3'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('12,50'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('\$25'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('25 ETB'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('2 5'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(tryParseBirrToSantim('abc'), isNull);
      });

      test('throws on negative input when allowNegative is false', () {
        expect(
          () => parseBirrToSantim('-25', allowNegative: false),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('-0.05', allowNegative: false),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(tryParseBirrToSantim('-25', allowNegative: false), isNull);
      });

      test('tryParseBirrToSantim returns null on null input', () {
        expect(tryParseBirrToSantim(null), isNull);
      });
    });

    group('unrepresentable values (sub-santim precision)', () {
      test(
        'rejects values with more than 2 decimal places without rounding',
        () {
          expect(
            () => parseBirrToSantim('25.555'),
            throwsA(isA<MoneyFormatException>()),
          );
          expect(
            () => parseBirrToSantim('0.001'),
            throwsA(isA<MoneyFormatException>()),
          );
          expect(
            () => parseBirrToSantim('10.1234'),
            throwsA(isA<MoneyFormatException>()),
          );
          expect(
            () => parseBirrToSantim('10.000'),
            throwsA(isA<MoneyFormatException>()),
          );
          expect(tryParseBirrToSantim('25.555'), isNull);
          expect(tryParseBirrToSantim('0.001'), isNull);
        },
      );
    });

    group('boundary cases & 64-bit integer limits', () {
      test('parses maximum representable santim (maxInt64)', () {
        expect(parseBirrToSantim('92233720368547758.07'), equals(maxSantim));
        expect(tryParseBirrToSantim('92233720368547758.07'), equals(maxSantim));
      });

      test('parses minimum representable santim (minInt64)', () {
        expect(parseBirrToSantim('-92233720368547758.08'), equals(minSantim));
        expect(
          tryParseBirrToSantim('-92233720368547758.08'),
          equals(minSantim),
        );
      });

      test('throws when exceeding maxInt64 by 1 santim', () {
        expect(
          () => parseBirrToSantim('92233720368547758.08'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(tryParseBirrToSantim('92233720368547758.08'), isNull);
      });

      test('throws when below minInt64 by 1 santim', () {
        expect(
          () => parseBirrToSantim('-92233720368547758.09'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(tryParseBirrToSantim('-92233720368547758.09'), isNull);
      });

      test('throws on whole birr exceeding maxWholeBirr', () {
        expect(
          () => parseBirrToSantim('92233720368547759'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('-92233720368547759'),
          throwsA(isA<MoneyFormatException>()),
        );
      });

      test('throws on massive integers that overflow 64-bit entirely', () {
        expect(
          () => parseBirrToSantim('99999999999999999999999999999999'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          () => parseBirrToSantim('-99999999999999999999999999999999'),
          throwsA(isA<MoneyFormatException>()),
        );
        expect(
          tryParseBirrToSantim('99999999999999999999999999999999'),
          isNull,
        );
      });
    });
  });

  group('formatSantimAsBirr & formatBirr', () {
    test('formats zero', () {
      expect(formatSantimAsBirr(0), equals('0.00'));
      expect(formatBirr(0), equals('0.00'));
    });

    test('formats positive whole birr amounts', () {
      expect(formatSantimAsBirr(100), equals('1.00'));
      expect(formatSantimAsBirr(2500), equals('25.00'));
      expect(formatSantimAsBirr(10000), equals('100.00'));
    });

    test('formats fractional santim amounts with 2-digit zero-padding', () {
      expect(formatSantimAsBirr(1), equals('0.01'));
      expect(formatSantimAsBirr(5), equals('0.05'));
      expect(formatSantimAsBirr(10), equals('0.10'));
      expect(formatSantimAsBirr(50), equals('0.50'));
      expect(formatSantimAsBirr(99), equals('0.99'));
      expect(formatSantimAsBirr(2550), equals('25.50'));
      expect(formatSantimAsBirr(2505), equals('25.05'));
    });

    test('formats negative santim amounts', () {
      expect(formatSantimAsBirr(-1), equals('-0.01'));
      expect(formatSantimAsBirr(-5), equals('-0.05'));
      expect(formatSantimAsBirr(-50), equals('-0.50'));
      expect(formatSantimAsBirr(-100), equals('-1.00'));
      expect(formatSantimAsBirr(-2550), equals('-25.50'));
    });

    test('formats with thousands grouping separator', () {
      expect(formatSantimAsBirr(0, useGrouping: true), equals('0.00'));
      expect(formatSantimAsBirr(2550, useGrouping: true), equals('25.50'));
      expect(formatSantimAsBirr(100000, useGrouping: true), equals('1,000.00'));
      expect(
        formatSantimAsBirr(1234567, useGrouping: true),
        equals('12,345.67'),
      );
      expect(
        formatSantimAsBirr(-1234567, useGrouping: true),
        equals('-12,345.67'),
      );
    });

    test('formats with currency symbol', () {
      expect(formatSantimAsBirr(2550, symbol: 'ETB'), equals('25.50 ETB'));
      expect(formatSantimAsBirr(-2550, symbol: 'ETB'), equals('-25.50 ETB'));
      expect(
        formatSantimAsBirr(2550, symbol: 'ብር', symbolAtStart: true),
        equals('ብር 25.50'),
      );
      expect(
        formatSantimAsBirr(-2550, symbol: 'ብር', symbolAtStart: true),
        equals('-ብር 25.50'),
      );
    });

    test('formats boundary values (maxSantim and minSantim)', () {
      expect(formatSantimAsBirr(maxSantim), equals('92233720368547758.07'));
      expect(
        formatSantimAsBirr(maxSantim, useGrouping: true),
        equals('92,233,720,368,547,758.07'),
      );
      expect(formatSantimAsBirr(minSantim), equals('-92233720368547758.08'));
      expect(
        formatSantimAsBirr(minSantim, useGrouping: true),
        equals('-92,233,720,368,547,758.08'),
      );
    });
  });

  group('birrToSantim and splitSantim', () {
    test('birrToSantim converts whole and fractional components', () {
      expect(birrToSantim(25, 50), equals(2550));
      expect(birrToSantim(25, 0), equals(2500));
      expect(birrToSantim(0, 5), equals(5));
      expect(birrToSantim(0, 0), equals(0));
      expect(birrToSantim(-25, 50), equals(-2550));
    });

    test('birrToSantim validates fractional range 0..99', () {
      expect(() => birrToSantim(25, 100), throwsArgumentError);
      expect(() => birrToSantim(25, -1), throwsArgumentError);
    });

    test('splitSantim separates whole birr and santim remainder', () {
      final pos = splitSantim(2550);
      expect(pos.wholeBirr, equals(25));
      expect(pos.santimRemainder, equals(50));

      final neg = splitSantim(-2550);
      expect(neg.wholeBirr, equals(-25));
      expect(neg.santimRemainder, equals(50));

      final small = splitSantim(5);
      expect(small.wholeBirr, equals(0));
      expect(small.santimRemainder, equals(5));

      final min = splitSantim(minSantim);
      expect(min.wholeBirr, equals(-92233720368547758));
      expect(min.santimRemainder, equals(8));
    });
  });

  group('Extensions and Santim extension type', () {
    test('SantimIntExtension methods', () {
      expect(2550.toBirrString(), equals('25.50'));
      expect(2550.wholeBirr, equals(25));
      expect(2550.subBirrSantim, equals(50));

      final split = 2550.splitAsBirr;
      expect(split.wholeBirr, equals(25));
      expect(split.santimRemainder, equals(50));
    });

    test('BirrStringExtension methods', () {
      expect('25.50'.toSantim(), equals(2550));
      expect('25.50'.tryToSantim(), equals(2550));
      expect('invalid'.tryToSantim(), isNull);
    });

    test('Santim extension type operates seamlessly as int', () {
      const s = Santim(2550);
      expect(s.value, equals(2550));
      expect(s.wholeBirr, equals(25));
      expect(s.subBirrSantim, equals(50));
      expect(s.formatBirr(), equals('25.50'));

      // Operates as int
      const Santim a = Santim(100);
      const Santim b = Santim(200);
      final int c = a + b;
      expect(c, equals(300));

      final parsed = Santim.parseBirr('12.34');
      expect(parsed, equals(1234));
      expect(Santim.tryParseBirr('bad'), isNull);

      final fromBirr = Santim.fromBirr(10, 25);
      expect(fromBirr, equals(1025));
    });
  });
}
