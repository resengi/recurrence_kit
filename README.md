# Recurrence Kit

A standalone recurrence rule system for Flutter — data models, a computation engine, and a configurable picker UI widget.

[![pub package](https://img.shields.io/pub/v/recurrence_kit.svg)](https://pub.dev/packages/recurrence_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Publisher](https://img.shields.io/pub/publisher/recurrence_kit.svg)](https://pub.dev/publishers/resengi.io)

## Examples

| Daily | Weekly | Monthly | Yearly |
|:---:|:---:|:---:|:---:|
| ![Daily](https://raw.githubusercontent.com/resengi/recurrence_kit/main/assets/example_daily.png) | ![Weekly](https://raw.githubusercontent.com/resengi/recurrence_kit/main/assets/example_weekly.png) | ![Monthly](https://raw.githubusercontent.com/resengi/recurrence_kit/main/assets/example_monthly.png) | ![Yearly](https://raw.githubusercontent.com/resengi/recurrence_kit/main/assets/example_yearly.png) |

## Features

- Immutable `RecurrenceRule` model with full JSON serialization (`toJson` / `fromJson`)
- Human-readable display text (`"Every 2 weeks: Mon, Fri · for 10 times"`)
- Support for daily, weekly, monthly (fixed date and relative weekday), and yearly patterns
- Configurable intervals, day-of-week selection, and end conditions (never, on date, after count)
- Monthly relative weekday mode (`"2nd Tuesday"`, `"last Friday"`)
- Short-month and leap-day fallback handling
- Pure, stateless computation engine with direct-jump arithmetic (no day-by-day iteration)
- DST-safe date calculations
- Fully themeable picker widget via a single `RecurrencePickerTheme` config class
- Optional `maxCount` safety cap for user-controlled occurrence counts
- Single dependency beyond Flutter (`intl`)

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  recurrence_kit: ^0.1.0
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
  type: RecurrenceType.weekly,
  daysOfWeek: [1, 3, 5],
);

// Check if a date matches:
RecurrenceEngine.occursOnDate(rule, someDate, startDate);

// Get upcoming occurrences:
RecurrenceEngine.nextOccurrences(rule, startDate, afterDate, count: 5);

// Full picker widget:
RecurrencePicker(
  rule: rule,
  onChanged: (updated) => setState(() => _rule = updated),
  startDate: DateTime.now(),
)
```

## Usage Guide

### RecurrenceRule

An immutable description of a repeating schedule. Supports daily, weekly, monthly (fixed date or relative weekday), and yearly patterns with configurable intervals and end conditions.

```dart
// Every 2 weeks on Monday and Friday, ending after 10 occurrences
final rule = RecurrenceRule(
  type: RecurrenceType.weekly,
  interval: 2,
  daysOfWeek: [1, 5],
  endType: RecurrenceEndType.afterCount,
  endAfterCount: 10,
);

print(rule.displayText); // "Every 2 weeks: Mon, Fri · for 10 times"
```

#### Monthly Rules

Monthly supports two modes. Fixed date mode repeats on a specific day of the month, with automatic fallback for shorter months:

```dart
// Every month on the 31st (falls back to last day in shorter months)
RecurrenceRule(
  type: RecurrenceType.monthly,
  monthDay: 31,
)
```

Relative weekday mode repeats on the Nth occurrence of a weekday:

```dart
// Every month on the 2nd Tuesday
RecurrenceRule(
  type: RecurrenceType.monthly,
  weekOfMonth: 2,
  dayOfWeek: 2,
)

// Every month on the last Friday
RecurrenceRule(
  type: RecurrenceType.monthly,
  weekOfMonth: 5, // 5 = last
  dayOfWeek: 5,
)
```

#### Serialization

`toJson` and `fromJson` produce and consume a plain `Map<String, dynamic>`, suitable for JSON storage or Drift `TypeConverter` integration:

```dart
final json = rule.toJson();
final restored = RecurrenceRule.fromJson(json);
assert(rule == restored);
```

A Drift `TypeConverter` is just a few lines in your app code:

```dart
class RecurrenceRuleConverter extends TypeConverter<RecurrenceRule, String> {
  const RecurrenceRuleConverter();

  @override
  RecurrenceRule fromSql(String fromDb) =>
      RecurrenceRule.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(RecurrenceRule value) => jsonEncode(value.toJson());
}
```

#### copyWith

All fields support override via `copyWith`. Boolean `clear*` flags reset individual fields to null:

```dart
final updated = rule.copyWith(interval: 3);
final cleared = rule.copyWith(clearDaysOfWeek: true);
```

### RecurrenceEngine

Pure, stateless computation — all methods are static with no Flutter dependencies.

#### Checking a Date

```dart
final matches = RecurrenceEngine.occursOnDate(rule, date, startDate);
```

All dates are normalized to midnight internally. The recurrence boundary is read from `rule.endDate`.

#### Getting Upcoming Occurrences

```dart
final upcoming = RecurrenceEngine.nextOccurrences(
  rule,
  startDate,
  afterDate, // exclusive — occurrences start from afterDate + 1
  count: 5,
);
```

Uses direct-jump arithmetic to compute each occurrence in O(1) — no day-by-day iteration regardless of interval size. A yearly rule with `interval: 10` requesting 5 occurrences takes exactly 5 computations, not 18,250.

#### Computing End Dates for "After N" Rules

When `endType == RecurrenceEndType.afterCount`, the picker stores the count but not the concrete end date. Resolve it at save time:

```dart
final endDate = RecurrenceEngine.computeEndDateFromCount(
  rule,
  startDate,
  rule.endAfterCount!,
);
final resolved = rule.copyWith(endDate: endDate);
```

Use `maxCount` to guard against unreasonably large user input:

```dart
final endDate = RecurrenceEngine.computeEndDateFromCount(
  rule, startDate, userCount,
  maxCount: 1000, // returns null if userCount > 1000
);
```

### RecurrencePicker

An inline editor widget that builds a `RecurrenceRule` interactively. Provides controls for frequency, interval, day/week/month selection, and end conditions.

```dart
RecurrencePicker(
  rule: _rule,
  onChanged: (updated) => setState(() => _rule = updated),
  startDate: DateTime(2025, 1, 15),
)
```

#### Theming

Pass a `RecurrencePickerTheme` to customize colors, font sizes, spacing, and functional options:

```dart
RecurrencePicker(
  rule: _rule,
  onChanged: (updated) => setState(() => _rule = updated),
  startDate: DateTime.now(),
  theme: RecurrencePickerTheme(
    accentColor: Colors.indigo,
    textColor: Colors.white,
    fontSizeBody: 15.0,
    spacingM: 16.0,
  ),
)
```

Use `copyWith` to derive a modified theme from an existing one:

```dart
final darkTheme = lightTheme.copyWith(
  textColor: Color(0xFFE0E0E0),
  accentColor: Color(0xFF81C784),
);
```

#### Week Start Day

The day-of-week selector defaults to Sunday-first. Pass `firstDayOfWeek` to change it:

```dart
RecurrencePicker(
  rule: _rule,
  onChanged: (updated) => setState(() => _rule = updated),
  startDate: DateTime.now(),
  firstDayOfWeek: DateTime.monday,
)
```

#### Custom Date Formatting

The end-date display uses `intl`'s `DateFormat.yMMMd()` by default. Override it via the theme:

```dart
RecurrencePickerTheme(
  dateFormatter: (date) => '${date.day}/${date.month}/${date.year}',
)
```

## Customization

### RecurrenceRule Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `type` | `RecurrenceType` | required | Frequency: `daily`, `weekly`, `monthly`, `yearly` |
| `interval` | `int` | `1` | Every N days/weeks/months/years |
| `daysOfWeek` | `List<int>?` | `null` | Weekly: selected ISO weekdays (1=Mon … 7=Sun) |
| `monthDay` | `int?` | `null` | Monthly (fixed) / yearly: day of month (1–31) |
| `weekOfMonth` | `int?` | `null` | Monthly (relative): which week (1–4, or 5=last) |
| `dayOfWeek` | `int?` | `null` | Monthly (relative): ISO weekday (1=Mon … 7=Sun) |
| `monthOfYear` | `int?` | `null` | Yearly: month (1–12) |
| `endType` | `RecurrenceEndType` | `.never` | How the recurrence ends: `never`, `onDate`, `afterCount` |
| `endDate` | `DateTime?` | `null` | The date after which no more occurrences are generated |
| `endAfterCount` | `int?` | `null` | Display-only: original count for "after N" rules |

### RecurrencePicker Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `rule` | `RecurrenceRule` | required | Current recurrence rule |
| `onChanged` | `ValueChanged<RecurrenceRule>` | required | Fires on every user edit |
| `startDate` | `DateTime` | required | Start date — used to derive monthly/yearly defaults |
| `firstDayOfWeek` | `int` | `DateTime.sunday` | Week start for the day-of-week selector |
| `theme` | `RecurrencePickerTheme` | `const RecurrencePickerTheme()` | Visual and functional configuration |

### RecurrencePickerTheme Properties

#### Colors

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `textColor` | `Color` | `Color(0xFF1A1A1A)` | Primary text for labels and values |
| `secondaryTextColor` | `Color` | `Color(0xFF6B6B6B)` | Hints, helper text, de-emphasized content |
| `accentColor` | `Color` | `Color(0xFF5B6ABF)` | Selected chips, stepper buttons, date icon |
| `borderColor` | `Color` | `Color(0xFFD0D0D0)` | Unselected chips and day-of-week circles |

#### Font Sizes

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fontSizeBody` | `double` | `14.0` | Labels: "Every", "On days", "Ends", dropdowns |
| `fontSizeMedium` | `double` | `16.0` | Stepper counter values |
| `fontSizeCompact` | `double` | `13.0` | Chip labels and day-of-week letters |
| `fontSizeSmall` | `double` | `12.0` | Helper notes and segmented button labels |

#### Spacing

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `spacingXS` | `double` | `4.0` | Between stepper and helper note |
| `spacingS` | `double` | `8.0` | Between label and control |
| `spacingM` | `double` | `12.0` | Between major sections |
| `spacingL` | `double` | `16.0` | Before end-condition section |

#### Functional

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `datePickerEndYear` | `int` | `2040` | Last year in the end-date picker |
| `dateFormatter` | `String Function(DateTime)?` | `null` | Custom end-date display (null = `DateFormat.yMMMd()`) |

## How It Works

1. **Immutable model** — `RecurrenceRule` encodes the full recurrence pattern as value types with `==`, `hashCode`, and `copyWith`. Serialization round-trips cleanly via `toJson` / `fromJson`.

2. **Direct-jump engine** — `nextOccurrences` and `computeEndDateFromCount` compute each occurrence in O(1) by jumping directly to the next matching date using modular arithmetic (daily), week-aligned scanning (weekly), month-offset arithmetic (monthly), or year-offset arithmetic (yearly). No day-by-day iteration.

3. **DST safety** — All day-count and week-count calculations use a UTC conversion helper to avoid `DateTime.difference().inDays` truncation errors caused by daylight saving transitions. Monday-of-week computations use component math rather than `Duration` subtraction.

4. **Predicate for external use** — `occursOnDate` is a standalone check for "does date X match rule Y?" — useful when iterating a visible date range (calendars, planners) rather than computing N upcoming dates.

5. **Decoupled theme** — `RecurrencePickerTheme` maps 1:1 to visual elements with no inherited theme lookups. Every field has a sensible default, so consumers can override selectively or pass `const RecurrencePickerTheme()` for zero-config.

## Best Practices

**Resolve "after N" end dates at save time**, not in `build`. The picker outputs `endAfterCount` but the engine uses `endDate` as the boundary. Call `computeEndDateFromCount` once when saving, not on every frame:

```dart
void _save() {
  var rule = _rule;
  if (rule.endType == RecurrenceEndType.afterCount && rule.endAfterCount != null) {
    rule = rule.copyWith(
      endDate: RecurrenceEngine.computeEndDateFromCount(
        rule, _startDate, rule.endAfterCount!,
      ),
    );
  }
  database.saveRule(rule);
}
```

**Use `maxCount` for user-facing input** to guard against unreasonably large occurrence counts:

```dart
RecurrenceEngine.computeEndDateFromCount(rule, start, userCount, maxCount: 1000);
```

**Pass `afterDate` one day before start** when you want the first occurrence (possibly today) included:

```dart
final upcoming = RecurrenceEngine.nextOccurrences(
  rule, startDate,
  startDate.subtract(const Duration(days: 1)),
  count: 5,
);
```

**Keep engine calls out of `build`** — cache results in state and recompute only when the rule changes. This avoids unnecessary computation on every frame rebuild.

**Use `occursOnDate` for calendar ranges** — when materializing a planner or calendar view, iterate your visible date range and check each day with `occursOnDate`. This is efficient for bounded ranges (7–31 days). Use `nextOccurrences` when you need the next N dates without a bounded range.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.