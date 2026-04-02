import 'dart:ui' show Color;

/// Visual and functional configuration for [RecurrencePicker].
///
/// Controls colors, font sizes, spacing, and functional options like the
/// date picker range and date formatting. Every field maps 1:1 to a
/// specific visual element in the picker — there are no inherited or
/// implicit theme lookups.
///
/// All fields have sensible defaults. Pass `const RecurrencePickerTheme()`
/// for a zero-config experience, or override selectively:
///
/// ```dart
/// RecurrencePicker(
///   rule: myRule,
///   onChanged: (r) => setState(() => _rule = r),
///   startDate: DateTime.now(),
///   theme: RecurrencePickerTheme(
///     accentColor: Colors.indigo,
///     fontSizeBody: 15.0,
///   ),
/// )
/// ```
///
/// Use [copyWith] to derive a modified theme from an existing one.
class RecurrencePickerTheme {
  /// Creates a picker theme configuration.
  ///
  /// All parameters are optional and fall back to neutral defaults that
  /// work well across both light and dark backgrounds.
  const RecurrencePickerTheme({
    this.textColor = const Color(0xFF1A1A1A),
    this.secondaryTextColor = const Color(0xFF6B6B6B),
    this.accentColor = const Color(0xFF5B6ABF),
    this.borderColor = const Color(0xFFD0D0D0),
    this.fontSizeBody = 14.0,
    this.fontSizeMedium = 16.0,
    this.fontSizeCompact = 13.0,
    this.fontSizeSmall = 12.0,
    this.spacingXS = 4.0,
    this.spacingS = 8.0,
    this.spacingM = 12.0,
    this.spacingL = 16.0,
    this.datePickerEndYear = 2040,
    this.dateFormatter,
  });

  // ── Colors ───────────────────────────────────────────────────────────────

  /// Primary text color used for labels and values.
  final Color textColor;

  /// Secondary text color used for hints, helper text, and de-emphasized
  /// content.
  final Color secondaryTextColor;

  /// Accent color used for selected chips, active radio indicators, stepper
  /// buttons, and the date-picker icon.
  final Color accentColor;

  /// Border color used for unselected chips and day-of-week circles.
  final Color borderColor;

  // ── Font sizes ───────────────────────────────────────────────────────────

  /// Body text size used for labels like "Every", "On days", "Ends", and
  /// dropdown items.
  final double fontSizeBody;

  /// Medium text size used for stepper counter values.
  final double fontSizeMedium;

  /// Compact text size used for chip labels and day-of-week circle letters.
  final double fontSizeCompact;

  /// Small text size used for helper notes and segmented button labels.
  final double fontSizeSmall;

  // ── Spacing ──────────────────────────────────────────────────────────────

  /// Extra-small spacing (e.g. between a stepper row and its helper note).
  final double spacingXS;

  /// Small spacing (e.g. between a label and its control).
  final double spacingS;

  /// Medium spacing (e.g. between major sections within the picker).
  final double spacingM;

  /// Large spacing (e.g. before the end-condition section).
  final double spacingL;

  // ── Functional ───────────────────────────────────────────────────────────

  /// The last year offered in the "end on date" date picker.
  final int datePickerEndYear;

  /// Optional custom date formatter for the end-date display.
  ///
  /// When null, the picker uses `intl`'s `DateFormat.yMMMd()` which
  /// produces output like "Jan 15, 2025".
  final String Function(DateTime)? dateFormatter;

  // ── copyWith ─────────────────────────────────────────────────────────────

  RecurrencePickerTheme copyWith({
    Color? textColor,
    Color? secondaryTextColor,
    Color? accentColor,
    Color? borderColor,
    double? fontSizeBody,
    double? fontSizeMedium,
    double? fontSizeCompact,
    double? fontSizeSmall,
    double? spacingXS,
    double? spacingS,
    double? spacingM,
    double? spacingL,
    int? datePickerEndYear,
    String Function(DateTime)? dateFormatter,
  }) {
    return RecurrencePickerTheme(
      textColor: textColor ?? this.textColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      accentColor: accentColor ?? this.accentColor,
      borderColor: borderColor ?? this.borderColor,
      fontSizeBody: fontSizeBody ?? this.fontSizeBody,
      fontSizeMedium: fontSizeMedium ?? this.fontSizeMedium,
      fontSizeCompact: fontSizeCompact ?? this.fontSizeCompact,
      fontSizeSmall: fontSizeSmall ?? this.fontSizeSmall,
      spacingXS: spacingXS ?? this.spacingXS,
      spacingS: spacingS ?? this.spacingS,
      spacingM: spacingM ?? this.spacingM,
      spacingL: spacingL ?? this.spacingL,
      datePickerEndYear: datePickerEndYear ?? this.datePickerEndYear,
      dateFormatter: dateFormatter ?? this.dateFormatter,
    );
  }
}
