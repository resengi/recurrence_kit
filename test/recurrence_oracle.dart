/// A naive, independent implementation of the recurrence contract for
/// cross-checking [RecurrenceEngine].
///
/// It shares no code with the engine: it walks calendar days one at a time
/// to enumerate a schedule, and steps aligned months or years through one
/// full calendar cycle to prove that a rule never matches. Dart's own
/// [DateTime] normalization supplies month lengths and weekdays.
library;

import 'package:recurrence_kit/recurrence_kit.dart';

DateTime oracleDay(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime oraclePlusDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

int _daysFrom(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

int _monthLength(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime _mondayOf(DateTime date) => oraclePlusDays(date, 1 - date.weekday);

int? _targetDay(int year, int month, int day, MissingDay missingDay) {
  final length = _monthLength(year, month);
  if (day <= length) return day;
  return missingDay == MissingDay.skip ? null : length;
}

/// Whether [date] is the [position]-th occurrence of its weekday within
/// its month: the last when no later date in the month shares the weekday,
/// otherwise by which seven-day block of the month it falls in.
bool _atPosition(DateTime date, WeekPosition position) =>
    position == WeekPosition.last
    ? date.day + 7 > _monthLength(date.year, date.month)
    : (date.day - 1) ~/ 7 == position.index;

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// Whether [date] matches [pattern] anchored at [start]; false before
/// [start].
bool oracleMatches(RecurrencePattern pattern, DateTime start, DateTime date) {
  if (date.isBefore(start)) return false;
  final monthsFromStart =
      (date.year - start.year) * 12 + (date.month - start.month);
  return switch (pattern) {
    Daily(:final interval) => _daysFrom(start, date) % interval == 0,
    Weekly(:final interval, :final weekdays) =>
      weekdays.contains(date.weekday) &&
          (_daysFrom(_mondayOf(start), _mondayOf(date)) ~/ 7) % interval == 0,
    MonthlyByDay(:final interval, :final day, :final missingDay) =>
      monthsFromStart % interval == 0 &&
          _targetDay(date.year, date.month, day, missingDay) == date.day,
    MonthlyByWeekday(:final interval, :final position, :final weekday) =>
      date.weekday == weekday &&
          monthsFromStart % interval == 0 &&
          _atPosition(date, position),
    Yearly(:final interval, :final month, :final day, :final missingDay) =>
      (date.year - start.year) % interval == 0 &&
          date.month == month &&
          _targetDay(date.year, month, day, missingDay) == date.day,
  };
}

/// Whether [pattern] anchored at [start] matches no date at all, proven by
/// stepping aligned months or years through one full cycle of the
/// calendar's month-length and leap-year state. Only skip-mode patterns
/// can be empty.
bool oracleNeverMatches(RecurrencePattern pattern, DateTime start) {
  switch (pattern) {
    case MonthlyByDay(:final interval, :final day, :final missingDay)
        when missingDay == MissingDay.skip:
      final steps = 4800 ~/ _gcd(interval, 4800);
      for (var n = 0; n < steps; n++) {
        final months = (start.month - 1) + n * interval;
        if (day <= _monthLength(start.year + months ~/ 12, months % 12 + 1)) {
          return false;
        }
      }
      return true;
    case Yearly(:final interval, :final month, :final day, :final missingDay)
        when missingDay == MissingDay.skip:
      final steps = 400 ~/ _gcd(interval, 400);
      for (var n = 0; n < steps; n++) {
        if (day <= _monthLength(start.year + n * interval, month)) return false;
      }
      return true;
    default:
      return false;
  }
}

/// The base sequence of [rule] from [start] through [until], walked day by
/// day.
List<DateTime> oracleBaseDates(
  RecurrenceRule rule,
  DateTime start,
  DateTime until,
) {
  final first = oracleDay(start);
  final dates = <DateTime>[];
  if (rule.includeStartDate) dates.add(first);
  for (var date = first; !date.isAfter(until); date = oraclePlusDays(date, 1)) {
    if (rule.includeStartDate && date == first) continue;
    if (oracleMatches(rule.pattern, first, date)) dates.add(date);
  }
  return dates;
}

/// The occurrences of [rule] from [start] through [until]. Exact for every
/// date up to [until]: the after-N bound keeps a prefix of the base
/// sequence, and the dates through [until] are a prefix of it.
List<DateTime> oracleOccurrences(
  RecurrenceRule rule,
  DateTime start,
  DateTime until,
) {
  final base = oracleBaseDates(rule, start, until);
  return switch (rule.end) {
    NeverEnds() => base,
    EndsOnDate(:final date) => base.where((d) => !d.isAfter(date)).toList(),
    EndsAfterCount(:final count) => base.take(count).toList(),
  };
}

/// Whether [occurrences], computed through [until], is the entire
/// schedule: the end date lies within the walked span, the after-N bound
/// was reached, or the base sequence is proven finite.
bool oracleIsComplete(
  RecurrenceRule rule,
  DateTime start,
  DateTime until,
  List<DateTime> occurrences,
) {
  final finiteBase = oracleNeverMatches(rule.pattern, oracleDay(start));
  return switch (rule.end) {
    NeverEnds() => finiteBase,
    EndsOnDate(:final date) => !until.isBefore(date) || finiteBase,
    EndsAfterCount(:final count) => occurrences.length == count || finiteBase,
  };
}
