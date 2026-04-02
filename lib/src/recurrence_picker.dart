import 'package:flutter/material.dart';

import 'format_helpers.dart' as helpers;
import 'recurrence_end_type.dart';
import 'recurrence_picker_theme.dart';
import 'recurrence_rule.dart';
import 'recurrence_type.dart';

/// An inline recurrence rule editor widget.
///
/// Provides controls for frequency, interval, day/week/month selection,
/// and end conditions. Exposes the full [RecurrenceRule] — the parent
/// receives updates via [onChanged] whenever the user modifies any part
/// of the rule.
///
/// ```dart
/// RecurrencePicker(
///   rule: _rule,
///   onChanged: (updated) => setState(() => _rule = updated),
///   startDate: DateTime(2025, 1, 15),
///   theme: RecurrencePickerTheme(
///     accentColor: Colors.indigo,
///   ),
/// )
/// ```
///
/// ## End condition note
///
/// When [RecurrenceRule.endType] is [RecurrenceEndType.afterCount], the
/// parent is responsible for calling
/// [RecurrenceEngine.computeEndDateFromCount] at save time to pre-compute
/// the concrete end date.
class RecurrencePicker extends StatefulWidget {
  /// Creates an inline recurrence rule editor.
  const RecurrencePicker({
    required this.rule,
    required this.onChanged,
    required this.startDate,
    this.firstDayOfWeek = DateTime.sunday,
    this.theme = const RecurrencePickerTheme(),
    super.key,
  });

  /// Current recurrence rule.
  final RecurrenceRule rule;

  /// Called whenever the user changes any part of the rule.
  final ValueChanged<RecurrenceRule> onChanged;

  /// The start date of the task/event — used to derive defaults for
  /// monthly (day of month / weekday) and yearly (month + day).
  final DateTime startDate;

  /// Which day starts the week in the day-of-week selector.
  ///
  /// Accepts [DateTime.sunday] (default) or [DateTime.monday].
  final int firstDayOfWeek;

  /// Visual and functional configuration for the picker.
  final RecurrencePickerTheme theme;

  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  late RecurrenceType _type;
  late int _interval;
  late Set<int> _selectedDays;

  // Monthly state.
  late bool _monthlyRelative; // true = "2nd Tuesday", false = "on the 15th"
  late int _monthDay;
  late int _weekOfMonth;
  late int _dayOfWeek;

  // Yearly state.
  late int _yearMonth;
  late int _yearDay;

  // End condition state.
  late RecurrenceEndType _endType;
  DateTime? _endDate;
  late int _endAfterCount;

  @override
  void initState() {
    super.initState();
    _initFromRule(widget.rule);
  }

  @override
  void didUpdateWidget(RecurrencePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rule != oldWidget.rule) {
      _initFromRule(widget.rule);
    }
  }

  void _initFromRule(RecurrenceRule rule) {
    _type = rule.type;
    _interval = rule.interval;
    _selectedDays = Set<int>.from(rule.daysOfWeek ?? []);

    // Monthly defaults derived from start date.
    final sd = widget.startDate;
    _monthlyRelative = rule.isRelativeMonthly;
    _monthDay = rule.monthDay ?? sd.day;
    _weekOfMonth = rule.weekOfMonth ?? _weekOfMonthFromDate(sd);
    _dayOfWeek = rule.dayOfWeek ?? sd.weekday;

    // Yearly defaults derived from start date.
    _yearMonth = rule.monthOfYear ?? sd.month;
    _yearDay = rule.monthDay ?? sd.day;

    // End conditions.
    _endType = rule.endType;
    _endDate = rule.endDate;
    _endAfterCount = rule.endAfterCount ?? 10;
  }

  /// Compute which week-of-month occurrence the date falls on (1-4, or 5=last).
  static int _weekOfMonthFromDate(DateTime date) {
    final occurrence = ((date.day - 1) ~/ 7) + 1;
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    // If adding 7 days would exceed the month, this is the last occurrence.
    if (date.day + 7 > daysInMonth) return 5;
    return occurrence;
  }

  void _notifyChanged() {
    widget.onChanged(
      RecurrenceRule(
        type: _type,
        interval: _interval,
        daysOfWeek: _type == RecurrenceType.weekly
            ? (_selectedDays.toList()..sort())
            : null,
        monthDay: _type == RecurrenceType.monthly
            ? (_monthlyRelative ? null : _monthDay)
            : (_type == RecurrenceType.yearly ? _yearDay : null),
        weekOfMonth: (_type == RecurrenceType.monthly && _monthlyRelative)
            ? _weekOfMonth
            : null,
        dayOfWeek: (_type == RecurrenceType.monthly && _monthlyRelative)
            ? _dayOfWeek
            : null,
        monthOfYear: _type == RecurrenceType.yearly ? _yearMonth : null,
        endType: _endType,
        endDate: _endType == RecurrenceEndType.onDate ? _endDate : null,
        endAfterCount: _endType == RecurrenceEndType.afterCount
            ? _endAfterCount
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

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

        // ── 1. Frequency selector ──
        _FrequencyChips(
          selected: _type,
          onChanged: (type) {
            setState(() {
              _type = type;
              if (type == RecurrenceType.weekly && _selectedDays.isEmpty) {
                _selectedDays = {widget.startDate.weekday};
              }
            });
            _notifyChanged();
          },
          theme: theme,
        ),
        SizedBox(height: theme.spacingM),

        // ── 2. Interval row ──
        _IntervalRow(
          interval: _interval,
          type: _type,
          onDecrement: _interval > 1
              ? () {
                  setState(() => _interval--);
                  _notifyChanged();
                }
              : null,
          onIncrement: () {
            setState(() => _interval++);
            _notifyChanged();
          },
          theme: theme,
        ),

        // ── 3. Frequency-specific options ──
        if (_type == RecurrenceType.weekly) ...[
          SizedBox(height: theme.spacingM),
          Text(
            'On days',
            style: TextStyle(
              fontSize: theme.fontSizeBody,
              color: theme.textColor,
            ),
          ),
          SizedBox(height: theme.spacingS),
          _DayOfWeekSelector(
            selectedDays: _selectedDays,
            onChanged: (days) {
              setState(() => _selectedDays = days);
              _notifyChanged();
            },
            firstDayOfWeek: widget.firstDayOfWeek,
            theme: theme,
          ),
        ],
        if (_type == RecurrenceType.monthly) ...[
          SizedBox(height: theme.spacingM),
          _MonthlyOptions(
            monthlyRelative: _monthlyRelative,
            monthDay: _monthDay,
            weekOfMonth: _weekOfMonth,
            dayOfWeek: _dayOfWeek,
            startDate: widget.startDate,
            onRelativeChanged: (v) {
              setState(() => _monthlyRelative = v);
              _notifyChanged();
            },
            onMonthDayChanged: (v) {
              setState(() => _monthDay = v);
              _notifyChanged();
            },
            onWeekOfMonthChanged: (v) {
              setState(() => _weekOfMonth = v);
              _notifyChanged();
            },
            onDayOfWeekChanged: (v) {
              setState(() => _dayOfWeek = v);
              _notifyChanged();
            },
            theme: theme,
          ),
        ],
        if (_type == RecurrenceType.yearly) ...[
          SizedBox(height: theme.spacingM),
          Text(
            'Every year on ${_kMonthNames[_yearMonth]} $_yearDay',
            style: TextStyle(
              fontSize: theme.fontSizeBody,
              color: theme.secondaryTextColor,
            ),
          ),
        ],

        SizedBox(height: theme.spacingL),

        // ── 4. End condition ──
        _EndConditionControls(
          endType: _endType,
          endDate: _endDate,
          endAfterCount: _endAfterCount,
          startDate: widget.startDate,
          onEndTypeChanged: (v) {
            setState(() => _endType = v);
            _notifyChanged();
          },
          onEndDateChanged: (v) {
            setState(() => _endDate = v);
            _notifyChanged();
          },
          onEndAfterCountChanged: (v) {
            setState(() => _endAfterCount = v);
            _notifyChanged();
          },
          theme: theme,
        ),
      ],
    );
  }
}

// ── Constants ────────────────────────────────────────────────────────────────

const _kMonthNames = [
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

// ── Frequency Chips ──────────────────────────────────────────────────────────

class _FrequencyChips extends StatelessWidget {
  const _FrequencyChips({
    required this.selected,
    required this.onChanged,
    required this.theme,
  });

  final RecurrenceType selected;
  final ValueChanged<RecurrenceType> onChanged;
  final RecurrencePickerTheme theme;

  static String _label(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.yearly:
        return 'Yearly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: RecurrenceType.values.map((t) {
          final isSelected = t == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(t)),
              selected: isSelected,
              onSelected: (_) => onChanged(t),
              selectedColor: theme.accentColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                fontSize: theme.fontSizeCompact,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? theme.accentColor : theme.textColor,
              ),
              side: BorderSide(
                color: isSelected ? theme.accentColor : theme.borderColor,
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Interval Row ─────────────────────────────────────────────────────────────

class _IntervalRow extends StatelessWidget {
  const _IntervalRow({
    required this.interval,
    required this.type,
    required this.onDecrement,
    required this.onIncrement,
    required this.theme,
  });

  final int interval;
  final RecurrenceType type;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final RecurrencePickerTheme theme;

  static String _unitLabel(RecurrenceType type, int interval) {
    switch (type) {
      case RecurrenceType.daily:
        return interval == 1 ? 'day' : 'days';
      case RecurrenceType.weekly:
        return interval == 1 ? 'week' : 'weeks';
      case RecurrenceType.monthly:
        return interval == 1 ? 'month' : 'months';
      case RecurrenceType.yearly:
        return interval == 1 ? 'year' : 'years';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Every',
          style: TextStyle(
            fontSize: theme.fontSizeBody,
            color: theme.textColor,
          ),
        ),
        SizedBox(width: theme.spacingS),
        _StepperButton(
          icon: Icons.remove_circle_outline,
          onPressed: onDecrement,
          theme: theme,
        ),
        Text(
          '$interval',
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
        Text(
          _unitLabel(type, interval),
          style: TextStyle(
            fontSize: theme.fontSizeBody,
            color: theme.textColor,
          ),
        ),
      ],
    );
  }
}

// ── Monthly Options ──────────────────────────────────────────────────────────

class _MonthlyOptions extends StatelessWidget {
  const _MonthlyOptions({
    required this.monthlyRelative,
    required this.monthDay,
    required this.weekOfMonth,
    required this.dayOfWeek,
    required this.startDate,
    required this.onRelativeChanged,
    required this.onMonthDayChanged,
    required this.onWeekOfMonthChanged,
    required this.onDayOfWeekChanged,
    required this.theme,
  });

  final bool monthlyRelative;
  final int monthDay;
  final int weekOfMonth;
  final int dayOfWeek;
  final DateTime startDate;
  final ValueChanged<bool> onRelativeChanged;
  final ValueChanged<int> onMonthDayChanged;
  final ValueChanged<int> onWeekOfMonthChanged;
  final ValueChanged<int> onDayOfWeekChanged;
  final RecurrencePickerTheme theme;

  static String _shortDayName(int isoDay) {
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[isoDay];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle: fixed date vs. relative weekday.
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(monthDay == 31 ? 'Last day' : 'On day $monthDay'),
            ),
            ButtonSegment(
              value: true,
              label: Text(
                'On the ${helpers.ordinalWord(weekOfMonth)} ${_shortDayName(dayOfWeek)}',
              ),
            ),
          ],
          selected: {monthlyRelative},
          onSelectionChanged: (set) => onRelativeChanged(set.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: theme.fontSizeSmall),
            ),
          ),
        ),
        SizedBox(height: theme.spacingS),
        if (!monthlyRelative)
          _buildMonthDayPicker()
        else
          _buildRelativeWeekdayPicker(),
      ],
    );
  }

  Widget _buildMonthDayPicker() {
    // Check if start date is the last day of a short month and user
    // hasn't manually changed the day — offer "last day" shortcut.
    final daysInStartMonth = DateTime(
      startDate.year,
      startDate.month + 1,
      0,
    ).day;
    final isLastDayOfShortMonth =
        startDate.day == daysInStartMonth &&
        daysInStartMonth < 31 &&
        monthDay == startDate.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLastDayOfShortMonth) ...[
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text('On the ${startDate.day}th'),
              ),
              const ButtonSegment(
                value: true,
                label: Text('Last day of month'),
              ),
            ],
            selected: const {false},
            onSelectionChanged: (set) {
              if (set.first) onMonthDayChanged(31);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: theme.fontSizeSmall),
              ),
            ),
          ),
          SizedBox(height: theme.spacingS),
        ],
        Row(
          children: [
            Text(
              'Day of month: ',
              style: TextStyle(
                fontSize: theme.fontSizeBody,
                color: theme.textColor,
              ),
            ),
            _StepperButton(
              icon: Icons.remove_circle_outline,
              onPressed: monthDay > 1
                  ? () => onMonthDayChanged(monthDay - 1)
                  : null,
              theme: theme,
            ),
            Text(
              '$monthDay',
              style: TextStyle(
                fontSize: theme.fontSizeMedium,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            _StepperButton(
              icon: Icons.add_circle_outline,
              onPressed: monthDay < 31
                  ? () => onMonthDayChanged(monthDay + 1)
                  : null,
              theme: theme,
            ),
          ],
        ),
        if (monthDay >= 29) ...[
          SizedBox(height: theme.spacingXS),
          Text(
            monthDay == 31
                ? 'Recurs on the last day of each month'
                : monthDay == 30
                ? 'For shorter months, recurs on the last day'
                : 'For February in non-leap years, recurs on the 28th',
            style: TextStyle(
              fontSize: theme.fontSizeSmall,
              fontStyle: FontStyle.italic,
              color: theme.secondaryTextColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRelativeWeekdayPicker() {
    const ordinals = [
      (1, '1st'),
      (2, '2nd'),
      (3, '3rd'),
      (4, '4th'),
      (5, 'Last'),
    ];
    const weekdays = [
      (1, 'Monday'),
      (2, 'Tuesday'),
      (3, 'Wednesday'),
      (4, 'Thursday'),
      (5, 'Friday'),
      (6, 'Saturday'),
      (7, 'Sunday'),
    ];

    return Row(
      children: [
        DropdownButton<int>(
          value: weekOfMonth,
          items: ordinals
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: (v) {
            if (v != null) onWeekOfMonthChanged(v);
          },
          underline: const SizedBox(),
          style: TextStyle(
            fontSize: theme.fontSizeBody,
            color: theme.textColor,
          ),
        ),
        SizedBox(width: theme.spacingS),
        DropdownButton<int>(
          value: dayOfWeek,
          items: weekdays
              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
              .toList(),
          onChanged: (v) {
            if (v != null) onDayOfWeekChanged(v);
          },
          underline: const SizedBox(),
          style: TextStyle(
            fontSize: theme.fontSizeBody,
            color: theme.textColor,
          ),
        ),
      ],
    );
  }
}

// ── End Condition Controls ───────────────────────────────────────────────────

class _EndConditionControls extends StatelessWidget {
  const _EndConditionControls({
    required this.endType,
    required this.endDate,
    required this.endAfterCount,
    required this.startDate,
    required this.onEndTypeChanged,
    required this.onEndDateChanged,
    required this.onEndAfterCountChanged,
    required this.theme,
  });

  final RecurrenceEndType endType;
  final DateTime? endDate;
  final int endAfterCount;
  final DateTime startDate;
  final ValueChanged<RecurrenceEndType> onEndTypeChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<int> onEndAfterCountChanged;
  final RecurrencePickerTheme theme;

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

        RadioGroup<RecurrenceEndType>(
          groupValue: endType,
          onChanged: (v) {
            if (v != null) onEndTypeChanged(v);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Never.
              RadioListTile<RecurrenceEndType>(
                title: Text(
                  'Never',
                  style: TextStyle(fontSize: theme.fontSizeBody),
                ),
                value: RecurrenceEndType.never,
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),

              // On date.
              RadioListTile<RecurrenceEndType>(
                title: Text(
                  'On date',
                  style: TextStyle(fontSize: theme.fontSizeBody),
                ),
                value: RecurrenceEndType.onDate,
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              if (endType == RecurrenceEndType.onDate)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 4),
                  child: _buildEndDatePicker(context),
                ),

              // After count.
              RadioListTile<RecurrenceEndType>(
                title: Text(
                  'After',
                  style: TextStyle(fontSize: theme.fontSizeBody),
                ),
                value: RecurrenceEndType.afterCount,
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              if (endType == RecurrenceEndType.afterCount)
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: _buildEndAfterCountRow(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEndDatePicker(BuildContext context) {
    final formattedDate = endDate != null
        ? (theme.dateFormatter?.call(endDate!) ??
              helpers.formatFullDate(endDate!))
        : null;

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: endDate ?? startDate.add(const Duration(days: 30)),
          firstDate: startDate,
          lastDate: DateTime(theme.datePickerEndYear),
        );
        if (picked != null) onEndDateChanged(picked);
      },
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: theme.accentColor),
          SizedBox(width: theme.spacingS),
          Text(
            formattedDate ?? 'Select end date',
            style: TextStyle(
              fontSize: theme.fontSizeBody,
              color: endDate != null
                  ? theme.textColor
                  : theme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndAfterCountRow() {
    return Row(
      children: [
        _StepperButton(
          icon: Icons.remove_circle_outline,
          onPressed: endAfterCount > 1
              ? () => onEndAfterCountChanged(endAfterCount - 1)
              : null,
          theme: theme,
        ),
        Text(
          '$endAfterCount',
          style: TextStyle(
            fontSize: theme.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        _StepperButton(
          icon: Icons.add_circle_outline,
          onPressed: () => onEndAfterCountChanged(endAfterCount + 1),
          theme: theme,
        ),
        Text(
          'occurrences',
          style: TextStyle(
            fontSize: theme.fontSizeBody,
            color: theme.textColor,
          ),
        ),
      ],
    );
  }
}

// ── Shared Small Widgets ─────────────────────────────────────────────────────

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
    required this.theme,
    this.firstDayOfWeek = DateTime.sunday,
  });

  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onChanged;
  final int firstDayOfWeek;
  final RecurrencePickerTheme theme;

  // ISO weekday labels: Mon=1..Sun=7.
  static const _dayLabels = {
    1: 'M',
    2: 'T',
    3: 'W',
    4: 'T',
    5: 'F',
    6: 'S',
    7: 'S',
  };

  /// Returns ISO weekday values ordered starting from [firstDayOfWeek].
  List<int> get _orderedDays {
    final start = firstDayOfWeek == DateTime.sunday ? 7 : firstDayOfWeek;
    return List.generate(7, (i) => ((start - 1 + i) % 7) + 1);
  }

  @override
  Widget build(BuildContext context) {
    final days = _orderedDays;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final day = days[i];
        final selected = selectedDays.contains(day);

        return GestureDetector(
          onTap: () {
            final updated = Set<int>.from(selectedDays);
            if (selected && updated.length > 1) {
              updated.remove(day);
            } else {
              updated.add(day);
            }
            onChanged(updated);
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
              _dayLabels[day]!,
              style: TextStyle(
                fontSize: theme.fontSizeCompact,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? theme.accentColor : theme.secondaryTextColor,
              ),
            ),
          ),
        );
      }),
    );
  }
}
