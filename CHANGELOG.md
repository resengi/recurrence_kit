# Change Log



## 2026-09-05

### Changes

---

Packages with breaking changes:

 - [`recurrence_kit` - `v0.2.0`](#recurrence_kit---v020)

Packages with other changes:

 - There are no other changes in this release.

---

#### `recurrence_kit` - `v0.2.0`

 - **BREAKING** **FEAT**: Major refactor to add some new features and fix bugs ([#2](https://github.com/resengi/recurrence_kit/issues/2)). ([da3ded41](https://github.com/resengi/recurrence_kit/commit/da3ded41fb6e75bc53a795928abbe1b1bcd4763a))

## 0.2.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: Major refactor to add some new features and fix bugs ([#2](https://github.com/resengi/recurrence_kit/issues/2)). ([da3ded41](https://github.com/resengi/recurrence_kit/commit/da3ded41fb6e75bc53a795928abbe1b1bcd4763a))


## 2026-04-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`recurrence_kit` - `v0.1.1`](#recurrence_kit---v011)

---

#### `recurrence_kit` - `v0.1.1`

 - **FEAT**: Initial feat of the main business logic for the package ([#1](https://github.com/resengi/recurrence_kit/issues/1)). ([dce5d7a5](https://github.com/resengi/recurrence_kit/commit/dce5d7a5ba7c2dc8bc941411063c73be611266a8))

## 0.1.1

 - **FEAT**: Initial feat of the main business logic for the package ([#1](https://github.com/resengi/recurrence_kit/issues/1)). ([dce5d7a5](https://github.com/resengi/recurrence_kit/commit/dce5d7a5ba7c2dc8bc941411063c73be611266a8))

# Change Log

## 0.1.0

- Initial release.
- `RecurrenceType` — enum for daily, weekly, monthly, and yearly frequencies.
- `RecurrenceEndType` — enum for never, on-date, and after-count end conditions.
- `RecurrenceRule` — immutable recurrence model with `fromJson`, `toJson`, `copyWith`, `displayText`, and equality.
- `RecurrenceEngine` — pure stateless computation with direct-jump arithmetic.
  - `occursOnDate` — checks whether a rule matches a specific date.
  - `nextOccurrences` — returns the next N occurrence dates.
  - `computeEndDateFromCount` — resolves "after N occurrences" to a concrete end date, with optional `maxCount` safety cap.
- `RecurrencePicker` — inline editor widget for building recurrence rules interactively.
- `RecurrencePickerTheme` — single config class for colors, font sizes, spacing, and functional options.
- DST-safe date calculations throughout the engine.
- Monthly relative weekday support (`"2nd Tuesday"`, `"last Friday"`).
- Short-month and leap-day fallback handling.alculations throughout the engine.
- Monthly relative weekday support (`"2nd Tuesday"`, `"last Friday"`).
- Short-month and leap-day fallback handling.lback handling.alculations throughout the engine.
- Monthly relative weekday support (`"2nd Tuesday"`, `"last Friday"`).
- Short-month and leap-day fallback handling.