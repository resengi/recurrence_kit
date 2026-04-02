/// The frequency at which a [RecurrenceRule] repeats.
///
/// Combined with [RecurrenceRule.interval] to express patterns like
/// "every 2 weeks" or "every 3 months".
enum RecurrenceType {
  /// Repeats every N days.
  daily,

  /// Repeats on specific days of the week, every N weeks.
  weekly,

  /// Repeats on a fixed date or relative weekday, every N months.
  monthly,

  /// Repeats on a fixed month and day, every N years.
  yearly,
}
