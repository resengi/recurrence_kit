/// Gregorian calendar arithmetic shared by the model, engine, and picker.
///
/// Every function treats a [DateTime] as calendar components — year,
/// month, and day — and never converts between time zones.
library;

import 'recurrence_model.dart';

const List<int> _daysInMonthOfCommonYear = [
  0,
  31,
  28,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31,
];

/// Whether [year] is a leap year: divisible by 4, except centuries that
/// are not divisible by 400.
bool isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

/// The number of days in [month] of [year].
int daysInMonth(int year, int month) =>
    month == DateTime.february && isLeapYear(year)
    ? 29
    : _daysInMonthOfCommonYear[month];

/// The greatest number of days [month] has in any year.
int maxDaysInMonth(int month) =>
    month == DateTime.february ? 29 : _daysInMonthOfCommonYear[month];

/// A local [DateTime] constructed from [date]'s year, month, and day.
///
/// Time-of-day and the UTC flag are discarded; the components are not
/// converted between time zones.
DateTime calendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// [date] moved by [days] calendar days, constructed locally from the
/// resulting components.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Calendar days from [from] to [to], negative when [to] is earlier.
///
/// Computed in UTC so that daylight-saving transitions between the two
/// dates cannot shift the count.
int daysBetween(DateTime from, DateTime to) {
  final f = DateTime.utc(from.year, from.month, from.day);
  final t = DateTime.utc(to.year, to.month, to.day);
  return t.difference(f).inDays;
}

/// The Monday of the week containing [date].
DateTime mondayOfWeek(DateTime date) =>
    addDays(date, DateTime.monday - date.weekday);

/// The date of the [position]-th [weekday] in [month] of [year].
DateTime nthWeekdayOfMonth(
  int year,
  int month,
  int weekday,
  WeekPosition position,
) {
  if (position == WeekPosition.last) {
    final lastDay = daysInMonth(year, month);
    final lastWeekday = DateTime(year, month, lastDay).weekday;
    return DateTime(year, month, lastDay - (lastWeekday - weekday) % 7);
  }
  final firstWeekday = DateTime(year, month, 1).weekday;
  final firstMatch = 1 + (weekday - firstWeekday) % 7;
  return DateTime(year, month, firstMatch + position.index * 7);
}

/// The day on which a rule targeting [day] falls in [month] of [year]:
/// [day] itself when the month has it, otherwise the month's last day
/// under [MissingDay.useLastDay] or null under [MissingDay.skip].
int? targetDayInMonth(int year, int month, int day, MissingDay missingDay) {
  final length = daysInMonth(year, month);
  if (day <= length) return day;
  return switch (missingDay) {
    MissingDay.useLastDay => length,
    MissingDay.skip => null,
  };
}

/// The week position [date] occupies within its month: [WeekPosition.last]
/// when no later date in the month shares its weekday, otherwise first
/// through fourth.
WeekPosition weekPositionOf(DateTime date) {
  if (date.day + 7 > daysInMonth(date.year, date.month)) {
    return WeekPosition.last;
  }
  return WeekPosition.values[(date.day - 1) ~/ 7];
}

/// The greatest common divisor of two positive integers.
int gcd(int a, int b) {
  var x = a;
  var y = b;
  while (y != 0) {
    final t = x % y;
    x = y;
    y = t;
  }
  return x;
}
