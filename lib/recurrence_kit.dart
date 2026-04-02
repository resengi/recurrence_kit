/// A standalone recurrence rule system — data models, computation engine,
/// and a configurable picker UI widget.
///
/// ## Quick start
///
/// ```dart
/// import 'package:recurrence_kit/recurrence_kit.dart';
///
/// // Create a rule
/// final rule = RecurrenceRule(
///   type: RecurrenceType.weekly,
///   daysOfWeek: [1, 3, 5],
/// );
///
/// // Check if a date matches
/// RecurrenceEngine.occursOnDate(rule, someDate, startDate);
///
/// // Full picker widget
/// RecurrencePicker(
///   rule: rule,
///   onChanged: (updated) => setState(() => _rule = updated),
///   startDate: DateTime.now(),
/// )
/// ```
///
/// ## What's included
///
/// - **Models**: [RecurrenceRule], [RecurrenceType], [RecurrenceEndType] —
///   immutable data with JSON serialization.
/// - **Engine**: [RecurrenceEngine] — pure, stateless occurrence logic.
/// - **Widget**: [RecurrencePicker] — a configurable inline editor for
///   building recurrence rules, themed via [RecurrencePickerTheme].
library;

export 'src/recurrence_end_type.dart';
export 'src/recurrence_engine.dart';
export 'src/recurrence_picker.dart';
export 'src/recurrence_picker_theme.dart';
export 'src/recurrence_rule.dart';
export 'src/recurrence_type.dart';
