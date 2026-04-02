import 'recurrence_rule.dart';
import 'recurrence_type.dart';

/// Pure stateless logic for recurrence computation.
///
/// All methods are static — no instantiation needed. The engine operates
/// solely on [RecurrenceRule] and [DateTime], with no Flutter or persistence
/// dependencies.
///
/// ```dart
/// final rule = RecurrenceRule(
///   type: RecurrenceType.weekly,
///   daysOfWeek: [1, 5], // Monday, Friday
/// );
/// final start = DateTime(2025, 1, 6); // a Monday
///
/// // Check a specific date
/// RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 10), start); // true (Friday)
///
/// // Get upcoming occurrences
/// RecurrenceEngine.nextOccurrences(rule, start, start, count: 3);
///
/// // Pre-compute end date for "after N times" rules
/// RecurrenceEngine.computeEndDateFromCount(rule, start, 10);
/// ```
abstract final class RecurrenceEngine {
  // ── Internals ──────────────────────────────────────────────────────────

  /// Computes the number of calendar days between [from] and [to].
  ///
  /// Uses UTC to avoid DST-induced off-by-one errors from
  /// `DateTime.difference().inDays`, which can truncate incorrectly when
  /// a daylight saving transition falls between the two dates.
  static int _daysBetween(DateTime from, DateTime to) {
    final f = DateTime.utc(from.year, from.month, from.day);
    final t = DateTime.utc(to.year, to.month, to.day);
    return t.difference(f).inDays;
  }

  // ── Public predicate ───────────────────────────────────────────────────

  /// Whether [rule] produces an occurrence on [date], given a [startDate].
  ///
  /// All three dates are normalized to midnight internally, so time
  /// components are ignored. The recurrence boundary is read from
  /// [rule.endDate] — callers do not pass an external end date.
  static bool occursOnDate(
    RecurrenceRule rule,
    DateTime date,
    DateTime startDate,
  ) {
    // Normalize all dates to midnight.
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = rule.endDate != null
        ? DateTime(rule.endDate!.year, rule.endDate!.month, rule.endDate!.day)
        : null;

    // Before start or after end?
    if (d.isBefore(s)) return false;
    if (e != null && d.isAfter(e)) return false;

    switch (rule.type) {
      case RecurrenceType.daily:
        final daysDiff = _daysBetween(s, d);
        return daysDiff % rule.interval == 0;

      case RecurrenceType.weekly:
        final days = rule.daysOfWeek;
        if (days == null || days.isEmpty) return false;

        // Check if this day-of-week is in the set (ISO: 1=Mon..7=Sun).
        if (!days.contains(d.weekday)) return false;

        // Check interval: which week number (0-based) is this date in,
        // relative to the start date's week?
        if (rule.interval <= 1) return true;

        // Find the Monday of startDate's week and this date's week.
        // Uses component math rather than Duration subtraction to avoid
        // DST-induced off-by-one errors on the day boundary.
        final startMonday = DateTime(s.year, s.month, s.day - (s.weekday - 1));
        final dateMonday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
        final weeksDiff = _daysBetween(startMonday, dateMonday) ~/ 7;
        return weeksDiff % rule.interval == 0;

      case RecurrenceType.monthly:
        return _occursOnDateMonthly(rule, d, s);

      case RecurrenceType.yearly:
        return _occursOnDateYearly(rule, d, s);
    }
  }

  /// Monthly (fixed date): date.day == rule.monthDay and month difference
  /// from start is divisible by interval. Months shorter than monthDay
  /// are skipped.
  ///
  /// Monthly (relative weekday): find the Nth occurrence of rule.dayOfWeek
  /// in the target month. Value 5 = "last".
  static bool _occursOnDateMonthly(
    RecurrenceRule rule,
    DateTime d,
    DateTime s,
  ) {
    // Month difference from start.
    final monthsDiff = (d.year - s.year) * 12 + (d.month - s.month);
    if (monthsDiff < 0) return false;
    if (rule.interval > 1 && monthsDiff % rule.interval != 0) return false;

    if (rule.isRelativeMonthly) {
      // Relative weekday mode: "Nth [weekday] of the month".
      final targetWeekday = rule.dayOfWeek!;
      final targetWeek = rule.weekOfMonth!; // 1–4 literal, 5 = last

      if (d.weekday != targetWeekday) return false;

      if (targetWeek == 5) {
        // "Last [weekday]": check that no further occurrence of this
        // weekday exists in the same month (i.e. day + 7 > daysInMonth).
        final daysInMonth = DateTime(d.year, d.month + 1, 0).day;
        return d.day + 7 > daysInMonth;
      }

      // Literal Nth: the Nth occurrence of this weekday falls on days
      // (N-1)*7+1 through N*7. Equivalently: ((day - 1) ~/ 7) + 1 == N.
      final weekOccurrence = ((d.day - 1) ~/ 7) + 1;
      return weekOccurrence == targetWeek;
    }

    // Fixed date mode: "on the Xth of the month".
    if (rule.monthDay == null) return false;

    // Months shorter than monthDay: fall back to the last day of the month
    // (e.g. monthDay 31 → 30th in April, 28th/29th in February).
    final daysInMonth = DateTime(d.year, d.month + 1, 0).day;
    if (rule.monthDay! > daysInMonth) return d.day == daysInMonth;

    return d.day == rule.monthDay;
  }

  /// Yearly: date.month == rule.monthOfYear && date.day == rule.monthDay
  /// and year difference from start is divisible by interval.
  static bool _occursOnDateYearly(RecurrenceRule rule, DateTime d, DateTime s) {
    if (rule.monthOfYear == null || rule.monthDay == null) return false;
    if (d.month != rule.monthOfYear) return false;

    // Fall back to last day of month when monthDay exceeds days in month
    // (e.g. Feb 29 recurring yearly → Feb 28 in non-leap years).
    final daysInMonth = DateTime(d.year, d.month + 1, 0).day;
    if (rule.monthDay! > daysInMonth) {
      if (d.day != daysInMonth) return false;
    } else {
      if (d.day != rule.monthDay) return false;
    }

    final yearsDiff = d.year - s.year;
    if (yearsDiff < 0) return false;
    if (rule.interval > 1 && yearsDiff % rule.interval != 0) return false;

    return true;
  }

  // ── Direct-jump internals ──────────────────────────────────────────────

  /// Returns the first occurrence of [rule] on or after [onOrAfter],
  /// given [startDate]. Returns null if no occurrence exists (due to
  /// [rule.endDate] or an incomplete rule).
  ///
  /// Jumps directly to the next matching date arithmetically — does not
  /// iterate day-by-day.
  static DateTime? _nextOccurrenceOnOrAfter(
    RecurrenceRule rule,
    DateTime startDate,
    DateTime onOrAfter,
  ) {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final a = DateTime(onOrAfter.year, onOrAfter.month, onOrAfter.day);
    final endDate = rule.endDate != null
        ? DateTime(rule.endDate!.year, rule.endDate!.month, rule.endDate!.day)
        : null;

    // Effective search start: never before the rule's start date.
    final effective = a.isBefore(s) ? s : a;

    switch (rule.type) {
      case RecurrenceType.daily:
        return _nextDailyOnOrAfter(s, effective, rule.interval, endDate);

      case RecurrenceType.weekly:
        return _nextWeeklyOnOrAfter(
          s,
          effective,
          rule.interval,
          rule.daysOfWeek,
          endDate,
        );

      case RecurrenceType.monthly:
        if (rule.isRelativeMonthly) {
          return _nextMonthlyRelativeOnOrAfter(
            s,
            effective,
            rule.interval,
            rule.dayOfWeek!,
            rule.weekOfMonth!,
            endDate,
          );
        }
        if (rule.monthDay == null) return null;
        return _nextMonthlyFixedOnOrAfter(
          s,
          effective,
          rule.interval,
          rule.monthDay!,
          endDate,
        );

      case RecurrenceType.yearly:
        if (rule.monthOfYear == null || rule.monthDay == null) return null;
        return _nextYearlyOnOrAfter(
          s,
          effective,
          rule.interval,
          rule.monthOfYear!,
          rule.monthDay!,
          endDate,
        );
    }
  }

  /// Daily: jump directly to the next interval-aligned day.
  static DateTime? _nextDailyOnOrAfter(
    DateTime s,
    DateTime a,
    int interval,
    DateTime? endDate,
  ) {
    final daysDiff = _daysBetween(s, a);
    final remainder = daysDiff % interval;
    final candidate = remainder == 0
        ? a
        : DateTime(a.year, a.month, a.day + (interval - remainder));
    if (endDate != null && candidate.isAfter(endDate)) return null;
    return candidate;
  }

  /// Weekly: find the next selected weekday in the current or next
  /// interval-aligned week.
  static DateTime? _nextWeeklyOnOrAfter(
    DateTime s,
    DateTime a,
    int interval,
    List<int>? daysOfWeek,
    DateTime? endDate,
  ) {
    if (daysOfWeek == null || daysOfWeek.isEmpty) return null;
    final sorted = List<int>.from(daysOfWeek)..sort();

    final startMonday = DateTime(s.year, s.month, s.day - (s.weekday - 1));
    final aMonday = DateTime(a.year, a.month, a.day - (a.weekday - 1));
    final weeksDiff = _daysBetween(startMonday, aMonday) ~/ 7;

    // Check if the current week is interval-aligned.
    if (interval <= 1 || weeksDiff % interval == 0) {
      // Look for a selected day >= a's weekday in the current week.
      for (final day in sorted) {
        if (day >= a.weekday) {
          final candidate = DateTime(
            a.year,
            a.month,
            a.day + (day - a.weekday),
          );
          if (endDate != null && candidate.isAfter(endDate)) return null;
          return candidate;
        }
      }
    }

    // No matching day in the current week — jump to the next aligned
    // week's first selected day.
    final remainder = weeksDiff % interval;
    final weeksToNext = (interval <= 1 || remainder == 0)
        ? interval
        : (interval - remainder);
    final nextMonday = DateTime(
      aMonday.year,
      aMonday.month,
      aMonday.day + weeksToNext * 7,
    );
    // sorted.first is the earliest ISO weekday (1=Mon). Monday offset = 0.
    final candidate = DateTime(
      nextMonday.year,
      nextMonday.month,
      nextMonday.day + (sorted.first - 1),
    );
    if (endDate != null && candidate.isAfter(endDate)) return null;
    return candidate;
  }

  /// Monthly (fixed date): jump to the next interval-aligned month and
  /// construct the target date, handling short-month fallback.
  static DateTime? _nextMonthlyFixedOnOrAfter(
    DateTime s,
    DateTime a,
    int interval,
    int monthDay,
    DateTime? endDate,
  ) {
    final monthsDiffFromStart = (a.year - s.year) * 12 + (a.month - s.month);

    // Round up to the next interval-aligned month offset.
    int monthsOffset;
    if (monthsDiffFromStart < 0) {
      monthsOffset = 0;
    } else {
      final remainder = monthsDiffFromStart % interval;
      monthsOffset = remainder == 0
          ? monthsDiffFromStart
          : monthsDiffFromStart + (interval - remainder);
    }

    // Try up to 2 aligned months — the first might have its target day
    // earlier than `a` within the same month.
    for (int attempt = 0; attempt < 2; attempt++) {
      final totalMonths = (s.month - 1) + monthsOffset;
      final targetYear = s.year + totalMonths ~/ 12;
      final targetMonth = totalMonths % 12 + 1;

      final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
      final day = monthDay > daysInMonth ? daysInMonth : monthDay;
      final candidate = DateTime(targetYear, targetMonth, day);

      if (!candidate.isBefore(a)) {
        if (endDate != null && candidate.isAfter(endDate)) return null;
        return candidate;
      }

      monthsOffset += interval;
    }

    return null; // Unreachable for valid inputs.
  }

  /// Computes the date of the Nth occurrence of [weekday] in a given
  /// month, or the last occurrence when [weekOfMonth] is 5.
  static DateTime _nthWeekdayOfMonth(
    int year,
    int month,
    int weekday,
    int weekOfMonth,
  ) {
    if (weekOfMonth == 5) {
      // Last occurrence: start from end of month, walk back.
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final lastDay = DateTime(year, month, daysInMonth);
      final diff = (lastDay.weekday - weekday) % 7;
      return DateTime(year, month, daysInMonth - diff);
    }
    // First occurrence of weekday in the month.
    final firstOfMonth = DateTime(year, month, 1);
    final diff = (weekday - firstOfMonth.weekday + 7) % 7;
    final day = 1 + diff + (weekOfMonth - 1) * 7;
    return DateTime(year, month, day);
  }

  /// Monthly (relative weekday): jump to the next interval-aligned month
  /// and compute the Nth weekday arithmetically.
  static DateTime? _nextMonthlyRelativeOnOrAfter(
    DateTime s,
    DateTime a,
    int interval,
    int targetWeekday,
    int targetWeek,
    DateTime? endDate,
  ) {
    final monthsDiffFromStart = (a.year - s.year) * 12 + (a.month - s.month);

    int monthsOffset;
    if (monthsDiffFromStart < 0) {
      monthsOffset = 0;
    } else {
      final remainder = monthsDiffFromStart % interval;
      monthsOffset = remainder == 0
          ? monthsDiffFromStart
          : monthsDiffFromStart + (interval - remainder);
    }

    // Try up to 2 aligned months.
    for (int attempt = 0; attempt < 2; attempt++) {
      final totalMonths = (s.month - 1) + monthsOffset;
      final targetYear = s.year + totalMonths ~/ 12;
      final targetMonth = totalMonths % 12 + 1;

      final candidate = _nthWeekdayOfMonth(
        targetYear,
        targetMonth,
        targetWeekday,
        targetWeek,
      );

      if (!candidate.isBefore(a)) {
        if (endDate != null && candidate.isAfter(endDate)) return null;
        return candidate;
      }

      monthsOffset += interval;
    }

    return null; // Unreachable for valid inputs.
  }

  /// Yearly: jump to the next interval-aligned year and construct the
  /// target date, handling leap-day fallback.
  static DateTime? _nextYearlyOnOrAfter(
    DateTime s,
    DateTime a,
    int interval,
    int monthOfYear,
    int monthDay,
    DateTime? endDate,
  ) {
    final yearsDiffFromStart = a.year - s.year;

    int yearsOffset;
    if (yearsDiffFromStart < 0) {
      yearsOffset = 0;
    } else {
      final remainder = yearsDiffFromStart % interval;
      yearsOffset = remainder == 0
          ? yearsDiffFromStart
          : yearsDiffFromStart + (interval - remainder);
    }

    // Try up to 2 aligned years — the first might have its target date
    // earlier than `a` within the same year.
    for (int attempt = 0; attempt < 2; attempt++) {
      final targetYear = s.year + yearsOffset;
      final daysInMonth = DateTime(targetYear, monthOfYear + 1, 0).day;
      final day = monthDay > daysInMonth ? daysInMonth : monthDay;
      final candidate = DateTime(targetYear, monthOfYear, day);

      if (!candidate.isBefore(a)) {
        if (endDate != null && candidate.isAfter(endDate)) return null;
        return candidate;
      }

      yearsOffset += interval;
    }

    return null; // Unreachable for valid inputs.
  }

  // ── Public query methods ───────────────────────────────────────────────

  /// Returns the next [count] occurrence dates for a recurrence rule,
  /// starting from [afterDate] (exclusive).
  ///
  /// Jumps directly to each occurrence — does not iterate day-by-day.
  /// Returns fewer than [count] results if [rule.endDate] is reached or
  /// the rule is incomplete.
  static List<DateTime> nextOccurrences(
    RecurrenceRule rule,
    DateTime startDate,
    DateTime afterDate, {
    int count = 5,
  }) {
    final occurrences = <DateTime>[];
    var searchFrom = DateTime(
      afterDate.year,
      afterDate.month,
      afterDate.day + 1,
    );

    for (int i = 0; i < count; i++) {
      final next = _nextOccurrenceOnOrAfter(rule, startDate, searchFrom);
      if (next == null) break;
      occurrences.add(next);
      searchFrom = DateTime(next.year, next.month, next.day + 1);
    }

    return occurrences;
  }

  /// Pre-computes the concrete end date for an "after X occurrences" rule.
  ///
  /// Iterates from [startDate] (inclusive), jumping directly to each
  /// occurrence, and returns the date of the [count]-th occurrence.
  /// Returns null if [count] < 1, the rule is incomplete, or [count]
  /// exceeds [maxCount] (when provided).
  ///
  /// The [rule]'s own endDate is ignored during this computation — the
  /// purpose is to *calculate* what endDate should be.
  ///
  /// Typically called at save time when
  /// `endType == RecurrenceEndType.afterCount`.
  ///
  /// ## Safety cap
  ///
  /// When accepting user-controlled occurrence counts, pass [maxCount] to
  /// guard against unreasonably large values:
  ///
  /// ```dart
  /// RecurrenceEngine.computeEndDateFromCount(
  ///   rule, startDate, userCount,
  ///   maxCount: 1000,
  /// );
  /// ```
  ///
  /// Returns null if [count] exceeds [maxCount].
  static DateTime? computeEndDateFromCount(
    RecurrenceRule rule,
    DateTime startDate,
    int count, {
    int? maxCount,
  }) {
    if (count < 1) return null;
    if (maxCount != null && count > maxCount) return null;

    // Use a copy of the rule with no endDate so the jump logic doesn't
    // short-circuit on a stale boundary.
    final unboundedRule = rule.copyWith(clearEndDate: true, clearEndType: true);

    final s = DateTime(startDate.year, startDate.month, startDate.day);
    var searchFrom = s;
    DateTime? lastFound;

    for (int i = 0; i < count; i++) {
      final next = _nextOccurrenceOnOrAfter(
        unboundedRule,
        startDate,
        searchFrom,
      );
      if (next == null) break;
      lastFound = next;
      searchFrom = DateTime(next.year, next.month, next.day + 1);
    }

    return lastFound;
  }
}
