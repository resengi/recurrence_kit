import 'calendar.dart';
import 'recurrence_model.dart';
import 'recurrence_rule.dart';

/// Pure, stateless occurrence computation for a schedule — a
/// [RecurrenceRule] paired with a start date.
///
/// All dates are treated as calendar components: time-of-day on any input
/// is ignored, and inputs and results use local calendar-component
/// [DateTime] construction. The semantics of the occurrence sequence are
/// those of the package README.
///
/// Single-occurrence queries and the k-th occurrence are computed by
/// arithmetic on the calendar's fixed cycles and never scan days, months,
/// or years. Enumeration queries cost linear time in the number of dates
/// they return. A query is supported wherever the [DateTime] values
/// required to evaluate it are representable by Dart; near Dart's range
/// limits [DateTime] may throw [ArgumentError].
///
/// ```dart
/// final rule = RecurrenceRule(
///   pattern: Weekly(weekdays: [DateTime.monday, DateTime.friday]),
///   end: const NeverEnds(),
/// );
/// final start = DateTime(2025, 1, 6); // a Monday
///
/// RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 10), start); // true
/// RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, DateTime(2025, 1, 8));
/// // 2025-01-10
/// RecurrenceEngine.occurrencesInRange(
///   rule, start, DateTime(2025, 1, 6), DateTime(2025, 1, 17),
/// );
/// // 2025-01-06, 2025-01-10, 2025-01-13, 2025-01-17
/// ```
abstract final class RecurrenceEngine {
  /// Whether [date] is an occurrence of [rule] started on [startDate].
  static bool occursOnDate(
    RecurrenceRule rule,
    DateTime date,
    DateTime startDate,
  ) => _Schedule(rule, startDate).occursOn(calendarDate(date));

  /// The first occurrence on or after [onOrAfter], or null when there is
  /// none.
  static DateTime? nextOccurrenceOnOrAfter(
    RecurrenceRule rule,
    DateTime startDate,
    DateTime onOrAfter,
  ) => _Schedule(rule, startDate).nextOnOrAfter(calendarDate(onOrAfter));

  /// The last occurrence on or before [onOrBefore], or null when there is
  /// none.
  static DateTime? previousOccurrenceOnOrBefore(
    RecurrenceRule rule,
    DateTime startDate,
    DateTime onOrBefore,
  ) => _Schedule(rule, startDate).previousOnOrBefore(calendarDate(onOrBefore));

  /// Every occurrence from [rangeStart] to [rangeEnd], both inclusive, in
  /// ascending order.
  ///
  /// Throws an [ArgumentError] when [rangeEnd] precedes [rangeStart].
  static List<DateTime> occurrencesInRange(
    RecurrenceRule rule,
    DateTime startDate,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final first = calendarDate(rangeStart);
    final last = calendarDate(rangeEnd);
    if (last.isBefore(first)) {
      throw ArgumentError(
        'rangeEnd ($last) must not precede rangeStart ($first)',
      );
    }
    final schedule = _Schedule(rule, startDate);
    final occurrences = <DateTime>[];
    var cursor = schedule.nextOnOrAfter(first);
    while (cursor != null && !cursor.isAfter(last)) {
      occurrences.add(cursor);
      if (!cursor.isBefore(last)) return occurrences;
      cursor = schedule.nextOnOrAfter(addDays(cursor, 1));
    }
    return occurrences;
  }

  /// The first [count] occurrences on or after [onOrAfter], in ascending
  /// order; fewer when the schedule has fewer.
  ///
  /// A [count] of 0 returns an empty list; a negative [count] throws an
  /// [ArgumentError].
  static List<DateTime> nextOccurrences(
    RecurrenceRule rule,
    DateTime startDate,
    DateTime onOrAfter, {
    required int count,
  }) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be >= 0');
    }
    if (count == 0) return [];
    final schedule = _Schedule(rule, startDate);
    final occurrences = <DateTime>[];
    var cursor = schedule.nextOnOrAfter(calendarDate(onOrAfter));
    while (cursor != null) {
      occurrences.add(cursor);
      if (occurrences.length == count) return occurrences;
      cursor = schedule.nextOnOrAfter(addDays(cursor, 1));
    }
    return occurrences;
  }

  /// The final occurrence of the schedule, or null when the resulting
  /// sequence is empty or unbounded.
  static DateTime? lastOccurrence(RecurrenceRule rule, DateTime startDate) =>
      _Schedule(rule, startDate).lastOccurrence;
}

// ── Schedule ────────────────────────────────────────────────────────────

/// A pattern anchored at a start date, with the start date itself
/// included when the rule asks for it: the base sequence of the README.
class _BaseSequence {
  _BaseSequence(
    RecurrencePattern pattern,
    this.includeStartDate,
    DateTime startDate,
  ) : start = calendarDate(startDate),
      matcher = _Matcher.of(pattern, calendarDate(startDate));

  final DateTime start;
  final bool includeStartDate;
  final _Matcher matcher;

  /// Whether the sequence is finite: empty, or the start date alone.
  bool get isFinite => matcher.isEmpty;

  /// With the start date included, base occurrence k >= 1 is a pattern
  /// match; this is the number of leading matches to skip past it — one
  /// when the start date is itself a match, since that match is already
  /// base occurrence 0.
  int get _matchOffset => includeStartDate && matcher.isMatch(start) ? 1 : 0;

  /// The k-th (0-based) date of the sequence, or null when there is none.
  DateTime? at(int k) {
    if (!includeStartDate) return matcher.matchAt(k);
    if (k == 0) return start;
    return matcher.matchAt(k - 1 + _matchOffset);
  }

  bool contains(DateTime date) {
    if (date.isBefore(start)) return false;
    if (includeStartDate && date == start) return true;
    return matcher.isMatch(date);
  }

  DateTime? nextOnOrAfter(DateTime date) {
    if (!date.isAfter(start)) {
      return includeStartDate ? start : matcher.nextOnOrAfter(start);
    }
    return matcher.nextOnOrAfter(date);
  }

  DateTime? previousOnOrBefore(DateTime date) {
    if (date.isBefore(start)) return null;
    final match = matcher.previousOnOrBefore(date);
    return includeStartDate ? match ?? start : match;
  }
}

/// A base sequence under its end condition, expressed as an [_Extent].
class _Schedule {
  _Schedule(RecurrenceRule rule, DateTime startDate)
    : this._(
        _BaseSequence(rule.pattern, rule.includeStartDate, startDate),
        rule.end,
      );

  _Schedule._(this.base, RecurrenceEnd end) : extent = _extentOf(base, end);

  final _BaseSequence base;
  final _Extent extent;

  static _Extent _extentOf(_BaseSequence base, RecurrenceEnd end) =>
      switch (end) {
        NeverEnds() => base.isFinite ? _finite(base) : const _Unbounded(),
        EndsOnDate(:final date) => _Through(date),
        EndsAfterCount(:final count) =>
          base.isFinite ? _finite(base) : _Through(base.at(count - 1)!),
      };

  /// The extent of a finite base sequence: the start date alone when it is
  /// included, otherwise nothing.
  static _Extent _finite(_BaseSequence base) =>
      base.includeStartDate ? _Through(base.start) : const _Empty();

  bool occursOn(DateTime date) => extent.contains(date) && base.contains(date);

  DateTime? nextOnOrAfter(DateTime date) {
    final next = base.nextOnOrAfter(date);
    return next != null && extent.contains(next) ? next : null;
  }

  DateTime? previousOnOrBefore(DateTime date) => switch (extent) {
    _Empty() => null,
    _Unbounded() => base.previousOnOrBefore(date),
    _Through(:final last) => base.previousOnOrBefore(
      last.isBefore(date) ? last : date,
    ),
  };

  DateTime? get lastOccurrence => switch (extent) {
    _Empty() || _Unbounded() => null,
    _Through(:final last) => base.previousOnOrBefore(last),
  };
}

/// The bound an end condition places on a base sequence.
sealed class _Extent {
  const _Extent();

  bool contains(DateTime date);
}

/// No bound: every base occurrence is an occurrence.
final class _Unbounded extends _Extent {
  const _Unbounded();

  @override
  bool contains(DateTime date) => true;
}

/// No occurrences at all.
final class _Empty extends _Extent {
  const _Empty();

  @override
  bool contains(DateTime date) => false;
}

/// Base occurrences on or before [last].
final class _Through extends _Extent {
  const _Through(this.last);

  final DateTime last;

  @override
  bool contains(DateTime date) => !date.isAfter(last);
}

// ── Pattern matchers ────────────────────────────────────────────────────

/// The ascending sequence of dates on or after a start date that match a
/// pattern anchored there. Every method takes and returns calendar dates.
abstract class _Matcher {
  factory _Matcher.of(RecurrencePattern pattern, DateTime start) =>
      switch (pattern) {
        Daily daily => _DailyMatcher(start, daily),
        Weekly weekly => _WeeklyMatcher(start, weekly),
        MonthlyByDay monthly => _MonthlyByDayMatcher(start, monthly),
        MonthlyByWeekday monthly => _MonthlyByWeekdayMatcher(start, monthly),
        Yearly yearly => _YearlyMatcher(start, yearly),
      };

  /// Whether the sequence has no dates. A non-empty sequence is unbounded.
  bool get isEmpty;

  /// Whether [date] is in the sequence; false before the start date.
  bool isMatch(DateTime date);

  /// The k-th (0-based) date of the sequence, or null when [isEmpty].
  DateTime? matchAt(int k);

  /// The first date of the sequence on or after [date], which must not
  /// precede the start date; null when there is none.
  DateTime? nextOnOrAfter(DateTime date);

  /// The last date of the sequence on or before [date], which must not
  /// precede the start date; null when there is none.
  DateTime? previousOnOrBefore(DateTime date);
}

class _DailyMatcher implements _Matcher {
  _DailyMatcher(this.start, Daily pattern) : interval = pattern.interval;

  final DateTime start;
  final int interval;

  @override
  bool get isEmpty => false;

  @override
  bool isMatch(DateTime date) =>
      !date.isBefore(start) && daysBetween(start, date) % interval == 0;

  @override
  DateTime matchAt(int k) => addDays(start, k * interval);

  @override
  DateTime nextOnOrAfter(DateTime date) {
    assert(!date.isBefore(start));
    final remainder = daysBetween(start, date) % interval;
    return remainder == 0 ? date : addDays(date, interval - remainder);
  }

  @override
  DateTime previousOnOrBefore(DateTime date) {
    assert(!date.isBefore(start));
    return addDays(date, -(daysBetween(start, date) % interval));
  }
}

/// Weeks run Monday–Sunday; a week is aligned when its distance in weeks
/// from the start date's week is a multiple of the interval.
class _WeeklyMatcher implements _Matcher {
  _WeeklyMatcher(this.start, Weekly pattern)
    : interval = pattern.interval,
      weekdays = pattern.weekdays,
      startMonday = mondayOfWeek(start),
      startWeekMatches = pattern.weekdays
          .where((weekday) => weekday >= start.weekday)
          .toList();

  final DateTime start;
  final int interval;

  /// Sorted ascending, non-empty.
  final List<int> weekdays;
  final DateTime startMonday;

  /// The weekdays of the start week that fall on or after the start date.
  final List<int> startWeekMatches;

  int _weekIndex(DateTime date) =>
      daysBetween(startMonday, mondayOfWeek(date)) ~/ 7;

  bool _isAlignedWeek(int weekIndex) => weekIndex % interval == 0;

  DateTime _dateInWeek(int weekIndex, int weekday) =>
      addDays(startMonday, weekIndex * 7 + weekday - DateTime.monday);

  @override
  bool get isEmpty => false;

  @override
  bool isMatch(DateTime date) =>
      !date.isBefore(start) &&
      weekdays.contains(date.weekday) &&
      _isAlignedWeek(_weekIndex(date));

  @override
  DateTime matchAt(int k) {
    if (k < startWeekMatches.length) return _dateInWeek(0, startWeekMatches[k]);
    final afterStartWeek = k - startWeekMatches.length;
    final alignedWeeks = 1 + afterStartWeek ~/ weekdays.length;
    return _dateInWeek(
      alignedWeeks * interval,
      weekdays[afterStartWeek % weekdays.length],
    );
  }

  @override
  DateTime nextOnOrAfter(DateTime date) {
    assert(!date.isBefore(start));
    final weekIndex = _weekIndex(date);
    if (_isAlignedWeek(weekIndex)) {
      for (final weekday in weekdays) {
        if (weekday >= date.weekday) return _dateInWeek(weekIndex, weekday);
      }
    }
    final nextAligned = (weekIndex ~/ interval + 1) * interval;
    return _dateInWeek(nextAligned, weekdays.first);
  }

  @override
  DateTime? previousOnOrBefore(DateTime date) {
    assert(!date.isBefore(start));
    final weekIndex = _weekIndex(date);
    DateTime? candidate;
    if (_isAlignedWeek(weekIndex)) {
      for (final weekday in weekdays.reversed) {
        if (weekday <= date.weekday) {
          candidate = _dateInWeek(weekIndex, weekday);
          break;
        }
      }
    }
    if (candidate == null) {
      if (weekIndex == 0) return null;
      final previousAligned = ((weekIndex - 1) ~/ interval) * interval;
      candidate = _dateInWeek(previousAligned, weekdays.last);
    }
    return candidate.isBefore(start) ? null : candidate;
  }
}

/// Matchers whose sequence advances in aligned steps of whole months or
/// years, where step n covers the unit at index n × interval from the start
/// date's unit and lands on at most one date.
abstract class _SteppedMatcher implements _Matcher {
  _SteppedMatcher(this.start, this.interval, this.landings);

  final DateTime start;
  final int interval;

  /// Which steps land on a date; step n lands exactly when [dateOfStep]
  /// returns a date for n.
  final _PeriodicLandings landings;

  /// Units (months or years) from the start date's unit to [date]'s.
  int unitIndex(DateTime date);

  /// The date step [n] lands on, or null when it lands on nothing. Only
  /// step 0 can land before the start date.
  DateTime? dateOfStep(int n);

  @override
  bool get isEmpty => landings.isEmpty;

  @override
  bool isMatch(DateTime date) {
    if (date.isBefore(start)) return false;
    final unit = unitIndex(date);
    return unit % interval == 0 && dateOfStep(unit ~/ interval) == date;
  }

  /// Landing indices are counted from step 0; the first landing is skipped
  /// when step 0 lands before the start date.
  int get _firstLanding {
    final first = dateOfStep(0);
    return first != null && first.isBefore(start) ? 1 : 0;
  }

  @override
  DateTime? matchAt(int k) {
    final step = landings.stepOfLanding(k + _firstLanding);
    return step == null ? null : dateOfStep(step);
  }

  @override
  DateTime? nextOnOrAfter(DateTime date) {
    assert(!date.isBefore(start));
    final unit = unitIndex(date);
    var step = (unit + interval - 1) ~/ interval;
    if (step * interval == unit) {
      final candidate = dateOfStep(step);
      if (candidate != null && !candidate.isBefore(date)) return candidate;
      step += 1;
    }
    final landing = landings.nextOnOrAfter(step);
    return landing == null ? null : dateOfStep(landing);
  }

  @override
  DateTime? previousOnOrBefore(DateTime date) {
    assert(!date.isBefore(start));
    final unit = unitIndex(date);
    var step = unit ~/ interval;
    if (step * interval == unit) {
      final inUnit = dateOfStep(step);
      if (inUnit != null && !inUnit.isAfter(date)) {
        return inUnit.isBefore(start) ? null : inUnit;
      }
      step -= 1;
    }
    final landing = landings.previousOnOrBefore(step);
    if (landing == null) return null;
    final candidate = dateOfStep(landing)!;
    return candidate.isBefore(start) ? null : candidate;
  }
}

/// The year and month of the month [step] × [interval] months after the
/// month of [start].
(int, int) _yearMonthOfStep(DateTime start, int interval, int step) {
  final months = (start.month - 1) + step * interval;
  return (start.year + months ~/ 12, months % 12 + 1);
}

/// Matchers whose unit is the month.
abstract class _MonthlyMatcher extends _SteppedMatcher {
  _MonthlyMatcher(super.start, super.interval, super.landings);

  @override
  int unitIndex(DateTime date) =>
      (date.year - start.year) * 12 + (date.month - start.month);

  (int, int) yearMonthOfStep(int n) => _yearMonthOfStep(start, interval, n);
}

class _MonthlyByDayMatcher extends _MonthlyMatcher {
  _MonthlyByDayMatcher(DateTime start, MonthlyByDay pattern)
    : day = pattern.day,
      missingDay = pattern.missingDay,
      super(start, pattern.interval, _landingsOf(start, pattern));

  final int day;
  final MissingDay missingDay;

  @override
  DateTime? dateOfStep(int n) {
    final (year, month) = yearMonthOfStep(n);
    final target = targetDayInMonth(year, month, day, missingDay);
    return target == null ? null : DateTime(year, month, target);
  }

  /// The months of the year the steps visit repeat every
  /// 12 / gcd(interval, 12) steps. Under [MissingDay.skip], a step lands
  /// only when its month has the day; February with day 29 depends on the
  /// year, and those Februaries recur at a fixed step in years.
  static _PeriodicLandings _landingsOf(DateTime start, MonthlyByDay pattern) {
    final interval = pattern.interval;
    final stepsPerPeriod = 12 ~/ gcd(interval, 12);
    final always = <int>[];
    int? leapOffset;
    _LeapCycle? leapCycle;
    for (var offset = 0; offset < stepsPerPeriod; offset++) {
      final (year, month) = _yearMonthOfStep(start, interval, offset);
      if (pattern.missingDay == MissingDay.useLastDay) {
        always.add(offset);
      } else if (month == DateTime.february && pattern.day == 29) {
        leapOffset = offset;
        leapCycle = _LeapCycle(
          firstYear: year,
          yearStep: stepsPerPeriod * interval ~/ 12,
        );
      } else if (pattern.day <= maxDaysInMonth(month)) {
        always.add(offset);
      }
    }
    return _PeriodicLandings(
      stepsPerPeriod: stepsPerPeriod,
      alwaysOffsets: always,
      leapOffset: leapOffset,
      leapCycle: leapCycle,
    );
  }
}

class _MonthlyByWeekdayMatcher extends _MonthlyMatcher {
  _MonthlyByWeekdayMatcher(DateTime start, MonthlyByWeekday pattern)
    : position = pattern.position,
      weekday = pattern.weekday,
      super(start, pattern.interval, _PeriodicLandings.everyStep());

  final WeekPosition position;
  final int weekday;

  @override
  DateTime dateOfStep(int n) {
    final (year, month) = yearMonthOfStep(n);
    return nthWeekdayOfMonth(year, month, weekday, position);
  }
}

class _YearlyMatcher extends _SteppedMatcher {
  _YearlyMatcher(DateTime start, Yearly pattern)
    : month = pattern.month,
      day = pattern.day,
      missingDay = pattern.missingDay,
      super(start, pattern.interval, _landingsOf(start, pattern));

  final int month;
  final int day;
  final MissingDay missingDay;

  /// Every step lands, except that February 29 under [MissingDay.skip]
  /// lands only in leap years.
  static _PeriodicLandings _landingsOf(DateTime start, Yearly pattern) {
    final leapDayOnly =
        pattern.missingDay == MissingDay.skip &&
        pattern.month == DateTime.february &&
        pattern.day == 29;
    if (!leapDayOnly) return _PeriodicLandings.everyStep();
    return _PeriodicLandings(
      stepsPerPeriod: 1,
      alwaysOffsets: const [],
      leapOffset: 0,
      leapCycle: _LeapCycle(firstYear: start.year, yearStep: pattern.interval),
    );
  }

  @override
  int unitIndex(DateTime date) => date.year - start.year;

  @override
  DateTime? dateOfStep(int n) {
    final year = start.year + n * interval;
    final target = targetDayInMonth(year, month, day, missingDay);
    return target == null ? null : DateTime(year, month, target);
  }
}

// ── Periodic landings ───────────────────────────────────────────────────

/// Which years of an arithmetic progression are leap years. The pattern
/// repeats every 400 / gcd(yearStep, 400) terms, because the Gregorian
/// leap rule repeats every 400 years.
class _LeapCycle {
  _LeapCycle({required this.firstYear, required this.yearStep})
    : period = 400 ~/ gcd(yearStep, 400);

  final int firstYear;
  final int yearStep;
  final int period;

  bool isLeap(int term) => isLeapYear(firstYear + (term % period) * yearStep);
}

/// The steps of a [_SteppedMatcher] that land on a date, as a periodic
/// structure: within each period of [stepsPerPeriod] steps, the
/// [alwaysOffsets] land in every period and [leapOffset] lands only in
/// periods whose term of [leapCycle] is a leap year. The whole structure
/// repeats every [periodsPerCycle] periods.
class _PeriodicLandings {
  _PeriodicLandings({
    required this.stepsPerPeriod,
    required this.alwaysOffsets,
    this.leapOffset,
    this.leapCycle,
  }) : assert((leapOffset == null) == (leapCycle == null)),
       periodsPerCycle = leapCycle?.period ?? 1,
       _landingsBeforePeriod = _prefixCounts(alwaysOffsets.length, leapCycle);

  /// Every step lands.
  factory _PeriodicLandings.everyStep() =>
      _PeriodicLandings(stepsPerPeriod: 1, alwaysOffsets: const [0]);

  final int stepsPerPeriod;
  final int periodsPerCycle;

  /// Sorted offsets within a period that land in every period.
  final List<int> alwaysOffsets;

  /// The offset within a period that lands only in leap terms.
  final int? leapOffset;
  final _LeapCycle? leapCycle;

  /// `_landingsBeforePeriod[q]` is the number of landings in periods
  /// 0 .. q−1 of a cycle; the last entry is the landings per cycle.
  final List<int> _landingsBeforePeriod;

  static List<int> _prefixCounts(int alwaysCount, _LeapCycle? leapCycle) {
    final periods = leapCycle?.period ?? 1;
    final counts = List.filled(periods + 1, 0);
    for (var period = 0; period < periods; period++) {
      final leapLanding = leapCycle != null && leapCycle.isLeap(period) ? 1 : 0;
      counts[period + 1] = counts[period] + alwaysCount + leapLanding;
    }
    return counts;
  }

  int get stepsPerCycle => stepsPerPeriod * periodsPerCycle;

  int get landingsPerCycle => _landingsBeforePeriod[periodsPerCycle];

  bool get isEmpty => landingsPerCycle == 0;

  /// The landing offsets of [period] within its cycle, ascending.
  List<int> _offsetsIn(int period) {
    final leap = leapOffset;
    if (leap == null || !leapCycle!.isLeap(period)) return alwaysOffsets;
    return [...alwaysOffsets, leap]..sort();
  }

  /// The step of the j-th (0-based) landing, or null when [isEmpty].
  int? stepOfLanding(int j) {
    if (isEmpty) return null;
    final cycle = j ~/ landingsPerCycle;
    final index = j % landingsPerCycle;
    var period = 0;
    while (_landingsBeforePeriod[period + 1] <= index) {
      period++;
    }
    final offset = _offsetsIn(period)[index - _landingsBeforePeriod[period]];
    return cycle * stepsPerCycle + period * stepsPerPeriod + offset;
  }

  /// The first landing step at or after step [n] (n >= 0), or null when
  /// [isEmpty].
  int? nextOnOrAfter(int n) {
    assert(n >= 0);
    if (isEmpty) return null;
    final cycle = n ~/ stepsPerCycle;
    final within = n % stepsPerCycle;
    final fromPeriod = within ~/ stepsPerPeriod;
    final fromOffset = within % stepsPerPeriod;
    for (var period = fromPeriod; period < periodsPerCycle; period++) {
      for (final offset in _offsetsIn(period)) {
        if (period > fromPeriod || offset >= fromOffset) {
          return cycle * stepsPerCycle + period * stepsPerPeriod + offset;
        }
      }
    }
    return (cycle + 1) * stepsPerCycle + stepOfLanding(0)!;
  }

  /// The last landing step at or before step [n], or null when there is
  /// none (including any negative [n]).
  int? previousOnOrBefore(int n) {
    if (isEmpty || n < 0) return null;
    final cycle = n ~/ stepsPerCycle;
    final within = n % stepsPerCycle;
    final fromPeriod = within ~/ stepsPerPeriod;
    final fromOffset = within % stepsPerPeriod;
    for (var period = fromPeriod; period >= 0; period--) {
      for (final offset in _offsetsIn(period).reversed) {
        if (period < fromPeriod || offset <= fromOffset) {
          return cycle * stepsPerCycle + period * stepsPerPeriod + offset;
        }
      }
    }
    if (cycle == 0) return null;
    return (cycle - 1) * stepsPerCycle + stepOfLanding(landingsPerCycle - 1)!;
  }
}
