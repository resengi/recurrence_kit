# Recurrence Kit

A standalone recurrence rule system for Flutter — sealed data models, a computation engine, and a configurable picker UI widget.

[![pub package](https://img.shields.io/pub/v/recurrence_kit.svg)](https://pub.dev/packages/recurrence_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Publisher](https://img.shields.io/pub/publisher/recurrence_kit.svg)](https://pub.dev/publishers/resengi.io)

## Examples

| Daily | Weekly | Monthly | Yearly |
|:---:|:---:|:---:|:---:|
| ![Daily](https://raw.githubusercontent.com/resengi/recurrence_kit/main/assets/example_daily.png) | ![Weekly](https://raw.githubusercontent.com/resengi/recurrence_kit/main/assets/example_weekly.png) | ![Monthly](https://raw.githubusercontent.com/resengi/recurrence_kit/main/assets/example_monthly.png) | ![Yearly](https://raw.githubusercontent.com/resengi/recurrence_kit/main/assets/example_yearly.png) |

## Features

- Immutable `RecurrenceRule` built from sealed pattern and end variants, so a rule cannot be in an invalid state
- Daily, weekly, monthly by day, monthly by weekday (`"2nd Tuesday"`, `"last Friday"`), and yearly patterns with intervals
- Explicit missing-day policy for days 29–31 and February 29: use the month's last day, or skip
- End conditions: never, on a date, after a count
- Optional inclusion of the start date as the first occurrence
- Pure, stateless engine computing single occurrences and the k-th occurrence by calendar arithmetic; enumeration is linear in the dates returned
- DST-safe date calculations
- Strict JSON serialization that round-trips every rule and ignores unknown keys
- Human-readable display text (`"Every 2 weeks: Mon, Fri · for 10 times"`)
- Fully themeable, controlled picker widget
- Single dependency beyond Flutter (`intl`)

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  recurrence_kit: ^0.2.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:recurrence_kit/recurrence_kit.dart';

// Create a rule:
final rule = RecurrenceRule(
  pattern: Weekly(weekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday]),
  end: EndsAfterCount(10),
);

// Check whether a date is an occurrence:
RecurrenceEngine.occursOnDate(rule, someDate, startDate);

// Upcoming occurrences:
RecurrenceEngine.nextOccurrences(rule, startDate, fromDate, count: 5);

// Boundary queries and windows:
RecurrenceEngine.nextOccurrenceOnOrAfter(rule, startDate, someDate);
RecurrenceEngine.previousOccurrenceOnOrBefore(rule, startDate, someDate);
RecurrenceEngine.occurrencesInRange(rule, startDate, windowStart, windowEnd);
RecurrenceEngine.lastOccurrence(rule, startDate);

// Picker widget:
RecurrencePicker(
  rule: rule,
  onChanged: (updated) => setState(() => _rule = updated),
  startDate: DateTime.now(),
)
```

## Usage Guide

### RecurrenceRule

A rule is one pattern, one end, and an `includeStartDate` flag:

```dart
RecurrenceRule(
  pattern: Daily(interval: 3),
  end: const NeverEnds(),
);

RecurrenceRule(
  pattern: MonthlyByDay(day: 31),           // last day of every month
  end: EndsOnDate(DateTime(2025, 12, 31)),
);

RecurrenceRule(
  pattern: MonthlyByWeekday(position: WeekPosition.second, weekday: DateTime.tuesday),
  end: EndsAfterCount(12),
);

RecurrenceRule(
  pattern: Yearly(month: 2, day: 29, missingDay: MissingDay.skip), // leap years only
  end: const NeverEnds(),
  includeStartDate: true,
);
```

Every constructor validates its arguments and throws `ArgumentError` for values outside the documented ranges; see [Semantics](#semantics) rule 2.

#### Missing days

`MonthlyByDay` with a day of 29–31 and `Yearly` on February 29 target a day that some months lack. `missingDay` decides what happens then:

```dart
MonthlyByDay(day: 31)                              // Feb 28 (or 29), Apr 30, ... : useLastDay
MonthlyByDay(day: 31, missingDay: MissingDay.skip) // only 31-day months
Yearly(month: 2, day: 29)                          // Feb 28 in non-leap years
Yearly(month: 2, day: 29, missingDay: MissingDay.skip) // leap years only
```

A `skip` rule can have no occurrences at all — every 12 months on the 30th from a February start, for instance. The engine determines this by arithmetic and every query returns null or empty.

#### Display text

```dart
rule.displayText; // "Every 2 weeks: Mon, Fri · for 10 times"
```

#### Serialization

```dart
final json = rule.toJson();            // Map<String, dynamic>
final restored = RecurrenceRule.fromJson(json);
```

The shape is documented in [Semantics](#semantics) rules 11–13. `fromJson` throws `FormatException` for anything it cannot read.

#### copyWith

```dart
final biweekly = rule.copyWith(pattern: (rule.pattern as Weekly).copyWith(interval: 2));
final unbounded = rule.copyWith(end: const NeverEnds());
```

Pattern variants have `copyWith` for their own fields; end variants are reconstructed.

### RecurrenceEngine

All engine methods are static and pure. A schedule is a rule paired with a start date. Inputs are reduced to calendar dates; results are local `DateTime(year, month, day)` values.

```dart
final start = DateTime(2025, 1, 6); // a Monday
final rule = RecurrenceRule(
  pattern: Weekly(weekdays: [DateTime.monday, DateTime.friday]),
  end: const NeverEnds(),
);

RecurrenceEngine.occursOnDate(rule, DateTime(2025, 1, 10), start);            // true
RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, DateTime(2025, 1, 8));   // 2025-01-10
RecurrenceEngine.previousOccurrenceOnOrBefore(rule, start, DateTime(2025, 1, 8)); // 2025-01-06
RecurrenceEngine.occurrencesInRange(rule, start, DateTime(2025, 1, 6), DateTime(2025, 1, 17));
// [2025-01-06, 2025-01-10, 2025-01-13, 2025-01-17]
RecurrenceEngine.nextOccurrences(rule, start, DateTime(2025, 1, 8), count: 3);
// [2025-01-10, 2025-01-13, 2025-01-17]
RecurrenceEngine.lastOccurrence(rule, start); // null: the sequence is unbounded
```

`lastOccurrence` is the final date of the resulting sequence, or null when that sequence is empty or unbounded:

```dart
final tenFridays = rule.copyWith(
  pattern: Weekly(weekdays: [DateTime.friday]),
  end: EndsAfterCount(10),
);
RecurrenceEngine.lastOccurrence(tenFridays, start); // 2025-03-14
```

### RecurrencePicker

The picker is a controlled widget. It renders the rule you pass and calls `onChanged` with a complete replacement rule for every edit; it keeps no recurrence state of its own, so what you store is what it shows.

```dart
class _EditorState extends State<Editor> {
  RecurrenceRule _rule = RecurrenceRule(pattern: Daily(), end: const NeverEnds());

  @override
  Widget build(BuildContext context) {
    return RecurrencePicker(
      rule: _rule,
      onChanged: (updated) => setState(() => _rule = updated),
      startDate: DateTime.now(),
    );
  }
}
```

Entering a mode seeds its values from `startDate` and the theme: Weekly starts on the start date's weekday, Monthly on its day of month, Yearly on its month and day, "After" with `theme.defaultEndAfterCount`, and "On date" with the schedule's first date. `includeStartDate` has no control in the picker; emitted rules preserve whatever value came in.

#### Theming

```dart
RecurrencePicker(
  rule: _rule,
  onChanged: _update,
  startDate: DateTime.now(),
  theme: const RecurrencePickerTheme(
    accentColor: Colors.indigo,
    fontSizeBody: 15,
    defaultEndAfterCount: 5,
  ),
)
```

#### Week start day

```dart
RecurrencePicker(
  // ...
  firstDayOfWeek: DateTime.monday, // display order of the weekday selector
)
```

#### End-date dialog horizon

```dart
RecurrencePickerTheme(datePickerLastDate: DateTime(2030, 12, 31))
```

The horizon bounds new selections in the "On date" dialog. It defaults to 100 years after the start date, may be set earlier or later, and must not precede the start date. A rule whose end date already lies beyond the horizon stays editable: the dialog extends to that date.

#### Custom date formatting

```dart
RecurrencePickerTheme(dateFormatter: (date) => DateFormat.yMd().format(date))
```

## Semantics

**Model**

1. A `RecurrenceRule` is one pattern, one end, and an `includeStartDate` flag (default `false`).
   Patterns: `Daily(interval)`, `Weekly(interval, weekdays)`, `MonthlyByDay(interval, day, missingDay)`, `MonthlyByWeekday(interval, position, weekday)`, `Yearly(interval, month, day, missingDay)`.
   Ends: `NeverEnds`, `EndsOnDate(date)`, `EndsAfterCount(count)`.
2. Constructors reject invalid values with `ArgumentError`: interval ≥ 1; weekdays non-empty, each 1–7, stored sorted, unique, unmodifiable; day 1–31; weekday 1–7; month 1–12; a yearly day must exist for its month in some Gregorian year (Feb 29 valid, Feb 30 and Apr 31 not); count ≥ 1. `position` is an enum: first, second, third, fourth, last. `missingDay` is an enum: `useLastDay` (default), `skip`.
3. Dates are calendar components. Construction keeps the supplied year, month, and day and discards time-of-day and the UTC flag without timezone conversion. Engine inputs and results use local `DateTime(year, month, day)` component construction; Dart's normal local-time normalization applies where that local wall time does not exist.
4. Equality is structural over every field. `RecurrenceRule.copyWith` replaces `pattern`, `end`, and/or `includeStartDate`; pattern variants have `copyWith` for their own fields; end variants are reconstructed. There are no clear flags. `missingDay` is authored state that persists through day edits, so two rules differing only in it are different rules even when their schedules coincide.

**Schedule**

5. A schedule is (rule, startDate). Interval alignment is anchored to startDate's day, Monday-based week, month, or year. The **base sequence** is: with `includeStartDate` false, the ascending calendar dates on or after startDate that match the pattern; with it true, startDate followed by the ascending dates after startDate that match the pattern.
6. `missingDay` governs an aligned month that lacks the target day (days 29–31 in shorter months; Feb 29 in non-leap years). `useLastDay` places the match on that month's last day, so monthly day 31 means "last day of the month" and yearly Feb 29 means "last day of February". `skip` produces no match in that month. It has no effect on days that always exist.
7. A base sequence is empty, exactly startDate (switch on, no later match), or unbounded. Whether a `skip` rule ever matches, and where, is determined by arithmetic on the calendar's fixed cycles (which months of the year the rule visits; for Feb 29, which years of the 400-year leap cycle it visits), never by searching. Examples of rules that never match: every 12 months on the 30th from a February start; Feb 29 every 100 years from a 2001 start.
8. The end condition transforms the base sequence: `NeverEnds` imposes no end; `EndsOnDate(d)` keeps the occurrences on or before d (a d before startDate therefore yields an empty schedule and is valid); `EndsAfterCount(N)` keeps at most the first N. `lastOccurrence` is the final date of the resulting sequence, or null when that sequence is empty or unbounded. Every query returns null or empty for occurrences that do not exist.
9. All queries are inclusive on-or-after / on-or-before. `nextOccurrences` takes a required count: 0 returns empty, negative throws `ArgumentError`.
10. The package defines no date ceiling of its own. A query is supported wherever the `DateTime` values required to evaluate it are representable by Dart. Calendar arithmetic near Dart's range limits may require an adjacent value outside that range, in which case `DateTime` throws `ArgumentError`. Enumeration does not advance beyond the final occurrence it returns. Single-occurrence queries (`occursOnDate`, next, previous, `lastOccurrence`) and the k-th occurrence are computed by arithmetic on codified calendar rules, with no scanning over days, months, or years and no dependence on calendar distance or on k. Enumeration queries (`occurrencesInRange`, `nextOccurrences`) are linear in the number of dates returned. No production code walks the calendar.

**Serialization**

11. Shape:

    | Key | Value |
    |---|---|
    | `pattern.kind` | `daily` · `weekly` · `monthlyByDay` · `monthlyByWeekday` · `yearly` |
    | `pattern.interval` | int (all kinds) |
    | `pattern.weekdays` | int list (weekly) |
    | `pattern.day` | int (monthlyByDay, yearly) |
    | `pattern.missingDay` | `useLastDay` · `skip` (monthlyByDay, yearly) |
    | `pattern.position` | `first` · `second` · `third` · `fourth` · `last` (monthlyByWeekday) |
    | `pattern.weekday` | int (monthlyByWeekday) |
    | `pattern.month` | int (yearly) |
    | `end.kind` | `never` · `onDate` · `afterCount` |
    | `end.date` | `{year, month, day}` ints (onDate) |
    | `end.count` | int (afterCount) |
    | `includeStartDate` | bool (top level) |

    `toJson` writes every key that belongs to the rule's kinds, weekdays sorted.
12. `fromJson` reads exactly the fields for the declared kind and ignores any other key at any level. It throws `FormatException` for an unknown kind, a missing field, a wrong type, an out-of-range value, or a date object that is not a real date. Integer fields accept any finite number without a fractional part; a fractional or non-finite number is a wrong type. Weekday order and duplicates are canonicalized on read. Every constructible rule round-trips; keys the package does not define are not preserved through the model. Because older readers ignore keys they do not know, a key added in a later version must be one that is correct to ignore; a change that alters behavior is introduced as a new `kind`.
13. There is no reader for the pre-0.2.0 flat shape. The format change is listed in the CHANGELOG as a breaking change.

**Picker**

14. `RecurrencePicker` is a controlled widget that owns no recurrence state. It renders `rule` by switching on the variant types; every accepted edit builds one complete replacement rule from the rule current at that moment and passes it to `onChanged`; interactions that make no edit (a cancelled dialog, a refused last-weekday removal, tapping the active chip) emit nothing. If the parent does not supply the new rule, nothing changes. `includeStartDate` is programmatic-only in the picker: it has no control, every emitted rule preserves the incoming value, and the picker doc says so.
15. Entering a mode seeds its variant from the current `startDate` and theme, carrying the current interval: weekly → start weekday; monthly → start day with `useLastDay`, or start position and weekday; yearly → start month and day with `useLastDay`; After → `theme.defaultEndAfterCount`; On date → the first date of the base sequence, or startDate when the base sequence is empty.
16. A missing-day toggle (use last day / skip) is shown for a monthly-by-day rule whose day is 29–31 and for a yearly rule on Feb 29, and nowhere else. Its labels, the monthly "Last day" segment label, and the helper text under the day stepper reflect the current `missingDay`. Yearly has no other controls.
17. The date dialog's selectable range runs from startDate to the later of the horizon (`theme.datePickerLastDate`, which may be earlier or later than the default 100 years after startDate, but not earlier than startDate) and the rule's existing end date; its cursor is the existing end date clamped into that range (so a valid end before startDate opens on startDate). Opening or cancelling the dialog never changes the rule. A picked date is applied to the then-current `widget.rule` after a `mounted` check. The horizon restricts selection only.
18. At build, the picker rejects with `ArgumentError`: `defaultEndAfterCount` < 1, a horizon before startDate, `firstDayOfWeek` outside 1–7. `firstDayOfWeek` is display order only; default Sunday. The theme is a passive `const` value.

## API Reference

### RecurrenceRule

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `pattern` | `RecurrencePattern` | required | `Daily`, `Weekly`, `MonthlyByDay`, `MonthlyByWeekday`, or `Yearly` |
| `end` | `RecurrenceEnd` | required | `NeverEnds`, `EndsOnDate`, or `EndsAfterCount` |
| `includeStartDate` | `bool` | `false` | Whether the start date is occurrence #1 even when it does not match the pattern |

### Patterns

| Variant | Fields |
|---------|--------|
| `Daily` | `interval` |
| `Weekly` | `interval`, `weekdays` (sorted ISO weekdays, 1 = Mon … 7 = Sun) |
| `MonthlyByDay` | `interval`, `day` (1–31), `missingDay` |
| `MonthlyByWeekday` | `interval`, `position` (`WeekPosition`), `weekday` (1–7) |
| `Yearly` | `interval`, `month` (1–12), `day`, `missingDay` |

### RecurrencePicker

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `rule` | `RecurrenceRule` | required | The rule to render |
| `onChanged` | `ValueChanged<RecurrenceRule>` | required | Receives the replacement rule for every accepted edit |
| `startDate` | `DateTime` | required | Seeds mode defaults and bounds the end-date dialog |
| `firstDayOfWeek` | `int` | `DateTime.sunday` | Display order of the weekday selector |
| `theme` | `RecurrencePickerTheme` | `const RecurrencePickerTheme()` | Visual and functional configuration |

### RecurrencePickerTheme

#### Colors

| Property | Default | Used for |
|----------|---------|----------|
| `textColor` | `#1A1A1A` | Labels and values |
| `secondaryTextColor` | `#6B6B6B` | Hints and helper text |
| `accentColor` | `#5B6ABF` | Selected chips, radio indicators, stepper buttons, date icon |
| `borderColor` | `#D0D0D0` | Unselected chips and day-of-week circles |

#### Font sizes

| Property | Default | Used for |
|----------|---------|----------|
| `fontSizeBody` | `14.0` | Labels and dropdown items |
| `fontSizeMedium` | `16.0` | Stepper values |
| `fontSizeCompact` | `13.0` | Chip labels and day-of-week letters |
| `fontSizeSmall` | `12.0` | Helper text and segmented button labels |

#### Spacing

| Property | Default | Used for |
|----------|---------|----------|
| `spacingXS` | `4.0` | Stepper row to helper note |
| `spacingS` | `8.0` | Label to control |
| `spacingM` | `12.0` | Between sections |
| `spacingL` | `16.0` | Before the end-condition section |

#### Functional

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `datePickerLastDate` | `DateTime?` | `null` | Horizon of the "On date" dialog; null = 100 years after `startDate`. Must not precede `startDate`. |
| `defaultEndAfterCount` | `int` | `10` | Count seeded when "After" is selected; must be ≥ 1 |
| `dateFormatter` | `String Function(DateTime)?` | `null` | End-date display format (null = `DateFormat.yMMMd()`) |

## Best Practices

**Store the rule and the start date together.** A rule alone is not a schedule; every engine query takes both.

**Keep engine calls out of `build`.** Cache results in state and recompute when the rule or start date changes.

**Use `occurrencesInRange` for calendar views.** Ask for the visible window directly; cost scales with the number of dates returned, not with the window length. Use `nextOccurrences` for the next N dates without a bounded range.

**Use `lastOccurrence` to display when a schedule ends.** It is the authoritative final date of the resulting sequence and null when that sequence is empty or unbounded.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.