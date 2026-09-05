import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recurrence_kit/recurrence_kit.dart';

RecurrenceRule _rule(
  RecurrencePattern pattern, {
  RecurrenceEnd end = const NeverEnds(),
  bool includeStartDate = false,
}) => RecurrenceRule(
  pattern: pattern,
  end: end,
  includeStartDate: includeStartDate,
);

/// Encodes and decodes through JSON text, as storage would.
RecurrenceRule _roundTrip(RecurrenceRule rule) =>
    RecurrenceRule.fromJson(jsonDecode(jsonEncode(rule.toJson())));

Map<String, dynamic> _daily({Map<String, dynamic>? pattern}) => {
  'pattern': pattern ?? {'kind': 'daily', 'interval': 1},
  'end': {'kind': 'never'},
  'includeStartDate': false,
};

void main() {
  group('toJson shape', () {
    test('daily', () {
      expect(_rule(Daily(interval: 2)).toJson(), {
        'pattern': {'kind': 'daily', 'interval': 2},
        'end': {'kind': 'never'},
        'includeStartDate': false,
      });
    });

    test('weekly', () {
      expect(_rule(Weekly(weekdays: [5, 1])).toJson()['pattern'], {
        'kind': 'weekly',
        'interval': 1,
        'weekdays': [1, 5],
      });
    });

    test('monthly by day', () {
      expect(
        _rule(
          MonthlyByDay(interval: 3, day: 31, missingDay: MissingDay.skip),
        ).toJson()['pattern'],
        {
          'kind': 'monthlyByDay',
          'interval': 3,
          'day': 31,
          'missingDay': 'skip',
        },
      );
    });

    test('monthly by weekday', () {
      expect(
        _rule(
          MonthlyByWeekday(position: WeekPosition.last, weekday: 5),
        ).toJson()['pattern'],
        {
          'kind': 'monthlyByWeekday',
          'interval': 1,
          'position': 'last',
          'weekday': 5,
        },
      );
    });

    test('yearly', () {
      expect(_rule(Yearly(month: 2, day: 29)).toJson()['pattern'], {
        'kind': 'yearly',
        'interval': 1,
        'month': 2,
        'day': 29,
        'missingDay': 'useLastDay',
      });
    });

    test('ends', () {
      expect(
        _rule(Daily(), end: EndsOnDate(DateTime(2025, 12, 31))).toJson()['end'],
        {
          'kind': 'onDate',
          'date': {'year': 2025, 'month': 12, 'day': 31},
        },
      );
      expect(_rule(Daily(), end: EndsAfterCount(7)).toJson()['end'], {
        'kind': 'afterCount',
        'count': 7,
      });
    });

    test('includeStartDate', () {
      expect(
        _rule(Daily(), includeStartDate: true).toJson()['includeStartDate'],
        isTrue,
      );
    });

    test('is JSON-encodable', () {
      final json = _rule(
        Weekly(weekdays: [1, 5]),
        end: EndsOnDate(DateTime(2025, 12, 31)),
      ).toJson();
      expect(() => jsonEncode(json), returnsNormally);
    });
  });

  group('round trip', () {
    final rules = [
      _rule(Daily()),
      _rule(Daily(interval: 9), end: EndsAfterCount(1), includeStartDate: true),
      _rule(Weekly(interval: 2, weekdays: [1, 3, 7])),
      _rule(MonthlyByDay(day: 31)),
      _rule(MonthlyByDay(interval: 12, day: 30, missingDay: MissingDay.skip)),
      _rule(MonthlyByWeekday(position: WeekPosition.fourth, weekday: 4)),
      _rule(
        Yearly(interval: 4, month: 2, day: 29, missingDay: MissingDay.skip),
      ),
      _rule(Yearly(month: 12, day: 25), end: EndsOnDate(DateTime(2030, 1, 1))),
    ];

    for (final rule in rules) {
      test(rule.displayText, () {
        expect(_roundTrip(rule), rule);
      });
    }

    test('end dates with unusual years', () {
      for (final date in [DateTime(12345, 6, 15), DateTime(-44, 3, 15)]) {
        final rule = _rule(Daily(), end: EndsOnDate(date));
        expect(_roundTrip(rule), rule);
      }
    });
  });

  group('rejection', () {
    test('missing pattern or end', () {
      expect(
        () => RecurrenceRule.fromJson({
          'end': {'kind': 'never'},
          'includeStartDate': false,
        }),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {'kind': 'daily', 'interval': 1},
          'includeStartDate': false,
        }),
        throwsFormatException,
      );
    });

    test('missing or non-boolean includeStartDate', () {
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {'kind': 'daily', 'interval': 1},
          'end': {'kind': 'never'},
        }),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {'kind': 'daily', 'interval': 1},
          'end': {'kind': 'never'},
          'includeStartDate': 'yes',
        }),
        throwsFormatException,
      );
    });

    test('unknown or missing kind', () {
      expect(
        () => RecurrenceRule.fromJson(_daily(pattern: {'interval': 1})),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(pattern: {'kind': 'hourly', 'interval': 1}),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {'kind': 'daily', 'interval': 1},
          'end': {'kind': 'whenever'},
          'includeStartDate': false,
        }),
        throwsFormatException,
      );
    });

    test('missing field of the declared kind', () {
      expect(
        () => RecurrenceRule.fromJson(_daily(pattern: {'kind': 'daily'})),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(pattern: {'kind': 'weekly', 'interval': 1}),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(pattern: {'kind': 'monthlyByDay', 'interval': 1, 'day': 5}),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {'kind': 'daily', 'interval': 1},
          'end': {'kind': 'afterCount'},
          'includeStartDate': false,
        }),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {'kind': 'daily', 'interval': 1},
          'end': {
            'kind': 'onDate',
            'date': {'year': 2025, 'month': 1},
          },
          'includeStartDate': false,
        }),
        throwsFormatException,
      );
    });

    test('wrong field types', () {
      expect(
        () => RecurrenceRule.fromJson(
          _daily(pattern: {'kind': 'daily', 'interval': '2'}),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(pattern: {'kind': 'daily', 'interval': 2.5}),
        ),
        throwsFormatException,
      );
      for (final number in [
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ]) {
        expect(
          () => RecurrenceRule.fromJson(
            _daily(pattern: {'kind': 'daily', 'interval': number}),
          ),
          throwsFormatException,
          reason: '$number',
        );
      }
      expect(
        () => RecurrenceRule.fromJson(
          _daily(
            pattern: {
              'kind': 'weekly',
              'interval': 1,
              'weekdays': [1, 'Fri'],
            },
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(pattern: {'kind': 'weekly', 'interval': 1, 'weekdays': 1}),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {'kind': 'daily', 'interval': 1},
          'end': {'kind': 'onDate', 'date': '2025-01-01'},
          'includeStartDate': false,
        }),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {1: 'daily'},
          'end': {'kind': 'never'},
          'includeStartDate': false,
        }),
        throwsFormatException,
      );
    });

    test('out-of-range values', () {
      expect(
        () => RecurrenceRule.fromJson(
          _daily(pattern: {'kind': 'daily', 'interval': 0}),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(
            pattern: {
              'kind': 'weekly',
              'interval': 1,
              'weekdays': [8],
            },
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(
            pattern: {'kind': 'weekly', 'interval': 1, 'weekdays': <int>[]},
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(
            pattern: {
              'kind': 'monthlyByDay',
              'interval': 1,
              'day': 32,
              'missingDay': 'skip',
            },
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(
            pattern: {
              'kind': 'yearly',
              'interval': 1,
              'month': 2,
              'day': 30,
              'missingDay': 'skip',
            },
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson({
          'pattern': {'kind': 'daily', 'interval': 1},
          'end': {'kind': 'afterCount', 'count': 0},
          'includeStartDate': false,
        }),
        throwsFormatException,
      );
    });

    test('unknown enum names', () {
      expect(
        () => RecurrenceRule.fromJson(
          _daily(
            pattern: {
              'kind': 'monthlyByDay',
              'interval': 1,
              'day': 5,
              'missingDay': 'wrap',
            },
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RecurrenceRule.fromJson(
          _daily(
            pattern: {
              'kind': 'monthlyByWeekday',
              'interval': 1,
              'position': 'fifth',
              'weekday': 1,
            },
          ),
        ),
        throwsFormatException,
      );
    });

    test('dates that are not real calendar dates', () {
      for (final date in [
        {'year': 2025, 'month': 2, 'day': 30},
        {'year': 2025, 'month': 13, 'day': 1},
        {'year': 2025, 'month': 0, 'day': 1},
        {'year': 2025, 'month': 1, 'day': 0},
        {'year': 2025, 'month': 4, 'day': 31},
      ]) {
        expect(
          () => RecurrenceRule.fromJson({
            'pattern': {'kind': 'daily', 'interval': 1},
            'end': {'kind': 'onDate', 'date': date},
            'includeStartDate': false,
          }),
          throwsFormatException,
          reason: '$date',
        );
      }
    });
  });

  group('tolerance', () {
    test('ignores unknown keys at every level', () {
      final rule = RecurrenceRule.fromJson({
        'pattern': {'kind': 'daily', 'interval': 2, 'note': 'x'},
        'end': {
          'kind': 'onDate',
          'date': {'year': 2025, 'month': 6, 'day': 1, 'hour': 9},
          'label': 'summer',
        },
        'includeStartDate': true,
        'version': 7,
      });
      expect(
        rule,
        _rule(
          Daily(interval: 2),
          end: EndsOnDate(DateTime(2025, 6, 1)),
          includeStartDate: true,
        ),
      );
    });

    test('ignores fields belonging to other kinds', () {
      final rule = RecurrenceRule.fromJson(
        _daily(
          pattern: {
            'kind': 'weekly',
            'interval': 1,
            'weekdays': [3],
            'day': 31,
            'month': 2,
            'missingDay': 'skip',
          },
        ),
      );
      expect(rule.pattern, Weekly(weekdays: [3]));

      final end = RecurrenceRule.fromJson({
        'pattern': {'kind': 'daily', 'interval': 1},
        'end': {'kind': 'never', 'count': 5},
        'includeStartDate': false,
      }).end;
      expect(end, const NeverEnds());
    });

    test('does not preserve unknown keys', () {
      final rule = RecurrenceRule.fromJson({
        'pattern': {'kind': 'daily', 'interval': 1, 'note': 'x'},
        'end': {'kind': 'never'},
        'includeStartDate': false,
        'version': 7,
      });
      expect(rule.toJson(), _daily());
    });

    test('reads numbers without a fractional part as integers', () {
      final rule = RecurrenceRule.fromJson(
        _daily(
          pattern: {
            'kind': 'weekly',
            'interval': 2.0,
            'weekdays': [1.0, 5],
          },
        ),
      );
      expect(rule.pattern, Weekly(interval: 2, weekdays: [1, 5]));
    });

    test('canonicalizes weekdays', () {
      final rule = RecurrenceRule.fromJson(
        _daily(
          pattern: {
            'kind': 'weekly',
            'interval': 1,
            'weekdays': [5, 1, 5],
          },
        ),
      );
      expect((rule.pattern as Weekly).weekdays, [1, 5]);
    });
  });
}
