/// How a recurrence terminates.
///
/// Stored on [RecurrenceRule].
enum RecurrenceEndType {
  /// Repeats indefinitely.
  never,

  /// Repeats until a specific date (stored in [RecurrenceRule.endDate]).
  onDate,

  /// Repeats for a fixed number of occurrences. The concrete end date is
  /// pre-computed at save time and stored in [RecurrenceRule.endDate];
  /// [RecurrenceRule.endAfterCount] is retained for display purposes.
  afterCount,
}
