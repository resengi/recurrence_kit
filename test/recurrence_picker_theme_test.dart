import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurrence_kit/recurrence_kit.dart';

String _isoDate(DateTime date) => '${date.year}-${date.month}-${date.day}';

void main() {
  group('defaults', () {
    test('functional fields', () {
      const theme = RecurrencePickerTheme();
      expect(theme.datePickerLastDate, isNull);
      expect(theme.defaultEndAfterCount, 10);
      expect(theme.dateFormatter, isNull);
    });
  });

  group('copyWith', () {
    test('replaces the given fields and keeps the rest', () {
      final theme = const RecurrencePickerTheme().copyWith(
        accentColor: Colors.teal,
        defaultEndAfterCount: 5,
      );
      expect(theme.accentColor, Colors.teal);
      expect(theme.defaultEndAfterCount, 5);
      expect(theme.textColor, const RecurrencePickerTheme().textColor);
    });

    test('a null datePickerLastDate retains the current value', () {
      final theme = const RecurrencePickerTheme().copyWith(
        datePickerLastDate: DateTime(2035, 1, 1),
      );
      expect(theme.copyWith().datePickerLastDate, DateTime(2035, 1, 1));
      expect(
        theme.copyWith(datePickerLastDate: null).datePickerLastDate,
        DateTime(2035, 1, 1),
      );
    });

    test('clearDatePickerLastDate restores the default horizon', () {
      final theme = const RecurrencePickerTheme().copyWith(
        datePickerLastDate: DateTime(2035, 1, 1),
        defaultEndAfterCount: 5,
      );
      final restored = theme.copyWith(clearDatePickerLastDate: true);
      expect(restored.datePickerLastDate, isNull);
      expect(restored.defaultEndAfterCount, 5);
    });

    test('a null dateFormatter retains the current value', () {
      final theme = const RecurrencePickerTheme().copyWith(
        dateFormatter: _isoDate,
      );
      expect(theme.copyWith().dateFormatter, _isoDate);
      expect(theme.copyWith(dateFormatter: null).dateFormatter, _isoDate);
    });

    test('clearDateFormatter restores the default formatter', () {
      final theme = const RecurrencePickerTheme().copyWith(
        dateFormatter: _isoDate,
        accentColor: Colors.teal,
      );
      final restored = theme.copyWith(clearDateFormatter: true);
      expect(restored.dateFormatter, isNull);
      expect(restored.accentColor, Colors.teal);
    });
  });
}
