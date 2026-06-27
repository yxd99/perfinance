/// Returns the last day of [month] in [year].
/// Uses DateTime overflow trick: day 0 of next month = last day of this month.
int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Clamps [day] to the valid range [1, lastDayOfMonth(year, month)].
int clampEffectiveDay(int day, int year, int month) =>
    day.clamp(1, lastDayOfMonth(year, month));
