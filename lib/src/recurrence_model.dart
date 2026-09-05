import 'calendar.dart';

// ── Options ──────────────────────────────────────────────────────────────

/// Which occurrence of a weekday within a month a [MonthlyByWeekday] rule
/// targets.
enum WeekPosition { first, second, third, fourth, last }

/// What a [MonthlyByDay] or [Yearly] rule does in a month that lacks its
/// target day: days 29–31 in shorter months, and February 29 in non-leap
/// years.
enum MissingDay {
  /// The occurrence falls on the month's last day.
  useLastDay,

  /// The month produces no occurrence.
  skip,
}

// ── Patterns ─────────────────────────────────────────────────────────────

/// The repeating part of a `RecurrenceRule`: one of five cadences, each
/// carrying an [interval] of at least 1.
///
/// Every variant validates its fields at construction and throws an
/// [ArgumentError] for values outside the documented ranges. Instances are
/// immutable value objects with structural equality.
sealed class RecurrencePattern {
  RecurrencePattern._(int interval)
    : interval = _checkedMin(interval, 'interval', min: 1);

  /// Every N days, weeks, months, or years.
  final int interval;

  /// A copy with [interval] replaced.
  RecurrencePattern copyWith({int? interval});
}

/// Repeats every [interval] days.
final class Daily extends RecurrencePattern {
  Daily({int interval = 1}) : super._(interval);

  @override
  Daily copyWith({int? interval}) => Daily(interval: interval ?? this.interval);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Daily && interval == other.interval;

  @override
  int get hashCode => Object.hash(Daily, interval);
}

/// Repeats on [weekdays] every [interval] weeks.
final class Weekly extends RecurrencePattern {
  /// [weekdays] are ISO weekdays (1 = Monday … 7 = Sunday) and must contain
  /// at least one; they are stored sorted, without duplicates, and
  /// unmodifiable.
  Weekly({required Iterable<int> weekdays, int interval = 1})
    : weekdays = _canonicalWeekdays(weekdays),
      super._(interval);

  /// Sorted, duplicate-free, non-empty, unmodifiable ISO weekdays.
  final List<int> weekdays;

  static List<int> _canonicalWeekdays(Iterable<int> weekdays) {
    final canonical = weekdays.toSet().toList()..sort();
    if (canonical.isEmpty) {
      throw ArgumentError.value(weekdays, 'weekdays', 'must not be empty');
    }
    for (final weekday in canonical) {
      _checkedRange(weekday, 'weekdays', min: 1, max: 7);
    }
    return List.unmodifiable(canonical);
  }

  @override
  Weekly copyWith({int? interval, Iterable<int>? weekdays}) => Weekly(
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Weekly &&
          interval == other.interval &&
          _sameWeekdays(other.weekdays);

  bool _sameWeekdays(List<int> other) {
    if (weekdays.length != other.length) return false;
    for (var i = 0; i < weekdays.length; i++) {
      if (weekdays[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Weekly, interval, Object.hashAll(weekdays));
}

/// Repeats on [day] of the month every [interval] months.
final class MonthlyByDay extends RecurrencePattern {
  /// [day] is 1–31. Months shorter than [day] behave per [missingDay].
  MonthlyByDay({
    required int day,
    int interval = 1,
    this.missingDay = MissingDay.useLastDay,
  }) : day = _checkedRange(day, 'day', min: 1, max: 31),
       super._(interval);

  /// Day of the month, 1–31.
  final int day;

  /// Behavior in months that have fewer than [day] days.
  final MissingDay missingDay;

  @override
  MonthlyByDay copyWith({int? interval, int? day, MissingDay? missingDay}) =>
      MonthlyByDay(
        interval: interval ?? this.interval,
        day: day ?? this.day,
        missingDay: missingDay ?? this.missingDay,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyByDay &&
          interval == other.interval &&
          day == other.day &&
          missingDay == other.missingDay;

  @override
  int get hashCode => Object.hash(MonthlyByDay, interval, day, missingDay);
}

/// Repeats on the [position]-th [weekday] of the month every [interval]
/// months.
final class MonthlyByWeekday extends RecurrencePattern {
  /// [weekday] is an ISO weekday (1 = Monday … 7 = Sunday).
  MonthlyByWeekday({
    required this.position,
    required int weekday,
    int interval = 1,
  }) : weekday = _checkedRange(weekday, 'weekday', min: 1, max: 7),
       super._(interval);

  /// Which occurrence of [weekday] within the month.
  final WeekPosition position;

  /// ISO weekday, 1–7.
  final int weekday;

  @override
  MonthlyByWeekday copyWith({
    int? interval,
    WeekPosition? position,
    int? weekday,
  }) => MonthlyByWeekday(
    interval: interval ?? this.interval,
    position: position ?? this.position,
    weekday: weekday ?? this.weekday,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyByWeekday &&
          interval == other.interval &&
          position == other.position &&
          weekday == other.weekday;

  @override
  int get hashCode =>
      Object.hash(MonthlyByWeekday, interval, position, weekday);
}

/// Repeats on [day] of [month] every [interval] years.
final class Yearly extends RecurrencePattern {
  /// [month] is 1–12 and [day] must exist in that month in some year:
  /// February 29 is accepted, February 30 and April 31 are not. Non-leap
  /// years behave per [missingDay] for February 29.
  Yearly({
    required int month,
    required int day,
    int interval = 1,
    this.missingDay = MissingDay.useLastDay,
  }) : month = _checkedMonth(month),
       day = _checkedDay(day, month),
       super._(interval);

  /// Month of the year, 1–12.
  final int month;

  /// Day of [month], at most the month's greatest length in any year.
  final int day;

  static int _checkedMonth(int month) =>
      _checkedRange(month, 'month', min: 1, max: 12);

  /// Checks [month] itself before consulting its length, so the day bound
  /// never depends on another initializer having run first.
  static int _checkedDay(int day, int month) => _checkedRange(
    day,
    'day',
    min: 1,
    max: maxDaysInMonth(_checkedMonth(month)),
  );

  /// Behavior in years where [month] has fewer than [day] days.
  final MissingDay missingDay;

  @override
  Yearly copyWith({
    int? interval,
    int? month,
    int? day,
    MissingDay? missingDay,
  }) => Yearly(
    interval: interval ?? this.interval,
    month: month ?? this.month,
    day: day ?? this.day,
    missingDay: missingDay ?? this.missingDay,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Yearly &&
          interval == other.interval &&
          month == other.month &&
          day == other.day &&
          missingDay == other.missingDay;

  @override
  int get hashCode => Object.hash(Yearly, interval, month, day, missingDay);
}

// ── Ends ─────────────────────────────────────────────────────────────────

/// How a `RecurrenceRule` ends: never, on a calendar date, or after a
/// number of occurrences.
///
/// Instances are immutable value objects with structural equality.
sealed class RecurrenceEnd {
  const RecurrenceEnd();
}

/// Imposes no end condition.
final class NeverEnds extends RecurrenceEnd {
  const NeverEnds();

  @override
  bool operator ==(Object other) => other is NeverEnds;

  @override
  int get hashCode => (NeverEnds).hashCode;
}

/// Keeps the occurrences on or before [date].
final class EndsOnDate extends RecurrenceEnd {
  /// [date] is reduced to its calendar components.
  EndsOnDate(DateTime date) : date = calendarDate(date);

  /// The inclusive last calendar date, constructed locally from its
  /// components.
  final DateTime date;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EndsOnDate && date == other.date;

  @override
  int get hashCode => Object.hash(EndsOnDate, date);
}

/// Keeps at most the first [count] occurrences.
final class EndsAfterCount extends RecurrenceEnd {
  /// [count] must be at least 1.
  EndsAfterCount(int count) : count = _checkedMin(count, 'count', min: 1);

  /// The maximum number of occurrences, at least 1.
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EndsAfterCount && count == other.count;

  @override
  int get hashCode => Object.hash(EndsAfterCount, count);
}

// ── Argument checks ──────────────────────────────────────────────────────

/// Returns [value] when it lies within [min]..[max] inclusive; otherwise
/// throws an [ArgumentError] naming [name].
int _checkedRange(
  int value,
  String name, {
  required int min,
  required int max,
}) {
  if (value < min || value > max) {
    throw ArgumentError.value(value, name, 'must be $min-$max');
  }
  return value;
}

/// Returns [value] when it is at least [min]; otherwise throws an
/// [ArgumentError] naming [name].
int _checkedMin(int value, String name, {required int min}) {
  if (value < min) {
    throw ArgumentError.value(value, name, 'must be >= $min');
  }
  return value;
}
