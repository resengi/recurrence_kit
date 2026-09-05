import 'package:flutter_test/flutter_test.dart';
import 'package:recurrence_kit/recurrence_kit.dart';

/// Armed by `--dart-define=EXPECT_DST_TZ=true` on the DST-observing CI leg.
const bool _expectDstTz = bool.fromEnvironment('EXPECT_DST_TZ');

RecurrenceRule _rule(
  RecurrencePattern pattern, {
  RecurrenceEnd end = const NeverEnds(),
  bool includeStartDate = false,
}) => RecurrenceRule(
  pattern: pattern,
  end: end,
  includeStartDate: includeStartDate,
);

DateTime _d(int year, int month, int day) => DateTime(year, month, day);

List<DateTime> _next(
  RecurrenceRule rule,
  DateTime start,
  int count, {
  DateTime? from,
}) =>
    RecurrenceEngine.nextOccurrences(rule, start, from ?? start, count: count);

void main() {
  group('inputs and outputs are calendar dates', () {
    test('time-of-day and UTC flag on inputs are ignored', () {
      final rule = _rule(Daily());
      final start = DateTime.utc(2025, 1, 1, 23, 59);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 3, 8), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(
          rule,
          start,
          DateTime(2025, 1, 3, 17, 45),
        ),
        _d(2025, 1, 3),
      );
    });

    test('returned dates are local midnight', () {
      final next = RecurrenceEngine.nextOccurrenceOnOrAfter(
        _rule(Daily()),
        DateTime(2025, 1, 1, 9),
        DateTime(2025, 1, 1, 9),
      );
      expect(next, _d(2025, 1, 1));
      expect(next!.isUtc, isFalse);
    });
  });

  group('daily', () {
    test('every N days from the start date', () {
      expect(_next(_rule(Daily(interval: 3)), _d(2025, 1, 1), 3), [
        _d(2025, 1, 1),
        _d(2025, 1, 4),
        _d(2025, 1, 7),
      ]);
      expect(
        RecurrenceEngine.occursOnDate(
          _rule(Daily(interval: 3)),
          _d(2025, 1, 5),
          _d(2025, 1, 1),
        ),
        isFalse,
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          _rule(Daily(interval: 3)),
          _d(2025, 1, 1),
          _d(2025, 1, 6),
        ),
        _d(2025, 1, 4),
      );
    });
  });

  group('weekly', () {
    test('weeks are Monday-based and aligned to the start week', () {
      // 2025-01-01 is a Wednesday; its week is Mon Dec 30 – Sun Jan 5.
      final rule = _rule(Weekly(interval: 2, weekdays: [DateTime.friday]));
      final start = _d(2025, 1, 1);
      expect(_next(rule, start, 3), [
        _d(2025, 1, 3),
        _d(2025, 1, 17),
        _d(2025, 1, 31),
      ]);
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2025, 1, 10), start),
        isFalse,
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2025, 1, 30),
        ),
        _d(2025, 1, 17),
      );
    });

    test('several weekdays in ascending order within each aligned week', () {
      final rule = _rule(
        Weekly(interval: 2, weekdays: [DateTime.monday, DateTime.friday]),
      );
      expect(_next(rule, _d(2025, 1, 1), 4), [
        _d(2025, 1, 3),
        _d(2025, 1, 13),
        _d(2025, 1, 17),
        _d(2025, 1, 27),
      ]);
    });

    test('a start date on a selected weekday is the first occurrence', () {
      final rule = _rule(Weekly(weekdays: [DateTime.friday]));
      expect(_next(rule, _d(2025, 1, 10), 2), [
        _d(2025, 1, 10),
        _d(2025, 1, 17),
      ]);
    });
  });

  group('monthly by day', () {
    test('day 31 with useLastDay lands on every month\'s last day', () {
      expect(_next(_rule(MonthlyByDay(day: 31)), _d(2025, 1, 31), 4), [
        _d(2025, 1, 31),
        _d(2025, 2, 28),
        _d(2025, 3, 31),
        _d(2025, 4, 30),
      ]);
    });

    test('day 31 with skip produces nothing in shorter months', () {
      final rule = _rule(MonthlyByDay(day: 31, missingDay: MissingDay.skip));
      expect(
        RecurrenceEngine.occurrencesInRange(
          rule,
          _d(2025, 1, 31),
          _d(2025, 1, 1),
          _d(2025, 12, 31),
        ),
        [
          _d(2025, 1, 31),
          _d(2025, 3, 31),
          _d(2025, 5, 31),
          _d(2025, 7, 31),
          _d(2025, 8, 31),
          _d(2025, 10, 31),
          _d(2025, 12, 31),
        ],
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2025, 4, 30), _d(2025, 1, 31)),
        isFalse,
      );
    });

    test('day 30 in both modes', () {
      expect(_next(_rule(MonthlyByDay(day: 30)), _d(2025, 1, 30), 3), [
        _d(2025, 1, 30),
        _d(2025, 2, 28),
        _d(2025, 3, 30),
      ]);
      expect(
        _next(
          _rule(MonthlyByDay(day: 30, missingDay: MissingDay.skip)),
          _d(2025, 1, 30),
          3,
        ),
        [_d(2025, 1, 30), _d(2025, 3, 30), _d(2025, 4, 30)],
      );
    });

    test('day 29 in both modes across leap and non-leap Februaries', () {
      expect(_next(_rule(MonthlyByDay(day: 29)), _d(2025, 1, 29), 3), [
        _d(2025, 1, 29),
        _d(2025, 2, 28),
        _d(2025, 3, 29),
      ]);
      final skip = _rule(MonthlyByDay(day: 29, missingDay: MissingDay.skip));
      expect(_next(skip, _d(2025, 1, 29), 3), [
        _d(2025, 1, 29),
        _d(2025, 3, 29),
        _d(2025, 4, 29),
      ]);
      expect(_next(skip, _d(2024, 1, 29), 3), [
        _d(2024, 1, 29),
        _d(2024, 2, 29),
        _d(2024, 3, 29),
      ]);
    });

    test('a start date after the target day begins in the next month', () {
      expect(_next(_rule(MonthlyByDay(day: 15)), _d(2025, 1, 20), 2), [
        _d(2025, 2, 15),
        _d(2025, 3, 15),
      ]);
    });

    test('intervals are aligned to the start month', () {
      final rule = _rule(MonthlyByDay(interval: 3, day: 10));
      expect(_next(rule, _d(2025, 1, 5), 3), [
        _d(2025, 1, 10),
        _d(2025, 4, 10),
        _d(2025, 7, 10),
      ]);
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2025, 2, 10), _d(2025, 1, 5)),
        isFalse,
      );
    });

    test('day 29 with skip every 12 months from February', () {
      final rule = _rule(
        MonthlyByDay(interval: 12, day: 29, missingDay: MissingDay.skip),
      );
      expect(_next(rule, _d(2023, 2, 1), 3), [
        _d(2024, 2, 29),
        _d(2028, 2, 29),
        _d(2032, 2, 29),
      ]);
    });
  });

  group('monthly by weekday', () {
    test('last Friday', () {
      final rule = _rule(
        MonthlyByWeekday(position: WeekPosition.last, weekday: DateTime.friday),
      );
      expect(_next(rule, _d(2025, 1, 1), 5), [
        _d(2025, 1, 31),
        _d(2025, 2, 28),
        _d(2025, 3, 28),
        _d(2025, 4, 25),
        _d(2025, 5, 30),
      ]);
    });

    test('fourth Friday differs from the last in five-Friday months', () {
      final rule = _rule(
        MonthlyByWeekday(
          position: WeekPosition.fourth,
          weekday: DateTime.friday,
        ),
      );
      expect(_next(rule, _d(2025, 1, 1), 5), [
        _d(2025, 1, 24),
        _d(2025, 2, 28),
        _d(2025, 3, 28),
        _d(2025, 4, 25),
        _d(2025, 5, 23),
      ]);
    });

    test('first Monday every 2 months', () {
      final rule = _rule(
        MonthlyByWeekday(
          interval: 2,
          position: WeekPosition.first,
          weekday: DateTime.monday,
        ),
      );
      expect(_next(rule, _d(2025, 1, 10), 3), [
        _d(2025, 3, 3),
        _d(2025, 5, 5),
        _d(2025, 7, 7),
      ]);
    });
  });

  group('yearly', () {
    test('February 29 with useLastDay falls on Feb 28 in non-leap years', () {
      expect(_next(_rule(Yearly(month: 2, day: 29)), _d(2024, 2, 29), 3), [
        _d(2024, 2, 29),
        _d(2025, 2, 28),
        _d(2026, 2, 28),
      ]);
    });

    test('February 29 with skip falls only in leap years', () {
      final rule = _rule(
        Yearly(month: 2, day: 29, missingDay: MissingDay.skip),
      );
      expect(_next(rule, _d(2024, 2, 29), 3), [
        _d(2024, 2, 29),
        _d(2028, 2, 29),
        _d(2032, 2, 29),
      ]);
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2025, 2, 28), _d(2024, 2, 29)),
        isFalse,
      );
    });

    test('February 29 every 4 years skips the century year 2100', () {
      final rule = _rule(
        Yearly(interval: 4, month: 2, day: 29, missingDay: MissingDay.skip),
      );
      expect(_next(rule, _d(2096, 2, 29), 2), [
        _d(2096, 2, 29),
        _d(2104, 2, 29),
      ]);
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          _d(2096, 2, 29),
          _d(2103, 12, 31),
        ),
        _d(2096, 2, 29),
      );
    });

    test(
      'February 29 every 100 years lands only in years divisible by 400',
      () {
        final rule = _rule(
          Yearly(interval: 100, month: 2, day: 29, missingDay: MissingDay.skip),
        );
        expect(_next(rule, _d(2000, 2, 29), 2), [
          _d(2000, 2, 29),
          _d(2400, 2, 29),
        ]);
        expect(
          RecurrenceEngine.nextOccurrenceOnOrAfter(
            rule,
            _d(2000, 2, 29),
            _d(2000, 3, 1),
          ),
          _d(2400, 2, 29),
        );
      },
    );

    test(
      'a start date after the target day begins in the next aligned year',
      () {
        expect(
          _next(
            _rule(Yearly(interval: 2, month: 6, day: 15)),
            _d(2024, 7, 1),
            2,
          ),
          [_d(2026, 6, 15), _d(2028, 6, 15)],
        );
      },
    );
  });

  group('rules that never match', () {
    final monthly = _rule(
      MonthlyByDay(interval: 12, day: 30, missingDay: MissingDay.skip),
    );
    final monthlyStart = _d(2025, 2, 1);
    final yearly = _rule(
      Yearly(interval: 100, month: 2, day: 29, missingDay: MissingDay.skip),
    );
    final yearlyStart = _d(2001, 1, 1);

    test('every query is empty', () {
      for (final (rule, start) in [
        (monthly, monthlyStart),
        (yearly, yearlyStart),
      ]) {
        expect(RecurrenceEngine.occursOnDate(rule, start, start), isFalse);
        expect(
          RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, start),
          isNull,
        );
        expect(
          RecurrenceEngine.previousOccurrenceOnOrBefore(
            rule,
            start,
            _d(2500, 1, 1),
          ),
          isNull,
        );
        expect(
          RecurrenceEngine.occurrencesInRange(
            rule,
            start,
            start,
            _d(2035, 1, 1),
          ),
          isEmpty,
        );
        expect(_next(rule, start, 3), isEmpty);
        expect(RecurrenceEngine.lastOccurrence(rule, start), isNull);
      }
    });

    test('day 29 every 24 months from an odd-year February never lands', () {
      final rule = _rule(
        MonthlyByDay(interval: 24, day: 29, missingDay: MissingDay.skip),
      );
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(
          rule,
          _d(2023, 2, 1),
          _d(2023, 2, 1),
        ),
        isNull,
      );
    });

    test('with includeStartDate the schedule is the start date alone', () {
      final rule = monthly.copyWith(includeStartDate: true);
      final start = monthlyStart;
      expect(RecurrenceEngine.occursOnDate(rule, start, start), isTrue);
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, start),
        start,
      );
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, _d(2025, 2, 2)),
        isNull,
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2099, 1, 1),
        ),
        start,
      );
      expect(_next(rule, start, 5), [start]);
      expect(RecurrenceEngine.lastOccurrence(rule, start), start);
    });

    test(
      'with includeStartDate and after-N the schedule is still the start date',
      () {
        final rule = monthly.copyWith(
          includeStartDate: true,
          end: EndsAfterCount(10),
        );
        expect(_next(rule, monthlyStart, 5), [monthlyStart]);
        expect(
          RecurrenceEngine.lastOccurrence(rule, monthlyStart),
          monthlyStart,
        );
      },
    );
  });

  group('includeStartDate', () {
    // 2025-01-01 is a Wednesday.
    final fridays = Weekly(weekdays: [DateTime.friday]);
    final start = _d(2025, 1, 1);

    test('off: a non-matching start date is not an occurrence', () {
      final rule = _rule(fridays);
      expect(RecurrenceEngine.occursOnDate(rule, start, start), isFalse);
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, _d(2024, 12, 25)),
        _d(2025, 1, 3),
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2025, 1, 2),
        ),
        isNull,
      );
      expect(_next(rule, start, 2), [_d(2025, 1, 3), _d(2025, 1, 10)]);
      expect(
        RecurrenceEngine.lastOccurrence(
          rule.copyWith(end: EndsAfterCount(2)),
          start,
        ),
        _d(2025, 1, 10),
      );
    });

    test('on: a non-matching start date is occurrence #1', () {
      final rule = _rule(fridays, includeStartDate: true);
      expect(RecurrenceEngine.occursOnDate(rule, start, start), isTrue);
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, _d(2024, 12, 25)),
        start,
      );
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, _d(2025, 1, 2)),
        _d(2025, 1, 3),
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2025, 1, 2),
        ),
        start,
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2024, 12, 31),
        ),
        isNull,
      );
      expect(_next(rule, start, 3), [start, _d(2025, 1, 3), _d(2025, 1, 10)]);
      expect(
        RecurrenceEngine.lastOccurrence(
          rule.copyWith(end: EndsAfterCount(2)),
          start,
        ),
        _d(2025, 1, 3),
      );
    });

    test('on: a matching start date is not duplicated', () {
      final rule = _rule(Daily(), includeStartDate: true);
      expect(_next(rule, start, 3), [start, _d(2025, 1, 2), _d(2025, 1, 3)]);
      expect(
        RecurrenceEngine.lastOccurrence(
          rule.copyWith(end: EndsAfterCount(2)),
          start,
        ),
        _d(2025, 1, 2),
      );
      expect(
        RecurrenceEngine.occurrencesInRange(
          rule,
          start,
          _d(2024, 12, 30),
          _d(2025, 1, 2),
        ),
        [start, _d(2025, 1, 2)],
      );
    });
  });

  group('ends', () {
    test('until is inclusive', () {
      final rule = _rule(Daily(), end: EndsOnDate(_d(2025, 1, 5)));
      final start = _d(2025, 1, 1);
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2025, 1, 5), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2025, 1, 6), start),
        isFalse,
      );
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, _d(2025, 1, 6)),
        isNull,
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2025, 1, 10),
        ),
        _d(2025, 1, 5),
      );
      expect(RecurrenceEngine.lastOccurrence(rule, start), _d(2025, 1, 5));
      expect(_next(rule, start, 10), [
        _d(2025, 1, 1),
        _d(2025, 1, 2),
        _d(2025, 1, 3),
        _d(2025, 1, 4),
        _d(2025, 1, 5),
      ]);
    });

    test('until before the start date is a valid empty schedule', () {
      final rule = _rule(
        Daily(),
        end: EndsOnDate(_d(2025, 1, 5)),
        includeStartDate: true,
      );
      final start = _d(2025, 1, 10);
      expect(RecurrenceEngine.occursOnDate(rule, start, start), isFalse);
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, _d(2025, 1, 1)),
        isNull,
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2025, 1, 20),
        ),
        isNull,
      );
      expect(
        RecurrenceEngine.occurrencesInRange(
          rule,
          start,
          _d(2025, 1, 1),
          _d(2025, 1, 31),
        ),
        isEmpty,
      );
      expect(RecurrenceEngine.lastOccurrence(rule, start), isNull);
    });

    test('after N keeps the first N occurrences', () {
      final rule = _rule(
        Weekly(weekdays: [DateTime.friday]),
        end: EndsAfterCount(3),
      );
      final start = _d(2025, 1, 10);
      expect(_next(rule, start, 10, from: _d(2025, 1, 1)), [
        _d(2025, 1, 10),
        _d(2025, 1, 17),
        _d(2025, 1, 24),
      ]);
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2025, 1, 31), start),
        isFalse,
      );
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, _d(2025, 1, 25)),
        isNull,
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2025, 2, 15),
        ),
        _d(2025, 1, 24),
      );
      expect(RecurrenceEngine.lastOccurrence(rule, start), _d(2025, 1, 24));
    });

    test('after 1 is the first occurrence alone', () {
      final rule = _rule(Daily(interval: 5), end: EndsAfterCount(1));
      expect(
        RecurrenceEngine.lastOccurrence(rule, _d(2025, 1, 1)),
        _d(2025, 1, 1),
      );
      expect(_next(rule, _d(2025, 1, 1), 3), [_d(2025, 1, 1)]);
    });

    test('an unbounded sequence has no last occurrence', () {
      expect(
        RecurrenceEngine.lastOccurrence(_rule(Daily()), _d(2025, 1, 1)),
        isNull,
      );
    });
  });

  group('query conventions', () {
    final rule = _rule(Daily());
    final start = _d(2025, 1, 1);

    test('occurrencesInRange is inclusive at both ends', () {
      expect(
        RecurrenceEngine.occurrencesInRange(
          rule,
          start,
          _d(2025, 1, 3),
          _d(2025, 1, 5),
        ),
        [_d(2025, 1, 3), _d(2025, 1, 4), _d(2025, 1, 5)],
      );
      expect(
        RecurrenceEngine.occurrencesInRange(
          rule,
          start,
          _d(2025, 1, 3),
          _d(2025, 1, 3),
        ),
        [_d(2025, 1, 3)],
      );
    });

    test('occurrencesInRange rejects a reversed range', () {
      expect(
        () => RecurrenceEngine.occurrencesInRange(
          rule,
          start,
          _d(2025, 1, 5),
          _d(2025, 1, 3),
        ),
        throwsArgumentError,
      );
    });

    test('nextOccurrences is inclusive of the query date', () {
      expect(_next(rule, start, 3, from: _d(2025, 1, 4)), [
        _d(2025, 1, 4),
        _d(2025, 1, 5),
        _d(2025, 1, 6),
      ]);
    });

    test('nextOccurrences with count 0 is empty and negative counts throw', () {
      expect(_next(rule, start, 0), isEmpty);
      expect(() => _next(rule, start, -1), throwsArgumentError);
    });

    test('queries before the start date see nothing earlier', () {
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(
          rule,
          start,
          _d(2024, 12, 31),
        ),
        isNull,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2024, 12, 31), start),
        isFalse,
      );
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, _d(2024, 6, 1)),
        start,
      );
    });
  });

  group("Dart's last representable day", () {
    // The local calendar day of the last instant Dart can represent: the
    // day itself is constructible in every time zone; the day after it is
    // not.
    final limit = DateTime.fromMillisecondsSinceEpoch(8640000000000000);
    final lastDay = DateTime(limit.year, limit.month, limit.day);
    final daily = _rule(Daily());

    test(
      'nextOccurrences returns the requested count when the last of them is that day',
      () {
        expect(_next(daily, lastDay, 1), [lastDay]);
      },
    );

    test(
      'occurrencesInRange returns every date through a range ending on that day',
      () {
        final start = DateTime(lastDay.year, lastDay.month, lastDay.day - 2);
        expect(
          RecurrenceEngine.occurrencesInRange(daily, start, start, lastDay),
          [
            start,
            DateTime(lastDay.year, lastDay.month, lastDay.day - 1),
            lastDay,
          ],
        );
      },
    );

    test('single-occurrence queries on that day', () {
      expect(RecurrenceEngine.occursOnDate(daily, lastDay, lastDay), isTrue);
      expect(
        RecurrenceEngine.nextOccurrenceOnOrAfter(daily, lastDay, lastDay),
        lastDay,
      );
      expect(
        RecurrenceEngine.previousOccurrenceOnOrBefore(daily, lastDay, lastDay),
        lastDay,
      );
    });
  });

  group('daylight-saving transitions', () {
    test('daily steps cross the spring-forward date without drift', () {
      expect(_next(_rule(Daily()), _d(2025, 3, 8), 3), [
        _d(2025, 3, 8),
        _d(2025, 3, 9),
        _d(2025, 3, 10),
      ]);
    });

    test('a 7-day interval crosses the fall-back date without drift', () {
      final rule = _rule(Daily(interval: 7));
      expect(_next(rule, _d(2025, 10, 27), 2), [
        _d(2025, 10, 27),
        _d(2025, 11, 3),
      ]);
      expect(
        RecurrenceEngine.occursOnDate(rule, _d(2025, 11, 3), _d(2025, 10, 27)),
        isTrue,
      );
    });

    test('week alignment survives a transition inside the interval', () {
      final rule = _rule(Weekly(interval: 2, weekdays: [DateTime.monday]));
      expect(_next(rule, _d(2025, 3, 3), 2), [_d(2025, 3, 3), _d(2025, 3, 17)]);
    });

    test('the test environment observes DST when EXPECT_DST_TZ is defined', () {
      final spring = DateTime(
        2025,
        3,
        9,
        12,
      ).difference(DateTime(2025, 3, 8, 12));
      final fall = DateTime(
        2025,
        11,
        2,
        12,
      ).difference(DateTime(2025, 11, 1, 12));
      expect(
        spring != const Duration(hours: 24) ||
            fall != const Duration(hours: 24),
        isTrue,
        reason:
            'EXPECT_DST_TZ is defined, but the process time zone has no '
            'DST transition; run this leg with TZ=America/New_York or another '
            'DST-observing zone',
      );
    }, skip: !_expectDstTz);
  });
}
