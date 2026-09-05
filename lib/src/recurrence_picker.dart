import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'calendar.dart';
import 'format_helpers.dart';
import 'recurrence_engine.dart';
import 'recurrence_model.dart';
import 'recurrence_picker_theme.dart';
import 'recurrence_rule.dart';

/// An inline recurrence rule editor.
///
/// A controlled widget: it renders [rule] and owns no recurrence state of
/// its own. Every accepted edit builds one complete replacement rule from
/// the rule current at that moment and passes it to [onChanged];
/// interactions that make no edit (a cancelled date dialog, removing the
/// only selected weekday, tapping the active frequency chip) emit
/// nothing. If the parent does not supply the new rule, nothing changes.
///
/// Entering a mode seeds its values from the current [startDate] and
/// [theme], carrying the current interval: Weekly starts on the start
/// date's weekday, Monthly on its day of month (or its week position and
/// weekday), Yearly on its month and day, "After" with
/// [RecurrencePickerTheme.defaultEndAfterCount], and "On date" with the
/// schedule's first date (the start date when the schedule has none).
///
/// [RecurrenceRule.includeStartDate] has no control here; every emitted
/// rule preserves the incoming value.
///
/// ```dart
/// RecurrencePicker(
///   rule: _rule,
///   onChanged: (updated) => setState(() => _rule = updated),
///   startDate: DateTime(2025, 1, 15),
/// )
/// ```
class RecurrencePicker extends StatefulWidget {
  const RecurrencePicker({
    required this.rule,
    required this.onChanged,
    required this.startDate,
    this.firstDayOfWeek = DateTime.sunday,
    this.theme = const RecurrencePickerTheme(),
    super.key,
  });

  /// The rule being edited.
  final RecurrenceRule rule;

  /// Receives the replacement rule for every accepted edit.
  final ValueChanged<RecurrenceRule> onChanged;

  /// The schedule's start date; seeds mode defaults and bounds the
  /// end-date dialog.
  final DateTime startDate;

  /// The ISO weekday (1 = Monday … 7 = Sunday) shown first in the
  /// weekday selector. Display order only.
  final int firstDayOfWeek;

  /// Visual and functional configuration.
  final RecurrencePickerTheme theme;

  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  RecurrenceRule get _rule => widget.rule;

  DateTime get _start => calendarDate(widget.startDate);

  /// Throws an [ArgumentError] for a configuration the picker cannot
  /// honor: a count seed below 1, a horizon before the start date, or a
  /// first weekday outside 1–7.
  void _validateConfiguration() {
    final count = widget.theme.defaultEndAfterCount;
    if (count < 1) {
      throw ArgumentError.value(
        count,
        'theme.defaultEndAfterCount',
        'must be >= 1',
      );
    }
    final horizon = widget.theme.datePickerLastDate;
    if (horizon != null && calendarDate(horizon).isBefore(_start)) {
      throw ArgumentError(
        'theme.datePickerLastDate (${calendarDate(horizon)}) must not '
        'precede the picker startDate ($_start)',
      );
    }
    final firstDay = widget.firstDayOfWeek;
    if (firstDay < DateTime.monday || firstDay > DateTime.sunday) {
      throw ArgumentError.value(
        firstDay,
        'firstDayOfWeek',
        'must be an ISO weekday 1-7',
      );
    }
  }

  void _emitPattern(RecurrencePattern pattern) =>
      widget.onChanged(_rule.copyWith(pattern: pattern));

  void _emitEnd(RecurrenceEnd end) =>
      widget.onChanged(_rule.copyWith(end: end));

  void _selectFrequency(_Frequency frequency) {
    final pattern = _rule.pattern;
    if (frequency.isActive(pattern)) return;
    _emitPattern(frequency.seed(pattern.interval, _start));
  }

  void _selectOnDate() {
    final unbounded = _rule.copyWith(end: const NeverEnds());
    final first = RecurrenceEngine.nextOccurrenceOnOrAfter(
      unbounded,
      _start,
      _start,
    );
    _emitEnd(EndsOnDate(first ?? _start));
  }

  /// The default horizon: 100 years after the start date, on the same
  /// month and day, or the month's last day when it is shorter.
  DateTime get _defaultHorizon {
    final year = _start.year + 100;
    final day = math.min(_start.day, daysInMonth(year, _start.month));
    return DateTime(year, _start.month, day);
  }

  /// Opens the end-date dialog. Its range runs from the start date to the
  /// later of the horizon and the rule's existing end date; the picked
  /// date is applied to the rule current when the dialog closes.
  Future<void> _pickEndDate(EndsOnDate current) async {
    final first = _start;
    final configured = widget.theme.datePickerLastDate;
    final horizon = configured == null
        ? _defaultHorizon
        : calendarDate(configured);
    final last = current.date.isAfter(horizon) ? current.date : horizon;
    final cursor = current.date.isBefore(first) ? first : current.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: cursor,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    widget.onChanged(widget.rule.copyWith(end: EndsOnDate(picked)));
  }

  @override
  Widget build(BuildContext context) {
    _validateConfiguration();
    final theme = widget.theme;
    final pattern = _rule.pattern;
    final frequency = _frequencies.firstWhere((f) => f.isActive(pattern));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repeat',
          style: TextStyle(
            fontSize: theme.fontSizeBody,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        SizedBox(height: theme.spacingS),
        _FrequencyChips(
          pattern: pattern,
          onSelected: _selectFrequency,
          theme: theme,
        ),
        SizedBox(height: theme.spacingM),
        _IntervalRow(
          interval: pattern.interval,
          unitLabel: pattern.interval == 1
              ? frequency.unit
              : '${frequency.unit}s',
          onDecrement: pattern.interval > 1
              ? () => _emitPattern(
                  pattern.copyWith(interval: pattern.interval - 1),
                )
              : null,
          onIncrement: () =>
              _emitPattern(pattern.copyWith(interval: pattern.interval + 1)),
          theme: theme,
        ),
        switch (pattern) {
          Daily() => const SizedBox.shrink(),
          Weekly weekly => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: theme.spacingM),
              Text('On days', style: _bodyStyle(theme)),
              SizedBox(height: theme.spacingS),
              _DayOfWeekSelector(
                selectedDays: weekly.weekdays.toSet(),
                onChanged: (days) {
                  if (days.isEmpty) return;
                  _emitPattern(weekly.copyWith(weekdays: days));
                },
                firstDayOfWeek: widget.firstDayOfWeek,
                theme: theme,
              ),
            ],
          ),
          MonthlyByDay() || MonthlyByWeekday() => Padding(
            padding: EdgeInsets.only(top: theme.spacingM),
            child: _MonthlyOptions(
              pattern: pattern,
              startDate: _start,
              onChanged: _emitPattern,
              theme: theme,
            ),
          ),
          Yearly yearly => Padding(
            padding: EdgeInsets.only(top: theme.spacingM),
            child: _YearlyOptions(
              pattern: yearly,
              onChanged: _emitPattern,
              theme: theme,
            ),
          ),
        },
        SizedBox(height: theme.spacingL),
        _EndConditionControls(
          end: _rule.end,
          onNever: () => _emitEnd(const NeverEnds()),
          onOnDate: _selectOnDate,
          onAfter: () => _emitEnd(EndsAfterCount(theme.defaultEndAfterCount)),
          onCountChanged: (count) => _emitEnd(EndsAfterCount(count)),
          onPickDate: _pickEndDate,
          theme: theme,
        ),
      ],
    );
  }
}

// ── Shared styles ────────────────────────────────────────────────────────────

TextStyle _bodyStyle(RecurrencePickerTheme theme) =>
    TextStyle(fontSize: theme.fontSizeBody, color: theme.textColor);

ButtonStyle _segmentedStyle(RecurrencePickerTheme theme) => ButtonStyle(
  visualDensity: VisualDensity.compact,
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: theme.fontSizeSmall)),
);

// ── Frequencies ──────────────────────────────────────────────────────────────

/// One entry of the frequency chip row: which patterns it represents and
/// the pattern it seeds when entered.
class _Frequency {
  const _Frequency({
    required this.label,
    required this.unit,
    required this.isActive,
    required this.seed,
  });

  final String label;

  /// Singular interval unit; pluralized by appending "s".
  final String unit;
  final bool Function(RecurrencePattern pattern) isActive;
  final RecurrencePattern Function(int interval, DateTime startDate) seed;
}

final List<_Frequency> _frequencies = [
  _Frequency(
    label: 'Daily',
    unit: 'day',
    isActive: (pattern) => pattern is Daily,
    seed: (interval, _) => Daily(interval: interval),
  ),
  _Frequency(
    label: 'Weekly',
    unit: 'week',
    isActive: (pattern) => pattern is Weekly,
    seed: (interval, start) =>
        Weekly(interval: interval, weekdays: [start.weekday]),
  ),
  _Frequency(
    label: 'Monthly',
    unit: 'month',
    isActive: (pattern) =>
        pattern is MonthlyByDay || pattern is MonthlyByWeekday,
    seed: (interval, start) => MonthlyByDay(interval: interval, day: start.day),
  ),
  _Frequency(
    label: 'Yearly',
    unit: 'year',
    isActive: (pattern) => pattern is Yearly,
    seed: (interval, start) =>
        Yearly(interval: interval, month: start.month, day: start.day),
  ),
];

class _FrequencyChips extends StatelessWidget {
  const _FrequencyChips({
    required this.pattern,
    required this.onSelected,
    required this.theme,
  });

  final RecurrencePattern pattern;
  final ValueChanged<_Frequency> onSelected;
  final RecurrencePickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final frequency in _frequencies)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(frequency, frequency.isActive(pattern)),
            ),
        ],
      ),
    );
  }

  Widget _chip(_Frequency frequency, bool isSelected) => ChoiceChip(
    label: Text(frequency.label),
    selected: isSelected,
    onSelected: (_) => onSelected(frequency),
    selectedColor: theme.accentColor.withValues(alpha: 0.2),
    labelStyle: TextStyle(
      fontSize: theme.fontSizeCompact,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      color: isSelected ? theme.accentColor : theme.textColor,
    ),
    side: BorderSide(color: isSelected ? theme.accentColor : theme.borderColor),
    visualDensity: VisualDensity.compact,
  );
}

// ── Interval row ─────────────────────────────────────────────────────────────

class _IntervalRow extends StatelessWidget {
  const _IntervalRow({
    required this.interval,
    required this.unitLabel,
    required this.onDecrement,
    required this.onIncrement,
    required this.theme,
  });

  final int interval;
  final String unitLabel;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final RecurrencePickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Every', style: _bodyStyle(theme)),
        SizedBox(width: theme.spacingS),
        _Stepper(
          value: interval,
          onDecrement: onDecrement,
          onIncrement: onIncrement,
          theme: theme,
        ),
        Text(unitLabel, style: _bodyStyle(theme)),
      ],
    );
  }
}

// ── Monthly options ──────────────────────────────────────────────────────────

class _MonthlyOptions extends StatelessWidget {
  const _MonthlyOptions({
    required this.pattern,
    required this.startDate,
    required this.onChanged,
    required this.theme,
  }) : assert(pattern is MonthlyByDay || pattern is MonthlyByWeekday);

  /// A [MonthlyByDay] or [MonthlyByWeekday].
  final RecurrencePattern pattern;
  final DateTime startDate;
  final ValueChanged<RecurrencePattern> onChanged;
  final RecurrencePickerTheme theme;

  String get _byDayLabel => switch (pattern) {
    MonthlyByDay(:final day, :final missingDay)
        when day == 31 && missingDay == MissingDay.useLastDay =>
      'Last day',
    MonthlyByDay(:final day) => 'On day $day',
    _ => 'On day ${startDate.day}',
  };

  String get _byWeekdayLabel {
    final (position, weekday) = switch (pattern) {
      MonthlyByWeekday(:final position, :final weekday) => (position, weekday),
      _ => (weekPositionOf(startDate), startDate.weekday),
    };
    return 'On the ${positionWord(position)} ${shortDayName(weekday)}';
  }

  void _selectMode(bool byWeekday) {
    switch (pattern) {
      case MonthlyByDay(:final interval) when byWeekday:
        onChanged(
          MonthlyByWeekday(
            interval: interval,
            position: weekPositionOf(startDate),
            weekday: startDate.weekday,
          ),
        );
      case MonthlyByWeekday(:final interval) when !byWeekday:
        onChanged(MonthlyByDay(interval: interval, day: startDate.day));
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(_byDayLabel)),
            ButtonSegment(value: true, label: Text(_byWeekdayLabel)),
          ],
          selected: {pattern is MonthlyByWeekday},
          onSelectionChanged: (selection) => _selectMode(selection.first),
          style: _segmentedStyle(theme),
        ),
        SizedBox(height: theme.spacingS),
        if (pattern case MonthlyByDay byDay)
          _MonthDayControls(
            pattern: byDay,
            startDate: startDate,
            onChanged: onChanged,
            theme: theme,
          )
        else if (pattern case MonthlyByWeekday byWeekday)
          _RelativeWeekdayControls(
            pattern: byWeekday,
            onChanged: onChanged,
            theme: theme,
          ),
      ],
    );
  }
}

class _MonthDayControls extends StatelessWidget {
  const _MonthDayControls({
    required this.pattern,
    required this.startDate,
    required this.onChanged,
    required this.theme,
  });

  final MonthlyByDay pattern;
  final DateTime startDate;
  final ValueChanged<RecurrencePattern> onChanged;
  final RecurrencePickerTheme theme;

  /// Offered when the start date is the last day of a month shorter than
  /// 31 days and the rule still targets that day.
  bool get _offersLastDayShortcut {
    final length = daysInMonth(startDate.year, startDate.month);
    return startDate.day == length && length < 31 && pattern.day == length;
  }

  String get _helperText => switch (pattern.missingDay) {
    MissingDay.useLastDay when pattern.day == 31 =>
      'Recurs on the last day of each month',
    MissingDay.useLastDay when pattern.day == 30 =>
      'For shorter months, recurs on the last day',
    MissingDay.useLastDay =>
      'For February in non-leap years, recurs on the 28th',
    MissingDay.skip => 'Skipped in months without a ${ordinal(pattern.day)}',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_offersLastDayShortcut) ...[
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text('On the ${ordinal(startDate.day)}'),
              ),
              const ButtonSegment(
                value: true,
                label: Text('Last day of month'),
              ),
            ],
            selected: const {false},
            onSelectionChanged: (selection) {
              if (selection.first) {
                onChanged(
                  pattern.copyWith(day: 31, missingDay: MissingDay.useLastDay),
                );
              }
            },
            style: _segmentedStyle(theme),
          ),
          SizedBox(height: theme.spacingS),
        ],
        Row(
          children: [
            Text('Day of month: ', style: _bodyStyle(theme)),
            _Stepper(
              value: pattern.day,
              onDecrement: pattern.day > 1
                  ? () => onChanged(pattern.copyWith(day: pattern.day - 1))
                  : null,
              onIncrement: pattern.day < 31
                  ? () => onChanged(pattern.copyWith(day: pattern.day + 1))
                  : null,
              theme: theme,
            ),
          ],
        ),
        if (pattern.day >= 29) ...[
          SizedBox(height: theme.spacingXS),
          Text(
            _helperText,
            style: TextStyle(
              fontSize: theme.fontSizeSmall,
              fontStyle: FontStyle.italic,
              color: theme.secondaryTextColor,
            ),
          ),
          SizedBox(height: theme.spacingS),
          _MissingDayToggle(
            label: 'In shorter months',
            useLastDayLabel: 'Use last day',
            value: pattern.missingDay,
            onChanged: (missingDay) =>
                onChanged(pattern.copyWith(missingDay: missingDay)),
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _RelativeWeekdayControls extends StatelessWidget {
  const _RelativeWeekdayControls({
    required this.pattern,
    required this.onChanged,
    required this.theme,
  });

  final MonthlyByWeekday pattern;
  final ValueChanged<RecurrencePattern> onChanged;
  final RecurrencePickerTheme theme;

  @override
  Widget build(BuildContext context) {
    final style = _bodyStyle(theme);
    return Row(
      children: [
        DropdownButton<WeekPosition>(
          value: pattern.position,
          items: [
            for (final position in WeekPosition.values)
              DropdownMenuItem(
                value: position,
                child: Text(
                  position == WeekPosition.last
                      ? 'Last'
                      : positionWord(position),
                ),
              ),
          ],
          onChanged: (position) {
            if (position != null) {
              onChanged(pattern.copyWith(position: position));
            }
          },
          underline: const SizedBox(),
          style: style,
        ),
        SizedBox(width: theme.spacingS),
        DropdownButton<int>(
          value: pattern.weekday,
          items: [
            for (
              var weekday = DateTime.monday;
              weekday <= DateTime.sunday;
              weekday++
            )
              DropdownMenuItem(
                value: weekday,
                child: Text(longDayName(weekday)),
              ),
          ],
          onChanged: (weekday) {
            if (weekday != null) onChanged(pattern.copyWith(weekday: weekday));
          },
          underline: const SizedBox(),
          style: style,
        ),
      ],
    );
  }
}

// ── Yearly options ───────────────────────────────────────────────────────────

class _YearlyOptions extends StatelessWidget {
  const _YearlyOptions({
    required this.pattern,
    required this.onChanged,
    required this.theme,
  });

  final Yearly pattern;
  final ValueChanged<RecurrencePattern> onChanged;
  final RecurrencePickerTheme theme;

  bool get _isLeapDay =>
      pattern.month == DateTime.february && pattern.day == 29;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'On ${monthName(pattern.month)} ${pattern.day}',
          style: TextStyle(
            fontSize: theme.fontSizeBody,
            color: theme.secondaryTextColor,
          ),
        ),
        if (_isLeapDay) ...[
          SizedBox(height: theme.spacingS),
          _MissingDayToggle(
            label: 'In non-leap years',
            useLastDayLabel: 'Feb 28',
            value: pattern.missingDay,
            onChanged: (missingDay) =>
                onChanged(pattern.copyWith(missingDay: missingDay)),
            theme: theme,
          ),
        ],
      ],
    );
  }
}

// ── Missing-day toggle ───────────────────────────────────────────────────────

class _MissingDayToggle extends StatelessWidget {
  const _MissingDayToggle({
    required this.label,
    required this.useLastDayLabel,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  final String label;
  final String useLastDayLabel;
  final MissingDay value;
  final ValueChanged<MissingDay> onChanged;
  final RecurrencePickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: theme.fontSizeSmall,
            color: theme.secondaryTextColor,
          ),
        ),
        SizedBox(height: theme.spacingXS),
        SegmentedButton<MissingDay>(
          segments: [
            ButtonSegment(
              value: MissingDay.useLastDay,
              label: Text(useLastDayLabel),
            ),
            const ButtonSegment(value: MissingDay.skip, label: Text('Skip')),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
          style: _segmentedStyle(theme),
        ),
      ],
    );
  }
}

// ── End condition ────────────────────────────────────────────────────────────

class _EndConditionControls extends StatelessWidget {
  const _EndConditionControls({
    required this.end,
    required this.onNever,
    required this.onOnDate,
    required this.onAfter,
    required this.onCountChanged,
    required this.onPickDate,
    required this.theme,
  });

  final RecurrenceEnd end;
  final VoidCallback onNever;
  final VoidCallback onOnDate;
  final VoidCallback onAfter;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<EndsOnDate> onPickDate;
  final RecurrencePickerTheme theme;

  static Type _kindOf(RecurrenceEnd end) => switch (end) {
    NeverEnds() => NeverEnds,
    EndsOnDate() => EndsOnDate,
    EndsAfterCount() => EndsAfterCount,
  };

  void _select(Type? kind) {
    if (kind == _kindOf(end)) return;
    if (kind == NeverEnds) onNever();
    if (kind == EndsOnDate) onOnDate();
    if (kind == EndsAfterCount) onAfter();
  }

  Widget _tile(String label, Type kind) => RadioListTile<Type>(
    title: Text(label, style: _bodyStyle(theme)),
    value: kind,
    activeColor: theme.accentColor,
    dense: true,
    contentPadding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ends',
          style: TextStyle(
            fontSize: theme.fontSizeBody,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        SizedBox(height: theme.spacingXS),
        RadioGroup<Type>(
          groupValue: _kindOf(end),
          onChanged: _select,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tile('Never', NeverEnds),
              _tile('On date', EndsOnDate),
              if (end case EndsOnDate onDate)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 4),
                  child: _EndDateRow(
                    end: onDate,
                    onTap: () => onPickDate(onDate),
                    theme: theme,
                  ),
                ),
              _tile('After', EndsAfterCount),
              if (end case EndsAfterCount(:final count))
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Row(
                    children: [
                      _Stepper(
                        value: count,
                        onDecrement: count > 1
                            ? () => onCountChanged(count - 1)
                            : null,
                        onIncrement: () => onCountChanged(count + 1),
                        theme: theme,
                      ),
                      Text('occurrences', style: _bodyStyle(theme)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EndDateRow extends StatelessWidget {
  const _EndDateRow({
    required this.end,
    required this.onTap,
    required this.theme,
  });

  final EndsOnDate end;
  final VoidCallback onTap;
  final RecurrencePickerTheme theme;

  @override
  Widget build(BuildContext context) {
    final formatted =
        theme.dateFormatter?.call(end.date) ?? formatFullDate(end.date);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: theme.accentColor),
          SizedBox(width: theme.spacingS),
          Text(formatted, style: _bodyStyle(theme)),
        ],
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.theme,
  });

  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final RecurrencePickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove_circle_outline,
          onPressed: onDecrement,
          theme: theme,
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: theme.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        _StepperButton(
          icon: Icons.add_circle_outline,
          onPressed: onIncrement,
          theme: theme,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.theme,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final RecurrencePickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      color: theme.accentColor,
    );
  }
}

class _DayOfWeekSelector extends StatelessWidget {
  const _DayOfWeekSelector({
    required this.selectedDays,
    required this.onChanged,
    required this.firstDayOfWeek,
    required this.theme,
  });

  final Set<int> selectedDays;

  /// Receives the toggled set, which may be empty.
  final ValueChanged<Set<int>> onChanged;
  final int firstDayOfWeek;
  final RecurrencePickerTheme theme;

  static const _dayLetters = {
    DateTime.monday: 'M',
    DateTime.tuesday: 'T',
    DateTime.wednesday: 'W',
    DateTime.thursday: 'T',
    DateTime.friday: 'F',
    DateTime.saturday: 'S',
    DateTime.sunday: 'S',
  };

  /// ISO weekdays in display order, starting from [firstDayOfWeek].
  List<int> get _orderedDays =>
      List.generate(7, (i) => (firstDayOfWeek - 1 + i) % 7 + 1);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [for (final day in _orderedDays) _dayCircle(day)],
    );
  }

  Widget _dayCircle(int day) {
    final selected = selectedDays.contains(day);
    return GestureDetector(
      onTap: () {
        final toggled = Set<int>.from(selectedDays);
        if (!toggled.remove(day)) toggled.add(day);
        onChanged(toggled);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? theme.accentColor.withValues(alpha: 0.2)
              : Colors.transparent,
          border: Border.all(
            color: selected ? theme.accentColor : theme.borderColor,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _dayLetters[day]!,
          style: TextStyle(
            fontSize: theme.fontSizeCompact,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? theme.accentColor : theme.secondaryTextColor,
          ),
        ),
      ),
    );
  }
}
