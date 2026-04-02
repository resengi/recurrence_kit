/// Package-internal formatting utilities shared by [RecurrenceRule] and
/// [RecurrencePicker].
///
/// Not exported through the public barrel file.
library;

import 'package:intl/intl.dart';

/// Returns an ordinal word for the given week-of-month number.
///
/// Values 1–4 return "1st", "2nd", "3rd", "4th".
/// Value 5 returns "last" (used for the last occurrence of a weekday in a month).
String ordinalWord(int n) {
  if (n == 5) return 'last';
  const ordinals = ['', '1st', '2nd', '3rd', '4th'];
  return (n >= 1 && n <= 4) ? ordinals[n] : '${n}th';
}

/// Formats a [DateTime] as a human-readable full date string.
///
/// Used as the default date formatter when [RecurrencePickerTheme.dateFormatter]
/// is not provided. Example output: "Jan 15, 2025".
String formatFullDate(DateTime date) => DateFormat.yMMMd().format(date);
