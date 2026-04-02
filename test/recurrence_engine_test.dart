import 'package:flutter_test/flutter_test.dart';
import 'package:recurrence_kit/recurrence_kit.dart';

void main() {
  // ── occursOnDate — daily ───────────────────────────────────────────────

  group('occursOnDate — daily', () {
    test('interval 1 matches every day from start', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 1), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 2), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 10), start),
        isTrue,
      );
    });

    test('interval 3 matches every 3rd day', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily, interval: 3);
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 1), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 4), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 7), start),
        isTrue,
      );
    });

    test('non-matching interval day returns false', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily, interval: 3);
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 2), start),
        isFalse,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 3), start),
        isFalse,
      );
    });
  });

  // ── occursOnDate — weekly ──────────────────────────────────────────────

  group('occursOnDate — weekly', () {
    test('day in daysOfWeek matches', () {
      // Monday and Friday.
      final rule = RecurrenceRule(
        type: RecurrenceType.weekly,
        daysOfWeek: [1, 5],
      );
      final start = DateTime(2025, 1, 6); // Monday
      // Jan 6 2025 = Monday
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 6), start),
        isTrue,
      );
      // Jan 10 2025 = Friday
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 10), start),
        isTrue,
      );
    });

    test('day not in set returns false', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.weekly,
        daysOfWeek: [1, 5],
      );
      final start = DateTime(2025, 1, 6);
      // Jan 7 2025 = Tuesday
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 7), start),
        isFalse,
      );
    });

    test('empty daysOfWeek always returns false', () {
      final rule = RecurrenceRule(type: RecurrenceType.weekly, daysOfWeek: []);
      final start = DateTime(2025, 1, 6);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 6), start),
        isFalse,
      );
    });

    test('null daysOfWeek returns false', () {
      final rule = RecurrenceRule(type: RecurrenceType.weekly);
      final start = DateTime(2025, 1, 6);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 6), start),
        isFalse,
      );
    });

    test('interval 2 matches every other week', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.weekly,
        interval: 2,
        daysOfWeek: [1], // Monday
      );
      final start = DateTime(2025, 1, 6); // Monday, week 0
      // Week 0 Monday — matches
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 6), start),
        isTrue,
      );
      // Week 1 Monday — skipped
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 13), start),
        isFalse,
      );
      // Week 2 Monday — matches
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 20), start),
        isTrue,
      );
    });
  });

  // ── occursOnDate — monthly fixed ───────────────────────────────────────

  group('occursOnDate — monthly fixed', () {
    test('basic match on monthDay', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 15);
      final start = DateTime(2025, 1, 15);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 15), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 15), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 3, 15), start),
        isTrue,
      );
    });

    test('wrong day returns false', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 15);
      final start = DateTime(2025, 1, 15);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 14), start),
        isFalse,
      );
    });

    test('interval 2 skips alternate months', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        interval: 2,
        monthDay: 10,
      );
      final start = DateTime(2025, 1, 10);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 10), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 10), start),
        isFalse,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 3, 10), start),
        isTrue,
      );
    });

    test('monthDay 31 in 30-day month falls back to 30th', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 31);
      final start = DateTime(2025, 1, 31);
      // April has 30 days — should match on the 30th.
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 4, 30), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 4, 29), start),
        isFalse,
      );
    });

    test('monthDay 29 in Feb non-leap falls back to 28th', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 29);
      final start = DateTime(2025, 1, 29);
      // 2025 is not a leap year — Feb has 28 days.
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 28), start),
        isTrue,
      );
    });

    test('monthDay 29 in Feb leap year matches 29th', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 29);
      final start = DateTime(2024, 1, 29);
      // 2024 is a leap year.
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2024, 2, 29), start),
        isTrue,
      );
    });
  });

  // ── occursOnDate — monthly relative ────────────────────────────────────

  group('occursOnDate — monthly relative', () {
    test('2nd Tuesday matches correct date', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        weekOfMonth: 2,
        dayOfWeek: 2, // Tuesday
      );
      final start = DateTime(2025, 1, 14); // 2nd Tuesday of Jan 2025
      // Feb 2025: 2nd Tuesday = Feb 11
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 11), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 4), start),
        isFalse,
      );
    });

    test('last Friday (weekOfMonth=5) matches final Friday', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        weekOfMonth: 5,
        dayOfWeek: 5, // Friday
      );
      final start = DateTime(2025, 1, 31); // Last Friday of Jan 2025
      // Feb 2025: last Friday = Feb 28
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 28), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 21), start),
        isFalse,
      );
    });

    test('wrong weekday returns false', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        weekOfMonth: 2,
        dayOfWeek: 2, // Tuesday
      );
      final start = DateTime(2025, 1, 14);
      // Jan 15 2025 is Wednesday, not Tuesday
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 15), start),
        isFalse,
      );
    });

    test('weekOfMonth=5 with 5 occurrences of a weekday matches the 5th', () {
      // October 2025 has 5 Fridays: 3, 10, 17, 24, 31
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        weekOfMonth: 5,
        dayOfWeek: 5, // Friday
      );
      final start = DateTime(2025, 1, 31);
      // The last Friday = Oct 31
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 10, 31), start),
        isTrue,
      );
      // The 4th Friday (Oct 24) is not the last
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 10, 24), start),
        isFalse,
      );
    });
  });

  // ── occursOnDate — yearly ──────────────────────────────────────────────

  group('occursOnDate — yearly', () {
    test('basic month + day match', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.yearly,
        monthOfYear: 3,
        monthDay: 14,
      );
      final start = DateTime(2025, 3, 14);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 3, 14), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2026, 3, 14), start),
        isTrue,
      );
    });

    test('wrong month returns false', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.yearly,
        monthOfYear: 3,
        monthDay: 14,
      );
      final start = DateTime(2025, 3, 14);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 4, 14), start),
        isFalse,
      );
    });

    test('interval 2 skips alternate years', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.yearly,
        interval: 2,
        monthOfYear: 7,
        monthDay: 4,
      );
      final start = DateTime(2025, 7, 4);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 7, 4), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2026, 7, 4), start),
        isFalse,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2027, 7, 4), start),
        isTrue,
      );
    });

    test('Feb 29 in non-leap year falls back to Feb 28', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.yearly,
        monthOfYear: 2,
        monthDay: 29,
      );
      final start = DateTime(2024, 2, 29);
      // 2025 is not a leap year.
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 28), start),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 2, 27), start),
        isFalse,
      );
    });

    test('missing monthOfYear or monthDay returns false', () {
      final ruleNoMonth = RecurrenceRule(
        type: RecurrenceType.yearly,
        monthDay: 14,
      );
      final ruleNoDay = RecurrenceRule(
        type: RecurrenceType.yearly,
        monthOfYear: 3,
      );
      final start = DateTime(2025, 3, 14);
      expect(
        RecurrenceEngine.occursOnDate(
          ruleNoMonth,
          DateTime(2025, 3, 14),
          start,
        ),
        isFalse,
      );
      expect(
        RecurrenceEngine.occursOnDate(ruleNoDay, DateTime(2025, 3, 14), start),
        isFalse,
      );
    });
  });

  // ── occursOnDate — boundaries ──────────────────────────────────────────

  group('occursOnDate — boundaries', () {
    test('date == startDate returns true', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 1);
      expect(RecurrenceEngine.occursOnDate(rule, start, start), isTrue);
    });

    test('date == endDate returns true (inclusive)', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.daily,
        endType: RecurrenceEndType.onDate,
        endDate: DateTime(2025, 1, 10),
      );
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 10), start),
        isTrue,
      );
    });

    test('one day before startDate returns false', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 5);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 4), start),
        isFalse,
      );
    });

    test('one day after endDate returns false', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.daily,
        endType: RecurrenceEndType.onDate,
        endDate: DateTime(2025, 1, 10),
      );
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 11), start),
        isFalse,
      );
    });

    test('null endDate means no upper bound', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 1);
      // Far future date.
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2030, 6, 15), start),
        isTrue,
      );
    });
  });

  // ── occursOnDate — time normalization ──────────────────────────────────

  group('occursOnDate — time normalization', () {
    test('non-midnight times still match correctly', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily, interval: 2);
      final start = DateTime(2025, 1, 1, 14, 30);
      // Day 0 with time component — should match.
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 1, 8, 0), start),
        isTrue,
      );
      // Day 2 with time component — should match.
      expect(
        RecurrenceEngine.occursOnDate(
          rule,
          DateTime(2025, 1, 3, 23, 59),
          start,
        ),
        isTrue,
      );
      // Day 1 — should not match.
      expect(
        RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 2, 12, 0), start),
        isFalse,
      );
    });
  });

  // ── nextOccurrences ────────────────────────────────────────────────────

  group('nextOccurrences', () {
    test('returns requested count for unbounded rule', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 1);
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 3,
      );
      expect(results, [
        DateTime(2025, 1, 2),
        DateTime(2025, 1, 3),
        DateTime(2025, 1, 4),
      ]);
    });

    test('stops early when endDate is reached', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.daily,
        endType: RecurrenceEndType.onDate,
        endDate: DateTime(2025, 1, 3),
      );
      final start = DateTime(2025, 1, 1);
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 10,
      );
      expect(results, [DateTime(2025, 1, 2), DateTime(2025, 1, 3)]);
    });

    test('weekly rule skips non-selected days', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.weekly,
        daysOfWeek: [1, 5], // Monday, Friday
      );
      final start = DateTime(2025, 1, 6); // Monday
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 3,
      );
      expect(results, [
        DateTime(2025, 1, 10), // Friday
        DateTime(2025, 1, 13), // Monday
        DateTime(2025, 1, 17), // Friday
      ]);
    });

    test('daily rule returns consecutive days', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily, interval: 1);
      final start = DateTime(2025, 3, 1);
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        DateTime(2025, 3, 5),
        count: 3,
      );
      expect(results, [
        DateTime(2025, 3, 6),
        DateTime(2025, 3, 7),
        DateTime(2025, 3, 8),
      ]);
    });

    test('yearly rule returns occurrences across multiple years', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.yearly,
        monthOfYear: 6,
        monthDay: 15,
      );
      final start = DateTime(2025, 6, 15);
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 5,
      );
      expect(results, [
        DateTime(2026, 6, 15),
        DateTime(2027, 6, 15),
        DateTime(2028, 6, 15),
        DateTime(2029, 6, 15),
        DateTime(2030, 6, 15),
      ]);
    });
  });

  // ── computeEndDateFromCount ────────────────────────────────────────────

  group('computeEndDateFromCount', () {
    test('count 1 for daily rule returns start date', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 1);
      expect(RecurrenceEngine.computeEndDateFromCount(rule, start, 1), start);
    });

    test('count 10 for weekly rule returns 10th occurrence', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.weekly,
        daysOfWeek: [1], // Monday only
      );
      final start = DateTime(2025, 1, 6); // Monday
      // 10th Monday from Jan 6 = March 10
      final result = RecurrenceEngine.computeEndDateFromCount(rule, start, 10);
      expect(result, DateTime(2025, 3, 10));
    });

    test('count < 1 returns null', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 1);
      expect(RecurrenceEngine.computeEndDateFromCount(rule, start, 0), isNull);
      expect(RecurrenceEngine.computeEndDateFromCount(rule, start, -1), isNull);
    });

    test('ignores existing endDate on the rule', () {
      // Rule has a restrictive endDate of Jan 5, but we ask for 10 occurrences.
      final rule = RecurrenceRule(
        type: RecurrenceType.daily,
        endType: RecurrenceEndType.onDate,
        endDate: DateTime(2025, 1, 5),
      );
      final start = DateTime(2025, 1, 1);
      // Should still return the 10th day, ignoring the endDate.
      expect(
        RecurrenceEngine.computeEndDateFromCount(rule, start, 10),
        DateTime(2025, 1, 10),
      );
    });

    test('maxCount returns null when count exceeds it', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.computeEndDateFromCount(
          rule,
          start,
          500,
          maxCount: 100,
        ),
        isNull,
      );
    });

    test('maxCount allows count within limit', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily);
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.computeEndDateFromCount(rule, start, 5, maxCount: 100),
        DateTime(2025, 1, 5),
      );
    });

    test('yearly interval 10 computes correctly without safety limit', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.yearly,
        interval: 10,
        monthOfYear: 3,
        monthDay: 1,
      );
      final start = DateTime(2025, 3, 1);
      final result = RecurrenceEngine.computeEndDateFromCount(rule, start, 5);
      expect(result, DateTime(2065, 3, 1));
    });
  });

  // ── Invalid/incomplete rules ───────────────────────────────────────────

  group('invalid rule handling', () {
    test('nextOccurrences with null daysOfWeek returns empty', () {
      final rule = RecurrenceRule(type: RecurrenceType.weekly);
      final start = DateTime(2025, 1, 6);
      expect(
        RecurrenceEngine.nextOccurrences(rule, start, start, count: 5),
        isEmpty,
      );
    });

    test('nextOccurrences with empty daysOfWeek returns empty', () {
      final rule = RecurrenceRule(type: RecurrenceType.weekly, daysOfWeek: []);
      final start = DateTime(2025, 1, 6);
      expect(
        RecurrenceEngine.nextOccurrences(rule, start, start, count: 5),
        isEmpty,
      );
    });

    test('nextOccurrences monthly with null monthDay returns empty', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly);
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.nextOccurrences(rule, start, start, count: 5),
        isEmpty,
      );
    });

    test('nextOccurrences yearly with null fields returns empty', () {
      final rule = RecurrenceRule(type: RecurrenceType.yearly);
      final start = DateTime(2025, 1, 1);
      expect(
        RecurrenceEngine.nextOccurrences(rule, start, start, count: 5),
        isEmpty,
      );
    });

    test('computeEndDateFromCount with incomplete rule returns null', () {
      final rule = RecurrenceRule(type: RecurrenceType.yearly);
      final start = DateTime(2025, 1, 1);
      expect(RecurrenceEngine.computeEndDateFromCount(rule, start, 5), isNull);
    });
  });

  // ── Direct-jump large intervals ────────────────────────────────────────

  group('large interval jumps', () {
    test('yearly interval 3 returns 5 occurrences', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.yearly,
        interval: 3,
        monthOfYear: 7,
        monthDay: 4,
      );
      final start = DateTime(2025, 7, 4);
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 5,
      );
      expect(results, [
        DateTime(2028, 7, 4),
        DateTime(2031, 7, 4),
        DateTime(2034, 7, 4),
        DateTime(2037, 7, 4),
        DateTime(2040, 7, 4),
      ]);
    });

    test('monthly interval 6 returns correct occurrences', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        interval: 6,
        monthDay: 15,
      );
      final start = DateTime(2025, 1, 15);
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 4,
      );
      expect(results, [
        DateTime(2025, 7, 15),
        DateTime(2026, 1, 15),
        DateTime(2026, 7, 15),
        DateTime(2027, 1, 15),
      ]);
    });

    test('daily interval 100 returns correct occurrences', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily, interval: 100);
      final start = DateTime(2025, 1, 1);
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 3,
      );
      expect(results, [
        DateTime(2025, 4, 11),
        DateTime(2025, 7, 20),
        DateTime(2025, 10, 28),
      ]);
    });

    test('weekly interval 4 with multiple days returns correct pattern', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.weekly,
        interval: 4,
        daysOfWeek: [1, 5], // Monday, Friday
      );
      final start = DateTime(2025, 1, 6); // Monday, week 0
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 4,
      );
      expect(results, [
        DateTime(2025, 1, 10), // Friday week 0
        DateTime(2025, 2, 3), // Monday week 4
        DateTime(2025, 2, 7), // Friday week 4
        DateTime(2025, 3, 3), // Monday week 8
      ]);
    });

    test('monthly relative "last Friday" jumps correctly', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        weekOfMonth: 5,
        dayOfWeek: 5,
      );
      final start = DateTime(2025, 1, 31); // Last Friday of Jan
      final results = RecurrenceEngine.nextOccurrences(
        rule,
        start,
        start,
        count: 4,
      );
      expect(results, [
        DateTime(2025, 2, 28),
        DateTime(2025, 3, 28),
        DateTime(2025, 4, 25),
        DateTime(2025, 5, 30),
      ]);
    });
  });
}
