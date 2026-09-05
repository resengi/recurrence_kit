import 'format_helpers.dart';
import 'recurrence_model.dart';

/// A complete, immutable description of a repeating schedule: one
/// [pattern], one [end], and whether the schedule's start date is itself
/// an occurrence.
///
/// A rule does not know its start date. Paired with one by
/// `RecurrenceEngine`, it defines the occurrence sequence described in the
/// package README.
///
/// ```dart
/// final rule = RecurrenceRule(
///   pattern: Weekly(interval: 2, weekdays: [DateTime.monday, DateTime.friday]),
///   end: EndsAfterCount(10),
/// );
/// print(rule.displayText); // "Every 2 weeks: Mon, Fri · for 10 times"
/// ```
final class RecurrenceRule {
  RecurrenceRule({
    required this.pattern,
    required this.end,
    this.includeStartDate = false,
  });

  /// Restores a rule from a [toJson] map.
  ///
  /// Reads exactly the fields belonging to each declared `kind` and ignores
  /// any other key. Integer fields accept any finite number without a
  /// fractional part. Throws a [FormatException] for an unknown kind, a
  /// missing field, a wrong-typed field, an out-of-range value, or a date
  /// whose components do not form a real calendar date.
  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    try {
      return RecurrenceRule(
        pattern: _patternFromJson(_readMap(json, 'pattern')),
        end: _endFromJson(_readMap(json, 'end')),
        includeStartDate: _readBool(json, 'includeStartDate'),
      );
    } on ArgumentError catch (error) {
      throw FormatException('$error');
    }
  }

  /// The repeating cadence.
  final RecurrencePattern pattern;

  /// The end condition.
  final RecurrenceEnd end;

  /// Whether the schedule's start date is occurrence #1 even when it does
  /// not match [pattern].
  final bool includeStartDate;

  /// A copy with the given parts replaced.
  RecurrenceRule copyWith({
    RecurrencePattern? pattern,
    RecurrenceEnd? end,
    bool? includeStartDate,
  }) => RecurrenceRule(
    pattern: pattern ?? this.pattern,
    end: end ?? this.end,
    includeStartDate: includeStartDate ?? this.includeStartDate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceRule &&
          pattern == other.pattern &&
          end == other.end &&
          includeStartDate == other.includeStartDate;

  @override
  int get hashCode => Object.hash(pattern, end, includeStartDate);

  // ── Serialization ─────────────────────────────────────────────────────

  /// A plain map suitable for JSON storage; see [RecurrenceRule.fromJson].
  Map<String, dynamic> toJson() => {
    'pattern': _patternToJson(pattern),
    'end': _endToJson(end),
    'includeStartDate': includeStartDate,
  };

  static Map<String, dynamic> _patternToJson(RecurrencePattern pattern) =>
      switch (pattern) {
        Daily(:final interval) => {'kind': 'daily', 'interval': interval},
        Weekly(:final interval, :final weekdays) => {
          'kind': 'weekly',
          'interval': interval,
          'weekdays': weekdays.toList(),
        },
        MonthlyByDay(:final interval, :final day, :final missingDay) => {
          'kind': 'monthlyByDay',
          'interval': interval,
          'day': day,
          'missingDay': missingDay.name,
        },
        MonthlyByWeekday(:final interval, :final position, :final weekday) => {
          'kind': 'monthlyByWeekday',
          'interval': interval,
          'position': position.name,
          'weekday': weekday,
        },
        Yearly(:final interval, :final month, :final day, :final missingDay) =>
          {
            'kind': 'yearly',
            'interval': interval,
            'month': month,
            'day': day,
            'missingDay': missingDay.name,
          },
      };

  static RecurrencePattern _patternFromJson(Map<String, dynamic> json) =>
      switch (_readString(json, 'kind')) {
        'daily' => Daily(interval: _readInt(json, 'interval')),
        'weekly' => Weekly(
          interval: _readInt(json, 'interval'),
          weekdays: _readIntList(json, 'weekdays'),
        ),
        'monthlyByDay' => MonthlyByDay(
          interval: _readInt(json, 'interval'),
          day: _readInt(json, 'day'),
          missingDay: _readEnum(json, 'missingDay', MissingDay.values),
        ),
        'monthlyByWeekday' => MonthlyByWeekday(
          interval: _readInt(json, 'interval'),
          position: _readEnum(json, 'position', WeekPosition.values),
          weekday: _readInt(json, 'weekday'),
        ),
        'yearly' => Yearly(
          interval: _readInt(json, 'interval'),
          month: _readInt(json, 'month'),
          day: _readInt(json, 'day'),
          missingDay: _readEnum(json, 'missingDay', MissingDay.values),
        ),
        final kind => throw FormatException('Unknown pattern kind: $kind'),
      };

  static Map<String, dynamic> _endToJson(RecurrenceEnd end) => switch (end) {
    NeverEnds() => {'kind': 'never'},
    EndsOnDate(:final date) => {
      'kind': 'onDate',
      'date': {'year': date.year, 'month': date.month, 'day': date.day},
    },
    EndsAfterCount(:final count) => {'kind': 'afterCount', 'count': count},
  };

  static RecurrenceEnd _endFromJson(Map<String, dynamic> json) =>
      switch (_readString(json, 'kind')) {
        'never' => const NeverEnds(),
        'onDate' => EndsOnDate(_readDate(_readMap(json, 'date'))),
        'afterCount' => EndsAfterCount(_readInt(json, 'count')),
        final kind => throw FormatException('Unknown end kind: $kind'),
      };

  /// Reads a `{year, month, day}` object, rejecting components that do not
  /// form a real calendar date. Dart normalizes overflowing components, so
  /// the constructed date is compared against the supplied ones.
  static DateTime _readDate(Map<String, dynamic> json) {
    final year = _readInt(json, 'year');
    final month = _readInt(json, 'month');
    final day = _readInt(json, 'day');
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('Not a calendar date: $year-$month-$day');
    }
    return date;
  }

  static Object _readRequired(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) throw FormatException('Missing field: $key');
    return value;
  }

  static Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
    final value = _readRequired(json, key);
    if (value is Map<String, dynamic>) return value;
    if (value is Map && value.keys.every((k) => k is String)) {
      return Map<String, dynamic>.from(value);
    }
    throw FormatException('Field "$key" must be an object: $value');
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final value = _readRequired(json, key);
    if (value is String) return value;
    throw FormatException('Field "$key" must be a string: $value');
  }

  static int _readInt(Map<String, dynamic> json, String key) =>
      _asInt(_readRequired(json, key), key);

  /// Accepts a finite number without a fractional part, so that `2` and
  /// `2.0` read identically on every platform. Both branches check
  /// finiteness because on the web platform `double.infinity is int` holds.
  static int _asInt(Object? value, String key) {
    if (value is int && value.isFinite) return value;
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }
    throw FormatException('Field "$key" must be an integer: $value');
  }

  static bool _readBool(Map<String, dynamic> json, String key) {
    final value = _readRequired(json, key);
    if (value is bool) return value;
    throw FormatException('Field "$key" must be a boolean: $value');
  }

  static List<int> _readIntList(Map<String, dynamic> json, String key) {
    final value = _readRequired(json, key);
    if (value is! List) {
      throw FormatException('Field "$key" must be a list of integers: $value');
    }
    return [for (final element in value) _asInt(element, key)];
  }

  static T _readEnum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    List<T> values,
  ) {
    final name = _readString(json, key);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Field "$key" has an unknown value: $name');
  }

  // ── Display ───────────────────────────────────────────────────────────

  /// An English summary such as "Every 2 weeks: Mon, Fri · for 10 times".
  String get displayText => [
    _patternText(pattern),
    _endText(end),
    if (includeStartDate) 'including start date',
  ].where((part) => part.isNotEmpty).join(' · ');

  static String _patternText(RecurrencePattern pattern) => switch (pattern) {
    Daily(:final interval) =>
      interval == 1 ? 'Every day' : 'Every $interval days',
    Weekly(:final interval, :final weekdays) => _weeklyText(interval, weekdays),
    MonthlyByDay(:final interval, :final day, :final missingDay) =>
      '${_every(interval, 'Monthly', 'months')} '
          '${_monthlyDayText(day, missingDay)}',
    MonthlyByWeekday(:final interval, :final position, :final weekday) =>
      '${_every(interval, 'Monthly', 'months')} on the '
          '${positionWord(position)} ${longDayName(weekday)}',
    Yearly(:final interval, :final month, :final day, :final missingDay) =>
      '${_every(interval, 'Yearly', 'years')} '
          '${_yearlyDayText(month, day, missingDay)}',
  };

  static String _weeklyText(int interval, List<int> weekdays) {
    final names = weekdays.map(shortDayName).join(', ');
    return interval == 1 ? names : 'Every $interval weeks: $names';
  }

  static String _every(int interval, String single, String pluralUnit) =>
      interval == 1 ? single : 'Every $interval $pluralUnit';

  static String _monthlyDayText(int day, MissingDay missingDay) {
    if (day < 29) return 'on the ${ordinal(day)}';
    return switch (missingDay) {
      MissingDay.useLastDay when day == 31 => 'on the last day',
      MissingDay.useLastDay =>
        'on the ${ordinal(day)}, using the last day in shorter months',
      MissingDay.skip =>
        'on the ${ordinal(day)}, skipping months without that day',
    };
  }

  static String _yearlyDayText(int month, int day, MissingDay missingDay) {
    if (month != DateTime.february || day != 29) {
      return 'on ${monthName(month)} $day';
    }
    return switch (missingDay) {
      MissingDay.useLastDay => 'on February 29, using Feb 28 in non-leap years',
      MissingDay.skip => 'on February 29, skipping non-leap years',
    };
  }

  static String _endText(RecurrenceEnd end) => switch (end) {
    NeverEnds() => '',
    EndsOnDate(:final date) => 'until ${date.month}/${date.day}/${date.year}',
    EndsAfterCount(:final count) =>
      count == 1 ? 'for 1 time' : 'for $count times',
  };
}
