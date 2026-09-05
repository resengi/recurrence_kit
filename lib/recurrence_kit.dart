/// A recurrence rule system for Flutter: immutable rule types, a
/// computation engine, and a configurable picker widget.
///
/// ```dart
/// import 'package:recurrence_kit/recurrence_kit.dart';
///
/// final rule = RecurrenceRule(
///   pattern: Weekly(weekdays: [DateTime.monday, DateTime.wednesday]),
///   end: EndsAfterCount(10),
/// );
///
/// // Does the schedule occur on a date?
/// RecurrenceEngine.occursOnDate(rule, someDate, startDate);
///
/// // Inline editor
/// RecurrencePicker(
///   rule: rule,
///   onChanged: (updated) => setState(() => _rule = updated),
///   startDate: DateTime.now(),
/// )
/// ```
///
/// - **Model**: [RecurrenceRule], the sealed [RecurrencePattern] variants
///   ([Daily], [Weekly], [MonthlyByDay], [MonthlyByWeekday], [Yearly]) with
///   their [WeekPosition] and [MissingDay] options, and the sealed
///   [RecurrenceEnd] variants ([NeverEnds], [EndsOnDate], [EndsAfterCount]),
///   with JSON serialization on the rule.
/// - **Engine**: [RecurrenceEngine], pure stateless occurrence queries.
/// - **Widget**: [RecurrencePicker], themed via [RecurrencePickerTheme].
library;

export 'src/recurrence_engine.dart';
export 'src/recurrence_model.dart';
export 'src/recurrence_picker.dart';
export 'src/recurrence_picker_theme.dart';
export 'src/recurrence_rule.dart';
