/// Package-internal naming and formatting shared by `RecurrenceRule` and
/// `RecurrencePicker`.
library;

import 'package:intl/intl.dart';

import 'recurrence_model.dart';

const List<String> _shortDayNames = [
  '',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _longDayNames = [
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthNames = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Mon" … "Sun" for an ISO weekday.
String shortDayName(int weekday) => _shortDayNames[weekday];

/// "Monday" … "Sunday" for an ISO weekday.
String longDayName(int weekday) => _longDayNames[weekday];

/// "January" … "December" for a month number.
String monthName(int month) => _monthNames[month];

/// "1st", "2nd", "3rd", "4th", "11th", "21st", and so on.
String ordinal(int n) {
  final suffix = switch (n % 100) {
    11 || 12 || 13 => 'th',
    _ => switch (n % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    },
  };
  return '$n$suffix';
}

/// "1st" … "4th" or "last" for a week position.
String positionWord(WeekPosition position) =>
    position == WeekPosition.last ? 'last' : ordinal(position.index + 1);

/// Formats a date as a full date string, for example "Jan 15, 2025".
///
/// The default end-date formatter of `RecurrencePicker` when
/// `RecurrencePickerTheme.dateFormatter` is not provided.
String formatFullDate(DateTime date) => DateFormat.yMMMd().format(date);
