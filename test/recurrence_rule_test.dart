import 'package:flutter_test/flutter_test.dart';
import 'package:recurrence_kit/recurrence_kit.dart';

void main() {
  // ── fromJson / toJson round-trip ────────────────────────────────────────

  group('fromJson / toJson round-trip', () {
    test('daily rule', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.daily,
        interval: 3,
        endType: RecurrenceEndType.onDate,
        endDate: DateTime(2025, 6, 15),
      );
      expect(RecurrenceRule.fromJson(rule.toJson()), equals(rule));
    });

    test('weekly rule with multiple days', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.weekly,
        interval: 2,
        daysOfWeek: [1, 3, 5],
        endType: RecurrenceEndType.afterCount,
        endAfterCount: 10,
        endDate: DateTime(2025, 12, 1),
      );
      expect(RecurrenceRule.fromJson(rule.toJson()), equals(rule));
    });

    test('monthly fixed date rule', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        interval: 1,
        monthDay: 15,
      );
      expect(RecurrenceRule.fromJson(rule.toJson()), equals(rule));
    });

    test('monthly relative weekday rule', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        interval: 2,
        weekOfMonth: 3,
        dayOfWeek: 2,
      );
      expect(RecurrenceRule.fromJson(rule.toJson()), equals(rule));
    });

    test('yearly rule', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.yearly,
        interval: 1,
        monthOfYear: 3,
        monthDay: 14,
      );
      expect(RecurrenceRule.fromJson(rule.toJson()), equals(rule));
    });
  });

  // ── fromJson defaults ──────────────────────────────────────────────────

  group('fromJson defaults', () {
    test('missing keys fall back to defaults', () {
      final rule = RecurrenceRule.fromJson({'type': 'daily'});
      expect(rule.type, RecurrenceType.daily);
      expect(rule.interval, 1);
      expect(rule.daysOfWeek, isNull);
      expect(rule.endType, RecurrenceEndType.never);
      expect(rule.endDate, isNull);
      expect(rule.endAfterCount, isNull);
    });

    test('malformed type falls back to daily', () {
      final rule = RecurrenceRule.fromJson({'type': 'biweekly'});
      expect(rule.type, RecurrenceType.daily);
    });

    test('missing endType defaults to never', () {
      final rule = RecurrenceRule.fromJson({
        'type': 'weekly',
        'daysOfWeek': [1, 5],
      });
      expect(rule.endType, RecurrenceEndType.never);
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────

  group('copyWith', () {
    final base = RecurrenceRule(
      type: RecurrenceType.weekly,
      interval: 2,
      daysOfWeek: [1, 3],
      endType: RecurrenceEndType.afterCount,
      endAfterCount: 5,
      endDate: DateTime(2025, 12, 31),
    );

    test('overrides a single field', () {
      final updated = base.copyWith(interval: 4);
      expect(updated.interval, 4);
      expect(updated.type, base.type);
      expect(updated.daysOfWeek, base.daysOfWeek);
      expect(updated.endType, base.endType);
    });

    test('clearDaysOfWeek nullifies daysOfWeek', () {
      final updated = base.copyWith(clearDaysOfWeek: true);
      expect(updated.daysOfWeek, isNull);
      expect(updated.interval, base.interval);
    });

    test('clearEndDate nullifies endDate', () {
      final updated = base.copyWith(clearEndDate: true);
      expect(updated.endDate, isNull);
      expect(updated.endAfterCount, base.endAfterCount);
    });

    test('clearEndType resets to never', () {
      final updated = base.copyWith(clearEndType: true);
      expect(updated.endType, RecurrenceEndType.never);
    });

    test('clearEndAfterCount nullifies endAfterCount', () {
      final updated = base.copyWith(clearEndAfterCount: true);
      expect(updated.endAfterCount, isNull);
      expect(updated.endType, base.endType);
    });

    test('clearMonthDay nullifies monthDay', () {
      final withMonthDay = RecurrenceRule(
        type: RecurrenceType.monthly,
        monthDay: 15,
      );
      final updated = withMonthDay.copyWith(clearMonthDay: true);
      expect(updated.monthDay, isNull);
    });

    test('clearWeekOfMonth and clearDayOfWeek nullify relative fields', () {
      final relative = RecurrenceRule(
        type: RecurrenceType.monthly,
        weekOfMonth: 2,
        dayOfWeek: 3,
      );
      final updated = relative.copyWith(
        clearWeekOfMonth: true,
        clearDayOfWeek: true,
      );
      expect(updated.weekOfMonth, isNull);
      expect(updated.dayOfWeek, isNull);
    });

    test('clearMonthOfYear nullifies monthOfYear', () {
      final yearly = RecurrenceRule(
        type: RecurrenceType.yearly,
        monthOfYear: 6,
        monthDay: 1,
      );
      final updated = yearly.copyWith(clearMonthOfYear: true);
      expect(updated.monthOfYear, isNull);
    });
  });

  // ── isRelativeMonthly ──────────────────────────────────────────────────

  group('isRelativeMonthly', () {
    test('true when monthly with weekOfMonth and dayOfWeek', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.monthly,
        weekOfMonth: 2,
        dayOfWeek: 2,
      );
      expect(rule.isRelativeMonthly, isTrue);
    });

    test('false when monthly with only monthDay', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 15);
      expect(rule.isRelativeMonthly, isFalse);
    });

    test('false for non-monthly type even with weekOfMonth/dayOfWeek', () {
      final rule = RecurrenceRule(
        type: RecurrenceType.weekly,
        weekOfMonth: 2,
        dayOfWeek: 2,
      );
      expect(rule.isRelativeMonthly, isFalse);
    });
  });

  // ── displayText ────────────────────────────────────────────────────────

  group('displayText', () {
    group('daily', () {
      test('interval 1', () {
        final rule = RecurrenceRule(type: RecurrenceType.daily);
        expect(rule.displayText, 'Every day');
      });

      test('interval > 1', () {
        final rule = RecurrenceRule(type: RecurrenceType.daily, interval: 3);
        expect(rule.displayText, 'Every 3 days');
      });
    });

    group('weekly', () {
      test('single day', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.weekly,
          daysOfWeek: [1],
        );
        expect(rule.displayText, 'Mon');
      });

      test('multiple days sorted', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.weekly,
          daysOfWeek: [5, 1, 3],
        );
        expect(rule.displayText, 'Mon, Wed, Fri');
      });

      test('interval > 1', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.weekly,
          interval: 2,
          daysOfWeek: [1, 5],
        );
        expect(rule.displayText, 'Every 2 weeks: Mon, Fri');
      });

      test('empty daysOfWeek', () {
        final rule = RecurrenceRule(type: RecurrenceType.weekly);
        expect(rule.displayText, 'Weekly');
      });
    });

    group('monthly', () {
      test('fixed date', () {
        final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 15);
        expect(rule.displayText, 'Monthly on the 15th');
      });

      test('monthDay 31 shows last day', () {
        final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 31);
        expect(rule.displayText, 'Monthly on the last day');
      });

      test('monthDay 29 shows parenthetical note', () {
        final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 29);
        expect(
          rule.displayText,
          'Monthly on the 29th (last day in shorter months)',
        );
      });

      test('relative weekday', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.monthly,
          weekOfMonth: 2,
          dayOfWeek: 2,
        );
        expect(rule.displayText, 'Monthly on the 2nd Tuesday');
      });

      test('last weekday', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.monthly,
          weekOfMonth: 5,
          dayOfWeek: 5,
        );
        expect(rule.displayText, 'Monthly on the last Friday');
      });

      test('interval > 1', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.monthly,
          interval: 3,
          monthDay: 1,
        );
        expect(rule.displayText, 'Every 3 months on the 1st');
      });
    });

    group('yearly', () {
      test('basic', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.yearly,
          monthOfYear: 1,
          monthDay: 15,
        );
        expect(rule.displayText, 'Yearly on January 15');
      });

      test('interval > 1', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.yearly,
          interval: 2,
          monthOfYear: 7,
          monthDay: 4,
        );
        expect(rule.displayText, 'Every 2 years on July 4');
      });

      test('Feb 29 shows parenthetical note', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.yearly,
          monthOfYear: 2,
          monthDay: 29,
        );
        expect(
          rule.displayText,
          'Yearly on February 29 (last day in shorter years)',
        );
      });
    });

    group('end suffixes', () {
      test('never shows no suffix', () {
        final rule = RecurrenceRule(type: RecurrenceType.daily);
        expect(rule.displayText, 'Every day');
      });

      test('onDate shows until date', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.daily,
          endType: RecurrenceEndType.onDate,
          endDate: DateTime(2025, 3, 15),
        );
        expect(rule.displayText, 'Every day · until 3/15/2025');
      });

      test('afterCount shows count', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.daily,
          endType: RecurrenceEndType.afterCount,
          endAfterCount: 10,
        );
        expect(rule.displayText, 'Every day · for 10 times');
      });

      test('onDate with null endDate shows no suffix', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.daily,
          endType: RecurrenceEndType.onDate,
        );
        expect(rule.displayText, 'Every day');
      });

      test('afterCount with null count shows no suffix', () {
        final rule = RecurrenceRule(
          type: RecurrenceType.daily,
          endType: RecurrenceEndType.afterCount,
        );
        expect(rule.displayText, 'Every day');
      });
    });
  });

  // ── == and hashCode ────────────────────────────────────────────────────

  group('equality and hashCode', () {
    test('identical rules are equal', () {
      final a = RecurrenceRule(
        type: RecurrenceType.weekly,
        interval: 2,
        daysOfWeek: [1, 3],
      );
      final b = RecurrenceRule(
        type: RecurrenceType.weekly,
        interval: 2,
        daysOfWeek: [1, 3],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing type breaks equality', () {
      final a = RecurrenceRule(type: RecurrenceType.daily);
      final b = RecurrenceRule(type: RecurrenceType.weekly);
      expect(a, isNot(equals(b)));
    });

    test('differing interval breaks equality', () {
      final a = RecurrenceRule(type: RecurrenceType.daily, interval: 1);
      final b = RecurrenceRule(type: RecurrenceType.daily, interval: 2);
      expect(a, isNot(equals(b)));
    });

    test('daysOfWeek order matters', () {
      final a = RecurrenceRule(type: RecurrenceType.weekly, daysOfWeek: [1, 3]);
      final b = RecurrenceRule(type: RecurrenceType.weekly, daysOfWeek: [3, 1]);
      expect(a, isNot(equals(b)));
    });

    test('null vs non-null daysOfWeek breaks equality', () {
      final a = RecurrenceRule(type: RecurrenceType.weekly);
      final b = RecurrenceRule(type: RecurrenceType.weekly, daysOfWeek: [1]);
      expect(a, isNot(equals(b)));
    });

    test('differing endType breaks equality', () {
      final a = RecurrenceRule(type: RecurrenceType.daily);
      final b = RecurrenceRule(
        type: RecurrenceType.daily,
        endType: RecurrenceEndType.onDate,
        endDate: DateTime(2025, 1, 1),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
