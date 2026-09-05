import 'package:flutter_test/flutter_test.dart';
import 'package:recurrence_kit/recurrence_kit.dart';

void main() {
  group('interval', () {
    test('every variant requires an interval of at least 1', () {
      expect(() => Daily(interval: 0), throwsArgumentError);
      expect(() => Weekly(interval: 0, weekdays: [1]), throwsArgumentError);
      expect(() => MonthlyByDay(interval: 0, day: 1), throwsArgumentError);
      expect(
        () => MonthlyByWeekday(
          interval: 0,
          position: WeekPosition.first,
          weekday: 1,
        ),
        throwsArgumentError,
      );
      expect(() => Yearly(interval: -1, month: 1, day: 1), throwsArgumentError);
    });

    test('defaults to 1', () {
      expect(Daily().interval, 1);
      expect(Weekly(weekdays: [1]).interval, 1);
      expect(MonthlyByDay(day: 1).interval, 1);
      expect(
        MonthlyByWeekday(position: WeekPosition.first, weekday: 1).interval,
        1,
      );
      expect(Yearly(month: 1, day: 1).interval, 1);
    });
  });

  group('Weekly', () {
    test('requires at least one weekday', () {
      expect(() => Weekly(weekdays: []), throwsArgumentError);
    });

    test('rejects weekdays outside 1-7', () {
      expect(() => Weekly(weekdays: [0]), throwsArgumentError);
      expect(() => Weekly(weekdays: [1, 8]), throwsArgumentError);
    });

    test('stores weekdays sorted, without duplicates, unmodifiable', () {
      final weekly = Weekly(weekdays: [5, 1, 5, 3]);
      expect(weekly.weekdays, [1, 3, 5]);
      expect(() => weekly.weekdays.add(7), throwsUnsupportedError);
    });

    test('does not retain the caller\'s list', () {
      final input = [1, 5];
      final weekly = Weekly(weekdays: input);
      input.add(7);
      expect(weekly.weekdays, [1, 5]);
    });

    test('equality is by canonical weekdays', () {
      expect(Weekly(weekdays: [5, 1]), Weekly(weekdays: [1, 5]));
      expect(
        Weekly(weekdays: [5, 1]).hashCode,
        Weekly(weekdays: [1, 5]).hashCode,
      );
      expect(Weekly(weekdays: [1]), isNot(Weekly(weekdays: [2])));
      expect(
        Weekly(interval: 2, weekdays: [1]),
        isNot(Weekly(interval: 3, weekdays: [1])),
      );
    });

    test('copyWith replaces interval and weekdays independently', () {
      final base = Weekly(interval: 2, weekdays: [1, 5]);
      expect(base.copyWith(interval: 3), Weekly(interval: 3, weekdays: [1, 5]));
      expect(base.copyWith(weekdays: [7]), Weekly(interval: 2, weekdays: [7]));
    });
  });

  group('MonthlyByDay', () {
    test('accepts days 1-31 and rejects others', () {
      expect(MonthlyByDay(day: 1).day, 1);
      expect(MonthlyByDay(day: 31).day, 31);
      expect(() => MonthlyByDay(day: 0), throwsArgumentError);
      expect(() => MonthlyByDay(day: 32), throwsArgumentError);
    });

    test('defaults missingDay to useLastDay', () {
      expect(MonthlyByDay(day: 31).missingDay, MissingDay.useLastDay);
    });

    test('missingDay is part of equality', () {
      expect(
        MonthlyByDay(day: 31, missingDay: MissingDay.skip),
        isNot(MonthlyByDay(day: 31)),
      );
      expect(
        MonthlyByDay(day: 15, missingDay: MissingDay.skip),
        isNot(MonthlyByDay(day: 15)),
      );
    });

    test('copyWith replaces each field', () {
      final base = MonthlyByDay(interval: 2, day: 15);
      expect(base.copyWith(day: 31), MonthlyByDay(interval: 2, day: 31));
      expect(
        base.copyWith(missingDay: MissingDay.skip),
        MonthlyByDay(interval: 2, day: 15, missingDay: MissingDay.skip),
      );
      expect(base.copyWith(interval: 1), MonthlyByDay(day: 15));
    });
  });

  group('MonthlyByWeekday', () {
    test('rejects weekdays outside 1-7', () {
      expect(
        () => MonthlyByWeekday(position: WeekPosition.first, weekday: 0),
        throwsArgumentError,
      );
      expect(
        () => MonthlyByWeekday(position: WeekPosition.last, weekday: 8),
        throwsArgumentError,
      );
    });

    test('copyWith replaces each field', () {
      final base = MonthlyByWeekday(position: WeekPosition.second, weekday: 2);
      expect(
        base.copyWith(position: WeekPosition.last),
        MonthlyByWeekday(position: WeekPosition.last, weekday: 2),
      );
      expect(
        base.copyWith(weekday: 5),
        MonthlyByWeekday(position: WeekPosition.second, weekday: 5),
      );
      expect(
        base.copyWith(interval: 3),
        MonthlyByWeekday(
          interval: 3,
          position: WeekPosition.second,
          weekday: 2,
        ),
      );
    });
  });

  group('Yearly', () {
    test('rejects months outside 1-12', () {
      expect(() => Yearly(month: 0, day: 1), throwsArgumentError);
      expect(() => Yearly(month: 13, day: 1), throwsArgumentError);
    });

    test('accepts a day that exists in the month in some year', () {
      expect(Yearly(month: 2, day: 29).day, 29);
      expect(Yearly(month: 4, day: 30).day, 30);
      expect(Yearly(month: 1, day: 31).day, 31);
    });

    test('rejects a day that exists in the month in no year', () {
      expect(() => Yearly(month: 2, day: 30), throwsArgumentError);
      expect(() => Yearly(month: 4, day: 31), throwsArgumentError);
      expect(() => Yearly(month: 6, day: 0), throwsArgumentError);
    });

    test('defaults missingDay to useLastDay', () {
      expect(Yearly(month: 2, day: 29).missingDay, MissingDay.useLastDay);
    });

    test('copyWith replaces each field', () {
      final base = Yearly(month: 6, day: 15);
      expect(base.copyWith(month: 2, day: 29), Yearly(month: 2, day: 29));
      expect(
        base.copyWith(missingDay: MissingDay.skip),
        Yearly(month: 6, day: 15, missingDay: MissingDay.skip),
      );
      expect(
        base.copyWith(interval: 4),
        Yearly(interval: 4, month: 6, day: 15),
      );
    });
  });

  group('equality across variants', () {
    test('different variants are never equal', () {
      expect(Daily(), isNot(MonthlyByDay(day: 1)));
      expect(
        MonthlyByDay(day: 1),
        isNot(MonthlyByWeekday(position: WeekPosition.first, weekday: 1)),
      );
    });

    test('equal values have equal hash codes', () {
      expect(Daily(interval: 2).hashCode, Daily(interval: 2).hashCode);
      expect(
        Yearly(month: 2, day: 29, missingDay: MissingDay.skip).hashCode,
        Yearly(month: 2, day: 29, missingDay: MissingDay.skip).hashCode,
      );
    });
  });
}
