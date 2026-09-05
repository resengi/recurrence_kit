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

void main() {
  group('RecurrenceEnd', () {
    test('EndsOnDate keeps calendar components and drops time and UTC', () {
      final end = EndsOnDate(DateTime.utc(2025, 3, 9, 23, 30));
      expect(end.date, DateTime(2025, 3, 9));
      expect(end.date.isUtc, isFalse);
      expect(EndsOnDate(DateTime(2025, 3, 9, 14)).date, DateTime(2025, 3, 9));
    });

    test('EndsAfterCount requires a count of at least 1', () {
      expect(() => EndsAfterCount(0), throwsArgumentError);
      expect(EndsAfterCount(1).count, 1);
    });

    test('structural equality', () {
      expect(const NeverEnds(), const NeverEnds());
      expect(const NeverEnds().hashCode, const NeverEnds().hashCode);
      expect(
        EndsOnDate(DateTime(2025, 1, 1)),
        EndsOnDate(DateTime(2025, 1, 1)),
      );
      expect(
        EndsOnDate(DateTime(2025, 1, 1)),
        isNot(EndsOnDate(DateTime(2025, 1, 2))),
      );
      expect(EndsAfterCount(3), EndsAfterCount(3));
      expect(EndsAfterCount(3), isNot(EndsAfterCount(4)));
      expect(const NeverEnds(), isNot(EndsAfterCount(1)));
    });
  });

  group('RecurrenceRule', () {
    test('defaults includeStartDate to false', () {
      expect(_rule(Daily()).includeStartDate, isFalse);
    });

    test('equality covers pattern, end, and includeStartDate', () {
      expect(_rule(Daily()), _rule(Daily()));
      expect(_rule(Daily()).hashCode, _rule(Daily()).hashCode);
      expect(_rule(Daily()), isNot(_rule(Daily(interval: 2))));
      expect(_rule(Daily()), isNot(_rule(Daily(), end: EndsAfterCount(1))));
      expect(_rule(Daily()), isNot(_rule(Daily(), includeStartDate: true)));
    });

    test('copyWith replaces each part independently', () {
      final base = _rule(Daily(), end: EndsAfterCount(3));
      expect(
        base.copyWith(pattern: Weekly(weekdays: [1])),
        _rule(Weekly(weekdays: [1]), end: EndsAfterCount(3)),
      );
      expect(base.copyWith(end: const NeverEnds()), _rule(Daily()));
      expect(
        base.copyWith(includeStartDate: true),
        _rule(Daily(), end: EndsAfterCount(3), includeStartDate: true),
      );
      expect(base.copyWith(), base);
    });
  });

  group('displayText', () {
    test('daily', () {
      expect(_rule(Daily()).displayText, 'Every day');
      expect(_rule(Daily(interval: 3)).displayText, 'Every 3 days');
    });

    test('weekly', () {
      expect(_rule(Weekly(weekdays: [5, 1])).displayText, 'Mon, Fri');
      expect(
        _rule(
          Weekly(interval: 2, weekdays: [1, 5]),
          end: EndsAfterCount(10),
        ).displayText,
        'Every 2 weeks: Mon, Fri · for 10 times',
      );
    });

    test('monthly by day below 29', () {
      expect(_rule(MonthlyByDay(day: 1)).displayText, 'Monthly on the 1st');
      expect(_rule(MonthlyByDay(day: 2)).displayText, 'Monthly on the 2nd');
      expect(_rule(MonthlyByDay(day: 3)).displayText, 'Monthly on the 3rd');
      expect(_rule(MonthlyByDay(day: 11)).displayText, 'Monthly on the 11th');
      expect(_rule(MonthlyByDay(day: 12)).displayText, 'Monthly on the 12th');
      expect(_rule(MonthlyByDay(day: 13)).displayText, 'Monthly on the 13th');
      expect(_rule(MonthlyByDay(day: 22)).displayText, 'Monthly on the 22nd');
      expect(
        _rule(MonthlyByDay(interval: 2, day: 15)).displayText,
        'Every 2 months on the 15th',
      );
      expect(
        _rule(MonthlyByDay(day: 15, missingDay: MissingDay.skip)).displayText,
        'Monthly on the 15th',
      );
    });

    test('monthly by day 29-31 describes the missing-day behavior', () {
      expect(
        _rule(MonthlyByDay(day: 31)).displayText,
        'Monthly on the last day',
      );
      expect(
        _rule(MonthlyByDay(day: 30)).displayText,
        'Monthly on the 30th, using the last day in shorter months',
      );
      expect(
        _rule(MonthlyByDay(day: 29)).displayText,
        'Monthly on the 29th, using the last day in shorter months',
      );
      expect(
        _rule(MonthlyByDay(day: 31, missingDay: MissingDay.skip)).displayText,
        'Monthly on the 31st, skipping months without that day',
      );
      expect(
        _rule(
          MonthlyByDay(interval: 3, day: 29, missingDay: MissingDay.skip),
        ).displayText,
        'Every 3 months on the 29th, skipping months without that day',
      );
    });

    test('monthly by weekday', () {
      expect(
        _rule(
          MonthlyByWeekday(position: WeekPosition.second, weekday: 2),
        ).displayText,
        'Monthly on the 2nd Tuesday',
      );
      expect(
        _rule(
          MonthlyByWeekday(
            interval: 2,
            position: WeekPosition.last,
            weekday: 5,
          ),
        ).displayText,
        'Every 2 months on the last Friday',
      );
    });

    test('yearly', () {
      expect(_rule(Yearly(month: 6, day: 15)).displayText, 'Yearly on June 15');
      expect(
        _rule(Yearly(interval: 2, month: 6, day: 15)).displayText,
        'Every 2 years on June 15',
      );
      expect(
        _rule(Yearly(month: 2, day: 29)).displayText,
        'Yearly on February 29, using Feb 28 in non-leap years',
      );
      expect(
        _rule(
          Yearly(month: 2, day: 29, missingDay: MissingDay.skip),
        ).displayText,
        'Yearly on February 29, skipping non-leap years',
      );
      expect(
        _rule(
          Yearly(month: 2, day: 28, missingDay: MissingDay.skip),
        ).displayText,
        'Yearly on February 28',
      );
    });

    test('end suffixes', () {
      expect(
        _rule(Daily(), end: EndsOnDate(DateTime(2025, 12, 31))).displayText,
        'Every day · until 12/31/2025',
      );
      expect(
        _rule(Daily(), end: EndsAfterCount(1)).displayText,
        'Every day · for 1 time',
      );
    });

    test('includeStartDate suffix', () {
      expect(
        _rule(Daily(), includeStartDate: true).displayText,
        'Every day · including start date',
      );
      expect(
        _rule(
          Weekly(weekdays: [1]),
          end: EndsAfterCount(5),
          includeStartDate: true,
        ).displayText,
        'Mon · for 5 times · including start date',
      );
    });
  });
}
