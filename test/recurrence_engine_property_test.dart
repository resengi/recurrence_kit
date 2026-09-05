@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:recurrence_kit/recurrence_kit.dart';

import 'recurrence_oracle.dart';

/// Every engine query is checked against [oracleOccurrences] within a
/// walked window that starts at the schedule's start date and spans 10
/// years for daily and weekly rules, 30 years for monthly rules, and 60
/// years for yearly rules. Answers inside the window are compared exactly.
/// An answer the oracle cannot settle inside the window — a next
/// occurrence, further occurrences, or a last occurrence that would lie
/// beyond it — is only required to lie beyond the window.
const _casesPerPattern = 150;

const _seed = 20250101;

class _Case {
  _Case({required this.rule, required this.start, required this.query});

  final RecurrenceRule rule;
  final DateTime start;
  final DateTime query;

  @override
  String toString() =>
      '${jsonEncode(rule.toJson())} start=${_ymd(start)} query=${_ymd(query)}';
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

T _pick<T>(Random random, List<T> values) =>
    values[random.nextInt(values.length)];

int _interval(Random random) => 1 + random.nextInt(13);

MissingDay _missingDay(Random random) => _pick(random, MissingDay.values);

RecurrencePattern _pattern(Random random, String family) => switch (family) {
  'daily' => Daily(interval: _interval(random)),
  'weekly' => Weekly(
    interval: _interval(random),
    weekdays: [
      for (var d = 1; d <= 7; d++)
        if (random.nextInt(3) == 0) d,
      1 + random.nextInt(7),
    ],
  ),
  'monthlyByDay' => MonthlyByDay(
    interval: random.nextInt(4) == 0
        ? _pick(random, [12, 24])
        : _interval(random),
    day: random.nextBool() ? 29 + random.nextInt(3) : 1 + random.nextInt(31),
    missingDay: _missingDay(random),
  ),
  'monthlyByWeekday' => MonthlyByWeekday(
    interval: _interval(random),
    position: _pick(random, WeekPosition.values),
    weekday: 1 + random.nextInt(7),
  ),
  'yearly' => _yearly(random),
  _ => throw StateError(family),
};

Yearly _yearly(Random random) {
  if (random.nextBool()) {
    return Yearly(
      interval: _interval(random),
      month: 2,
      day: 29,
      missingDay: _missingDay(random),
    );
  }
  final month = 1 + random.nextInt(12);
  final maxDay = DateTime(2024, month + 1, 0).day;
  return Yearly(
    interval: _interval(random),
    month: month,
    day: 1 + random.nextInt(maxDay),
    missingDay: _missingDay(random),
  );
}

RecurrenceEnd _end(Random random) => switch (random.nextInt(3)) {
  0 => const NeverEnds(),
  1 => EndsOnDate(
    DateTime(
      2023 + random.nextInt(8),
      1 + random.nextInt(12),
      1 + random.nextInt(28),
    ),
  ),
  _ => EndsAfterCount(1 + random.nextInt(20)),
};

_Case _case(Random random, String family) {
  final start = DateTime(
    2023 + random.nextInt(4),
    1 + random.nextInt(12),
    1 + random.nextInt(31),
  );
  return _Case(
    rule: RecurrenceRule(
      pattern: _pattern(random, family),
      end: _end(random),
      includeStartDate: random.nextBool(),
    ),
    start: start,
    query: oraclePlusDays(start, random.nextInt(2100) - 600),
  );
}

int _windowYears(String family) => switch (family) {
  'daily' || 'weekly' => 10,
  'monthlyByDay' || 'monthlyByWeekday' => 30,
  _ => 60,
};

DateTime? _firstOnOrAfter(List<DateTime> dates, DateTime date) {
  for (final d in dates) {
    if (!d.isBefore(date)) return d;
  }
  return null;
}

DateTime? _lastOnOrBefore(List<DateTime> dates, DateTime date) {
  DateTime? last;
  for (final d in dates) {
    if (d.isAfter(date)) break;
    last = d;
  }
  return last;
}

void _check(_Case c, Random random, String family) {
  final rule = c.rule;
  final start = c.start;
  final query = c.query;
  final windowEnd = DateTime(
    start.year + _windowYears(family),
    start.month,
    start.day,
  );
  final expected = oracleOccurrences(rule, start, windowEnd);
  final complete = oracleIsComplete(rule, start, windowEnd, expected);
  final reason = '$c';

  // occursOnDate at the query date and at every date the oracle found.
  expect(
    RecurrenceEngine.occursOnDate(rule, query, start),
    expected.contains(query),
    reason: reason,
  );
  for (final date in expected.take(12)) {
    expect(
      RecurrenceEngine.occursOnDate(rule, date, start),
      isTrue,
      reason: reason,
    );
    final dayAfter = oraclePlusDays(date, 1);
    expect(
      RecurrenceEngine.occursOnDate(rule, dayAfter, start),
      expected.contains(dayAfter),
      reason: reason,
    );
  }

  // nextOccurrenceOnOrAfter.
  final next = RecurrenceEngine.nextOccurrenceOnOrAfter(rule, start, query);
  final expectedNext = _firstOnOrAfter(expected, query);
  if (expectedNext != null || complete) {
    expect(next, expectedNext, reason: reason);
  } else if (next != null) {
    expect(next.isAfter(windowEnd), isTrue, reason: reason);
  }

  // previousOccurrenceOnOrBefore is always settled: the walk covers every
  // date from the start date to the query date.
  expect(
    RecurrenceEngine.previousOccurrenceOnOrBefore(rule, start, query),
    _lastOnOrBefore(expected, query),
    reason: reason,
  );

  // occurrencesInRange over a span inside the window.
  final rangeEnd = oraclePlusDays(query, random.nextInt(121));
  expect(
    RecurrenceEngine.occurrencesInRange(rule, start, query, rangeEnd),
    expected.where((d) => !d.isBefore(query) && !d.isAfter(rangeEnd)).toList(),
    reason: reason,
  );

  // nextOccurrences: the settled prefix must match; anything further must
  // lie beyond the window.
  final count = random.nextInt(4);
  final expectedNexts = expected
      .where((d) => !d.isBefore(query))
      .take(count)
      .toList();
  final nexts = RecurrenceEngine.nextOccurrences(
    rule,
    start,
    query,
    count: count,
  );
  if (expectedNexts.length == count || complete) {
    expect(nexts, expectedNexts, reason: reason);
  } else {
    expect(
      nexts.length,
      greaterThanOrEqualTo(expectedNexts.length),
      reason: reason,
    );
    expect(
      nexts.take(expectedNexts.length).toList(),
      expectedNexts,
      reason: reason,
    );
    for (final d in nexts.skip(expectedNexts.length)) {
      expect(d.isAfter(windowEnd), isTrue, reason: reason);
    }
  }

  // lastOccurrence.
  final last = RecurrenceEngine.lastOccurrence(rule, start);
  switch (rule.end) {
    case NeverEnds():
      expect(last, complete ? expected.lastOrNull : null, reason: reason);
    case EndsOnDate():
      expect(last, expected.lastOrNull, reason: reason);
    case EndsAfterCount():
      if (complete) {
        expect(last, expected.lastOrNull, reason: reason);
      } else if (last != null) {
        expect(last.isAfter(windowEnd), isTrue, reason: reason);
      }
  }

  // JSON round trip.
  expect(
    RecurrenceRule.fromJson(jsonDecode(jsonEncode(rule.toJson()))),
    rule,
    reason: reason,
  );
}

void main() {
  const families = [
    'daily',
    'weekly',
    'monthlyByDay',
    'monthlyByWeekday',
    'yearly',
  ];
  for (var f = 0; f < families.length; f++) {
    final family = families[f];
    test('engine agrees with the oracle: $family', () {
      final random = Random(_seed + f);
      for (var i = 0; i < _casesPerPattern; i++) {
        _check(_case(random, family), random, family);
      }
    });
  }
}
