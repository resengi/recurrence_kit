import 'format_helpers.dart' as helpers;
import 'recurrence_end_type.dart';
import 'recurrence_type.dart';

/// An immutable description of a repeating schedule.
///
/// Encodes the frequency, interval, day/week/month constraints, and end
/// condition for a recurrence pattern. Pairs with [RecurrenceEngine] for
/// occurrence computation and [RecurrencePicker] for interactive editing.
///
/// ```dart
/// // Every 2 weeks on Monday and Friday, ending after 10 occurrences
/// final rule = RecurrenceRule(
///   type: RecurrenceType.weekly,
///   interval: 2,
///   daysOfWeek: [1, 5],
///   endType: RecurrenceEndType.afterCount,
///   endAfterCount: 10,
/// );
///
/// print(rule.displayText); // "Every 2 weeks: Mon, Fri · for 10 times"
/// ```
///
/// ## Serialization
///
/// [toJson] and [fromJson] produce and consume a plain `Map<String, dynamic>`
/// suitable for JSON storage or Drift `TypeConverter` integration.
class RecurrenceRule {
  /// Creates a recurrence rule.
  ///
  /// Only [type] is required. All other fields default to the simplest
  /// configuration for that frequency (interval 1, no end condition).
  RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.daysOfWeek,
    this.monthDay,
    this.weekOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    this.endType = RecurrenceEndType.never,
    this.endDate,
    this.endAfterCount,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      type: RecurrenceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RecurrenceType.daily,
      ),
      interval: json['interval'] as int? ?? 1,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.cast<int>(),
      monthDay: json['monthDay'] as int?,
      weekOfMonth: json['weekOfMonth'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
      monthOfYear: json['monthOfYear'] as int?,
      endType: json['endType'] != null
          ? RecurrenceEndType.values.firstWhere(
              (e) => e.name == json['endType'],
              orElse: () => RecurrenceEndType.never,
            )
          : RecurrenceEndType.never,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      endAfterCount: json['endAfterCount'] as int?,
    );
  }

  final RecurrenceType type;

  /// Every N days/weeks/months/years.
  final int interval;

  /// For [RecurrenceType.weekly]: which days (1=Mon … 7=Sun, ISO weekday).
  final List<int>? daysOfWeek;

  /// For [RecurrenceType.monthly] (fixed date mode) and [RecurrenceType.yearly]:
  /// day of month (1–31).
  final int? monthDay;

  /// For [RecurrenceType.monthly] (relative weekday mode): which week (1–4
  /// literal, 5 = last occurrence of the weekday in that month).
  final int? weekOfMonth;

  /// For [RecurrenceType.monthly] (relative weekday mode): ISO weekday
  /// (1=Mon … 7=Sun).
  final int? dayOfWeek;

  /// For [RecurrenceType.yearly]: month (1–12).
  final int? monthOfYear;

  /// How this recurrence ends.
  final RecurrenceEndType endType;

  /// The date after which no more occurrences are generated.
  ///
  /// For [RecurrenceEndType.onDate], this is user-selected.
  /// For [RecurrenceEndType.afterCount], this is pre-computed at save time.
  /// This is the sole recurrence boundary — model-level endDate fields are
  /// no longer used for recurrence.
  final DateTime? endDate;

  /// Display-only: the original occurrence count when [endType] is
  /// [RecurrenceEndType.afterCount]. Stored so the UI can show "ends after
  /// 10 times" and recompute [endDate] if start date or interval changes.
  final int? endAfterCount;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Whether the monthly rule is in relative weekday mode
  /// (e.g. "2nd Tuesday") vs. fixed date mode (e.g. "on the 15th").
  bool get isRelativeMonthly =>
      type == RecurrenceType.monthly &&
      weekOfMonth != null &&
      dayOfWeek != null;

  RecurrenceRule copyWith({
    RecurrenceType? type,
    int? interval,
    List<int>? daysOfWeek,
    int? monthDay,
    int? weekOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
    RecurrenceEndType? endType,
    DateTime? endDate,
    int? endAfterCount,
    bool clearDaysOfWeek = false,
    bool clearMonthDay = false,
    bool clearWeekOfMonth = false,
    bool clearDayOfWeek = false,
    bool clearMonthOfYear = false,
    bool clearEndType = false,
    bool clearEndDate = false,
    bool clearEndAfterCount = false,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      daysOfWeek: clearDaysOfWeek ? null : (daysOfWeek ?? this.daysOfWeek),
      monthDay: clearMonthDay ? null : (monthDay ?? this.monthDay),
      weekOfMonth: clearWeekOfMonth ? null : (weekOfMonth ?? this.weekOfMonth),
      dayOfWeek: clearDayOfWeek ? null : (dayOfWeek ?? this.dayOfWeek),
      monthOfYear: clearMonthOfYear ? null : (monthOfYear ?? this.monthOfYear),
      endType: clearEndType
          ? RecurrenceEndType.never
          : (endType ?? this.endType),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      endAfterCount: clearEndAfterCount
          ? null
          : (endAfterCount ?? this.endAfterCount),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'interval': interval,
    'daysOfWeek': daysOfWeek,
    'monthDay': monthDay,
    'weekOfMonth': weekOfMonth,
    'dayOfWeek': dayOfWeek,
    'monthOfYear': monthOfYear,
    'endType': endType.name,
    'endDate': endDate?.toIso8601String(),
    'endAfterCount': endAfterCount,
  };

  String get displayText {
    final base = _baseDisplayText;
    final endSuffix = _endDisplaySuffix;
    if (endSuffix.isEmpty) return base;
    return '$base · $endSuffix';
  }

  String get _baseDisplayText {
    switch (type) {
      case RecurrenceType.daily:
        if (interval == 1) return 'Every day';
        return 'Every $interval days';
      case RecurrenceType.weekly:
        final days = daysOfWeek ?? [];
        if (days.isEmpty) return 'Weekly';
        const dayAbbreviations = [
          '',
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun',
        ];
        final sorted = List<int>.from(days)..sort();
        final dayNames = sorted.map((d) => dayAbbreviations[d]).join(', ');
        if (interval == 1) return dayNames;
        return 'Every $interval weeks: $dayNames';
      case RecurrenceType.monthly:
        final prefix = interval == 1 ? 'Monthly' : 'Every $interval months';
        if (isRelativeMonthly) {
          final ordinal = helpers.ordinalWord(weekOfMonth!);
          const dayNames = [
            '',
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
          return '$prefix on the $ordinal ${dayNames[dayOfWeek!]}';
        }
        if (monthDay != null) {
          if (monthDay == 31) {
            return '$prefix on the last day';
          }
          if (monthDay! >= 29) {
            return '$prefix on the ${_daySuffix(monthDay!)}'
                ' (last day in shorter months)';
          }
          return '$prefix on the ${_daySuffix(monthDay!)}';
        }
        return prefix;
      case RecurrenceType.yearly:
        const monthNames = [
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
        final prefix = interval == 1 ? 'Yearly' : 'Every $interval years';
        if (monthOfYear != null && monthDay != null) {
          final monthName = monthNames[monthOfYear!];
          final daysInMonth = DateTime(
            2024,
            monthOfYear! + 1,
            0,
          ).day; // 2024 is leap year for max
          if (monthDay! > daysInMonth || (monthOfYear == 2 && monthDay == 29)) {
            return '$prefix on $monthName $monthDay'
                ' (last day in shorter years)';
          }
          return '$prefix on $monthName $monthDay';
        }
        return prefix;
    }
  }

  String get _endDisplaySuffix {
    final effectiveEndType = endType;
    switch (effectiveEndType) {
      case RecurrenceEndType.never:
        return '';
      case RecurrenceEndType.onDate:
        if (endDate == null) return '';
        final d = endDate!;
        return 'until ${d.month}/${d.day}/${d.year}';
      case RecurrenceEndType.afterCount:
        if (endAfterCount == null) return '';
        return 'for $endAfterCount times';
    }
  }

  static String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceRule &&
          type == other.type &&
          interval == other.interval &&
          _listEquals(daysOfWeek, other.daysOfWeek) &&
          monthDay == other.monthDay &&
          weekOfMonth == other.weekOfMonth &&
          dayOfWeek == other.dayOfWeek &&
          monthOfYear == other.monthOfYear &&
          endType == other.endType &&
          endDate == other.endDate &&
          endAfterCount == other.endAfterCount;

  @override
  int get hashCode => Object.hash(
    type,
    interval,
    Object.hashAll(daysOfWeek ?? []),
    monthDay,
    weekOfMonth,
    dayOfWeek,
    monthOfYear,
    endType,
    endDate,
    endAfterCount,
  );

  static bool _listEquals(List<int>? a, List<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
