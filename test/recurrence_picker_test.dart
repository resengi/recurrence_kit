import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurrence_kit/recurrence_kit.dart';

/// 2025-01-15 is a Wednesday, the third Wednesday of January.
final _defaultStart = DateTime(2025, 1, 15);

RecurrenceRule _rule(
  RecurrencePattern pattern, {
  RecurrenceEnd end = const NeverEnds(),
  bool includeStartDate = false,
}) => RecurrenceRule(
  pattern: pattern,
  end: end,
  includeStartDate: includeStartDate,
);

/// Hosts a picker the way an app does: it holds the rule and, unless
/// [accepts] is false, adopts every emission. The held rule lives in the
/// host's state, so a host is one scenario; [_pump] keys each host so that
/// successive pumps in a test start from their own initial rule.
class _Host extends StatefulWidget {
  const _Host({
    required this.initialRule,
    required this.onChanged,
    required this.startDate,
    this.firstDayOfWeek = DateTime.sunday,
    this.theme = const RecurrencePickerTheme(),
    this.accepts = true,
    super.key,
  });

  final RecurrenceRule initialRule;
  final ValueChanged<RecurrenceRule> onChanged;
  final DateTime startDate;
  final int firstDayOfWeek;
  final RecurrencePickerTheme theme;
  final bool accepts;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late RecurrenceRule rule = widget.initialRule;

  void replace(RecurrenceRule replacement) =>
      setState(() => rule = replacement);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecurrencePicker(
            rule: rule,
            onChanged: (emitted) {
              widget.onChanged(emitted);
              if (widget.accepts) setState(() => rule = emitted);
            },
            startDate: widget.startDate,
            firstDayOfWeek: widget.firstDayOfWeek,
            theme: widget.theme,
          ),
        ),
      ),
    );
  }
}

/// Pumps a fresh host showing [rule] and returns the list its emissions
/// are recorded in. Pass [key] to reach the host's state from the test.
Future<List<RecurrenceRule>> _pump(
  WidgetTester tester,
  RecurrenceRule rule, {
  DateTime? startDate,
  int firstDayOfWeek = DateTime.sunday,
  RecurrencePickerTheme theme = const RecurrencePickerTheme(),
  bool accepts = true,
  Key? key,
}) async {
  final emissions = <RecurrenceRule>[];
  await tester.pumpWidget(
    _Host(
      key: key ?? UniqueKey(),
      initialRule: rule,
      onChanged: emissions.add,
      startDate: startDate ?? _defaultStart,
      firstDayOfWeek: firstDayOfWeek,
      theme: theme,
      accepts: accepts,
    ),
  );
  return emissions;
}

Finder _stepperIncrement() => find.byIcon(Icons.add_circle_outline);

Finder _stepperDecrement() => find.byIcon(Icons.remove_circle_outline);

DatePickerDialog _dialog(WidgetTester tester) =>
    tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));

bool _isEnabled(WidgetTester tester, Finder iconFinder) =>
    tester
        .widget<IconButton>(
          find.ancestor(of: iconFinder, matching: find.byType(IconButton)),
        )
        .onPressed !=
    null;

void main() {
  group('rendering', () {
    testWidgets('daily', (tester) async {
      await _pump(tester, _rule(Daily(interval: 3)));
      expect(find.text('Repeat'), findsOneWidget);
      for (final label in ['Daily', 'Weekly', 'Monthly', 'Yearly']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Every'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('days'), findsOneWidget);
      expect(find.text('On days'), findsNothing);
      expect(find.text('Ends'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);
    });

    testWidgets('weekly', (tester) async {
      await _pump(tester, _rule(Weekly(weekdays: [1])));
      expect(find.text('On days'), findsOneWidget);
      expect(find.text('week'), findsOneWidget);
    });

    testWidgets('monthly by day', (tester) async {
      await _pump(tester, _rule(MonthlyByDay(day: 15)));
      expect(find.text('On day 15'), findsOneWidget);
      expect(find.text('On the 3rd Wed'), findsOneWidget);
      expect(find.text('Day of month: '), findsOneWidget);
      expect(find.text('month'), findsOneWidget);
    });

    testWidgets('monthly by weekday', (tester) async {
      await _pump(
        tester,
        _rule(MonthlyByWeekday(position: WeekPosition.last, weekday: 5)),
      );
      expect(find.text('On the last Fri'), findsOneWidget);
      expect(find.text('On day 15'), findsOneWidget);
      expect(find.text('Last'), findsOneWidget);
      expect(find.text('Friday'), findsOneWidget);
    });

    testWidgets('yearly', (tester) async {
      await _pump(tester, _rule(Yearly(month: 6, day: 15)));
      expect(find.text('On June 15'), findsOneWidget);
      expect(find.text('year'), findsOneWidget);

      await _pump(tester, _rule(Yearly(interval: 2, month: 6, day: 15)));
      expect(find.text('On June 15'), findsOneWidget);
      expect(find.text('years'), findsOneWidget);
    });

    testWidgets('end modes', (tester) async {
      await _pump(tester, _rule(Daily(), end: EndsAfterCount(7)));
      expect(find.text('7'), findsOneWidget);
      expect(find.text('occurrences'), findsOneWidget);

      await _pump(
        tester,
        _rule(Daily(), end: EndsOnDate(DateTime(2025, 6, 1))),
      );
      expect(find.text('Jun 1, 2025'), findsOneWidget);
    });

    testWidgets('theme accent color reaches the date icon and the end radios', (
      tester,
    ) async {
      await _pump(
        tester,
        _rule(Daily(), end: EndsOnDate(DateTime(2025, 6, 1))),
        theme: const RecurrencePickerTheme(accentColor: Colors.teal),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.calendar_today)).color,
        Colors.teal,
      );
      final tiles = tester
          .widgetList<RadioListTile<Type>>(find.byType(RadioListTile<Type>))
          .toList();
      expect(tiles, hasLength(3));
      for (final tile in tiles) {
        expect(tile.activeColor, Colors.teal);
      }
    });

    testWidgets('custom date formatter is used', (tester) async {
      await _pump(
        tester,
        _rule(Daily(), end: EndsOnDate(DateTime(2025, 6, 1))),
        theme: RecurrencePickerTheme(
          dateFormatter: (d) => '${d.year}/${d.month}/${d.day}',
        ),
      );
      expect(find.text('2025/6/1'), findsOneWidget);
    });
  });

  group('frequency chips', () {
    testWidgets('Weekly seeds the start weekday and carries the interval', (
      tester,
    ) async {
      final emissions = await _pump(tester, _rule(Daily(interval: 2)));
      await tester.tap(find.text('Weekly'));
      await tester.pump();
      expect(emissions, [
        _rule(Weekly(interval: 2, weekdays: [DateTime.wednesday])),
      ]);
    });

    testWidgets('Monthly seeds the start day of month', (tester) async {
      final emissions = await _pump(tester, _rule(Daily()));
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      expect(emissions, [_rule(MonthlyByDay(day: 15))]);
    });

    testWidgets('Yearly seeds the start month and day', (tester) async {
      final emissions = await _pump(tester, _rule(Daily()));
      await tester.tap(find.text('Yearly'));
      await tester.pump();
      expect(emissions, [_rule(Yearly(month: 1, day: 15))]);
    });

    testWidgets('Daily from a weekly rule', (tester) async {
      final emissions = await _pump(
        tester,
        _rule(Weekly(interval: 3, weekdays: [1, 2])),
      );
      await tester.tap(find.text('Daily'));
      await tester.pump();
      expect(emissions, [_rule(Daily(interval: 3))]);
    });

    testWidgets('the active chip emits nothing', (tester) async {
      final emissions = await _pump(tester, _rule(Daily()));
      await tester.tap(find.text('Daily'));
      await tester.pump();
      expect(emissions, isEmpty);

      final monthly = await _pump(
        tester,
        _rule(MonthlyByWeekday(position: WeekPosition.first, weekday: 1)),
      );
      await tester.tap(find.text('Monthly'));
      await tester.pump();
      expect(monthly, isEmpty);
    });

    testWidgets('the end and includeStartDate are preserved', (tester) async {
      final emissions = await _pump(
        tester,
        _rule(Daily(), end: EndsAfterCount(4), includeStartDate: true),
      );
      await tester.tap(find.text('Weekly'));
      await tester.pump();
      expect(emissions.single.end, EndsAfterCount(4));
      expect(emissions.single.includeStartDate, isTrue);
    });
  });

  group('interval', () {
    testWidgets('increments and decrements', (tester) async {
      final emissions = await _pump(tester, _rule(Daily(interval: 2)));
      await tester.tap(_stepperIncrement());
      await tester.pump();
      expect(emissions.last, _rule(Daily(interval: 3)));
      await tester.tap(_stepperDecrement());
      await tester.pump();
      expect(emissions.last, _rule(Daily(interval: 2)));
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('cannot go below 1', (tester) async {
      await _pump(tester, _rule(Daily()));
      expect(_isEnabled(tester, _stepperDecrement()), isFalse);
      expect(_isEnabled(tester, _stepperIncrement()), isTrue);
    });

    testWidgets('unit label follows the interval', (tester) async {
      await _pump(tester, _rule(Weekly(interval: 2, weekdays: [1])));
      expect(find.text('weeks'), findsOneWidget);
    });
  });

  group('weekday selector', () {
    testWidgets('toggles days on and off', (tester) async {
      final emissions = await _pump(tester, _rule(Weekly(weekdays: [1])));
      await tester.tap(find.text('F'));
      await tester.pump();
      expect(emissions.last, _rule(Weekly(weekdays: [1, 5])));
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(emissions.last, _rule(Weekly(weekdays: [5])));
    });

    testWidgets('removing the only day emits nothing', (tester) async {
      final emissions = await _pump(tester, _rule(Weekly(weekdays: [1])));
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(emissions, isEmpty);
    });

    testWidgets('firstDayOfWeek orders the circles', (tester) async {
      await _pump(tester, _rule(Weekly(weekdays: [1])));
      expect(
        tester.getTopLeft(find.text('M')).dx,
        lessThan(tester.getTopLeft(find.text('W')).dx),
      );

      await _pump(
        tester,
        _rule(Weekly(weekdays: [1])),
        firstDayOfWeek: DateTime.wednesday,
      );
      expect(
        tester.getTopLeft(find.text('W')).dx,
        lessThan(tester.getTopLeft(find.text('M')).dx),
      );
    });
  });

  group('monthly', () {
    testWidgets('switching to by-weekday seeds the start position', (
      tester,
    ) async {
      final emissions = await _pump(
        tester,
        _rule(MonthlyByDay(interval: 2, day: 15)),
      );
      await tester.tap(find.text('On the 3rd Wed'));
      await tester.pump();
      expect(emissions, [
        _rule(
          MonthlyByWeekday(
            interval: 2,
            position: WeekPosition.third,
            weekday: DateTime.wednesday,
          ),
        ),
      ]);
    });

    testWidgets('switching to by-day seeds the start day', (tester) async {
      final emissions = await _pump(
        tester,
        _rule(MonthlyByWeekday(position: WeekPosition.last, weekday: 5)),
      );
      await tester.tap(find.text('On day 15'));
      await tester.pump();
      expect(emissions, [_rule(MonthlyByDay(day: 15))]);
    });

    testWidgets(
      'a start on the last day of a short month seeds that day and offers the last-day shortcut',
      (tester) async {
        final start = DateTime(2025, 2, 28);
        final emissions = await _pump(tester, _rule(Daily()), startDate: start);
        await tester.tap(find.text('Monthly'));
        await tester.pump();
        expect(emissions.last, _rule(MonthlyByDay(day: 28)));
        expect(find.text('Last day of month'), findsOneWidget);
        await tester.tap(find.text('Last day of month'));
        await tester.pump();
        expect(emissions.last, _rule(MonthlyByDay(day: 31)));
        expect(find.text('Last day of month'), findsNothing);
        expect(find.text('Last day'), findsOneWidget);
      },
    );

    testWidgets('day stepper is bounded to 1-31', (tester) async {
      final emissions = await _pump(tester, _rule(MonthlyByDay(day: 30)));
      final dayIncrement = _stepperIncrement().last;
      await tester.tap(dayIncrement);
      await tester.pump();
      expect(emissions.last, _rule(MonthlyByDay(day: 31)));
      expect(_isEnabled(tester, _stepperIncrement().last), isFalse);

      await _pump(tester, _rule(MonthlyByDay(day: 1)));
      expect(_isEnabled(tester, _stepperDecrement().last), isFalse);
    });

    testWidgets('the missing-day toggle appears only for days 29-31', (
      tester,
    ) async {
      await _pump(tester, _rule(MonthlyByDay(day: 28)));
      expect(find.text('In shorter months'), findsNothing);

      final emissions = await _pump(tester, _rule(MonthlyByDay(day: 29)));
      expect(find.text('In shorter months'), findsOneWidget);
      expect(find.text('Use last day'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(emissions, [
        _rule(MonthlyByDay(day: 29, missingDay: MissingDay.skip)),
      ]);
      expect(find.text('Skipped in months without a 29th'), findsOneWidget);
    });

    testWidgets('missingDay survives day edits', (tester) async {
      final emissions = await _pump(
        tester,
        _rule(MonthlyByDay(day: 30, missingDay: MissingDay.skip)),
      );
      await tester.tap(_stepperIncrement().last);
      await tester.pump();
      expect(
        emissions.last,
        _rule(MonthlyByDay(day: 31, missingDay: MissingDay.skip)),
      );
    });

    testWidgets('position and weekday dropdowns', (tester) async {
      final emissions = await _pump(
        tester,
        _rule(MonthlyByWeekday(position: WeekPosition.first, weekday: 1)),
      );
      await tester.tap(find.text('1st'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last').last);
      await tester.pumpAndSettle();
      expect(
        emissions.last,
        _rule(MonthlyByWeekday(position: WeekPosition.last, weekday: 1)),
      );

      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friday').last);
      await tester.pumpAndSettle();
      expect(
        emissions.last,
        _rule(MonthlyByWeekday(position: WeekPosition.last, weekday: 5)),
      );
    });
  });

  group('yearly', () {
    testWidgets('the non-leap-year toggle appears only for February 29', (
      tester,
    ) async {
      await _pump(tester, _rule(Yearly(month: 6, day: 15)));
      expect(find.text('In non-leap years'), findsNothing);

      final emissions = await _pump(
        tester,
        _rule(Yearly(month: 2, day: 29)),
        startDate: DateTime(2024, 2, 29),
      );
      expect(find.text('In non-leap years'), findsOneWidget);
      expect(find.text('Feb 28'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(emissions, [
        _rule(Yearly(month: 2, day: 29, missingDay: MissingDay.skip)),
      ]);
    });
  });

  group('end condition', () {
    testWidgets('Never', (tester) async {
      final emissions = await _pump(
        tester,
        _rule(Daily(), end: EndsAfterCount(3)),
      );
      await tester.tap(find.text('Never'));
      await tester.pump();
      expect(emissions, [_rule(Daily())]);
    });

    testWidgets('After seeds the theme default count', (tester) async {
      final emissions = await _pump(tester, _rule(Daily()));
      await tester.tap(find.text('After'));
      await tester.pump();
      expect(emissions, [_rule(Daily(), end: EndsAfterCount(10))]);

      final custom = await _pump(
        tester,
        _rule(Daily()),
        theme: const RecurrencePickerTheme(defaultEndAfterCount: 3),
      );
      await tester.tap(find.text('After'));
      await tester.pump();
      expect(custom, [_rule(Daily(), end: EndsAfterCount(3))]);
    });

    testWidgets('the count stepper is bounded below by 1', (tester) async {
      final emissions = await _pump(
        tester,
        _rule(Daily(), end: EndsAfterCount(1)),
      );
      expect(_isEnabled(tester, _stepperDecrement().last), isFalse);
      await tester.tap(_stepperIncrement().last);
      await tester.pump();
      expect(emissions.last, _rule(Daily(), end: EndsAfterCount(2)));
    });

    testWidgets('the active mode emits nothing', (tester) async {
      final emissions = await _pump(
        tester,
        _rule(Daily(), end: EndsAfterCount(3)),
      );
      await tester.tap(find.text('After'));
      await tester.pump();
      expect(emissions, isEmpty);
    });

    testWidgets('On date seeds the first date of the schedule', (tester) async {
      final daily = await _pump(tester, _rule(Daily()));
      await tester.tap(find.text('On date'));
      await tester.pump();
      expect(daily, [_rule(Daily(), end: EndsOnDate(_defaultStart))]);

      final fridays = await _pump(
        tester,
        _rule(Weekly(weekdays: [DateTime.friday])),
      );
      await tester.tap(find.text('On date'));
      await tester.pump();
      expect(fridays, [
        _rule(
          Weekly(weekdays: [DateTime.friday]),
          end: EndsOnDate(DateTime(2025, 1, 17)),
        ),
      ]);
    });

    testWidgets('On date for a schedule with no dates seeds the start date', (
      tester,
    ) async {
      final never = MonthlyByDay(
        interval: 12,
        day: 30,
        missingDay: MissingDay.skip,
      );
      final start = DateTime(2025, 2, 1);
      final emissions = await _pump(tester, _rule(never), startDate: start);
      await tester.tap(find.text('On date'));
      await tester.pump();
      expect(emissions, [_rule(never, end: EndsOnDate(start))]);
    });

    testWidgets('On date ignores the existing after-count when seeding', (
      tester,
    ) async {
      final emissions = await _pump(
        tester,
        _rule(Daily(), end: EndsAfterCount(1)),
      );
      await tester.tap(find.text('On date'));
      await tester.pump();
      expect(emissions, [_rule(Daily(), end: EndsOnDate(_defaultStart))]);
    });
  });

  group('end-date dialog', () {
    final onDate = _rule(Daily(), end: EndsOnDate(DateTime(2025, 1, 20)));

    testWidgets('confirming keeps the existing date as the cursor', (
      tester,
    ) async {
      final emissions = await _pump(tester, onDate);
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(emissions, [onDate]);
    });

    testWidgets('cancelling emits nothing', (tester) async {
      final emissions = await _pump(tester, onDate);
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(emissions, isEmpty);
    });

    testWidgets('a picked date replaces the end', (tester) async {
      final emissions = await _pump(tester, onDate);
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(emissions, [
        _rule(Daily(), end: EndsOnDate(DateTime(2025, 1, 25))),
      ]);
    });

    testWidgets(
      'the picked date applies to the rule current when the dialog closes',
      (tester) async {
        final key = GlobalKey<_HostState>();
        final emissions = await _pump(tester, onDate, key: key);
        await tester.tap(find.byIcon(Icons.calendar_today));
        await tester.pumpAndSettle();
        key.currentState!.replace(onDate.copyWith(pattern: Daily(interval: 5)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('25'));
        await tester.pump();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(emissions, [
          _rule(Daily(interval: 5), end: EndsOnDate(DateTime(2025, 1, 25))),
        ]);
      },
    );

    testWidgets('an end before the start date opens at the start date', (
      tester,
    ) async {
      final emissions = await _pump(
        tester,
        _rule(Daily(), end: EndsOnDate(DateTime(2024, 6, 1))),
      );
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      expect(_dialog(tester).initialDate, _defaultStart);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(emissions, [_rule(Daily(), end: EndsOnDate(_defaultStart))]);
    });

    testWidgets('the range runs from the start date to a century ahead', (
      tester,
    ) async {
      await _pump(tester, onDate);
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      final dialog = _dialog(tester);
      expect(dialog.firstDate, _defaultStart);
      expect(dialog.lastDate, DateTime(2125, 1, 15));
      expect(dialog.initialDate, DateTime(2025, 1, 20));
    });

    testWidgets('the default horizon uses the last day of a shorter month', (
      tester,
    ) async {
      await _pump(
        tester,
        _rule(Daily(), end: EndsOnDate(DateTime(2000, 3, 1))),
        startDate: DateTime(2000, 2, 29),
      );
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      expect(_dialog(tester).lastDate, DateTime(2100, 2, 28));
    });

    testWidgets('a custom horizon replaces the default in either direction', (
      tester,
    ) async {
      await _pump(
        tester,
        onDate,
        theme: RecurrencePickerTheme(
          datePickerLastDate: DateTime(2030, 12, 31),
        ),
      );
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      expect(_dialog(tester).lastDate, DateTime(2030, 12, 31));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await _pump(
        tester,
        onDate,
        theme: RecurrencePickerTheme(datePickerLastDate: DateTime(2300, 1, 1)),
      );
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      expect(_dialog(tester).lastDate, DateTime(2300, 1, 1));
    });

    testWidgets('a horizon on the start date is accepted', (tester) async {
      await _pump(
        tester,
        onDate.copyWith(end: EndsOnDate(_defaultStart)),
        theme: RecurrencePickerTheme(
          datePickerLastDate: DateTime(2025, 1, 15, 9),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      final dialog = _dialog(tester);
      expect(dialog.firstDate, _defaultStart);
      expect(dialog.lastDate, _defaultStart);
    });

    testWidgets('an end beyond the horizon stays reachable', (tester) async {
      final far = _rule(Daily(), end: EndsOnDate(DateTime(2100, 1, 1)));
      final emissions = await _pump(
        tester,
        far,
        theme: RecurrencePickerTheme(datePickerLastDate: DateTime(2030, 1, 1)),
      );
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      final dialog = _dialog(tester);
      expect(dialog.lastDate, DateTime(2100, 1, 1));
      expect(dialog.initialDate, DateTime(2100, 1, 1));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(emissions, [far]);
    });
  });

  group('configuration', () {
    testWidgets('a count seed below 1 is rejected on build', (tester) async {
      await _pump(
        tester,
        _rule(Daily()),
        theme: const RecurrencePickerTheme(defaultEndAfterCount: 0),
      );
      expect(tester.takeException(), isArgumentError);
    });

    testWidgets('a horizon before the start date is rejected on build', (
      tester,
    ) async {
      await _pump(
        tester,
        _rule(Daily()),
        theme: RecurrencePickerTheme(datePickerLastDate: DateTime(2025, 1, 14)),
      );
      expect(tester.takeException(), isArgumentError);
    });

    testWidgets('firstDayOfWeek outside 1-7 is rejected on build', (
      tester,
    ) async {
      await _pump(tester, _rule(Daily()), firstDayOfWeek: 0);
      expect(tester.takeException(), isArgumentError);
      await _pump(tester, _rule(Daily()), firstDayOfWeek: 8);
      expect(tester.takeException(), isArgumentError);
    });
  });

  group('controlled behavior', () {
    testWidgets('an ignored emission changes nothing', (tester) async {
      final emissions = await _pump(tester, _rule(Daily()), accepts: false);
      await tester.tap(_stepperIncrement());
      await tester.pump();
      await tester.tap(_stepperIncrement());
      await tester.pump();
      expect(emissions, [_rule(Daily(interval: 2)), _rule(Daily(interval: 2))]);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a replaced rule is rendered', (tester) async {
      final key = GlobalKey<_HostState>();
      await _pump(tester, _rule(Daily()), key: key);
      expect(find.text('On days'), findsNothing);
      key.currentState!.replace(_rule(Weekly(weekdays: [1])));
      await tester.pumpAndSettle();
      expect(find.text('On days'), findsOneWidget);
    });
  });
}
