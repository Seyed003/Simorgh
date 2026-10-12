/// Bytes moved through the tunnel on one day.
class DayUsage {
  const DayUsage({this.up = 0, this.down = 0});

  final int up;
  final int down;

  int get total => up + down;

  DayUsage add(int up, int down) =>
      DayUsage(up: this.up + up, down: this.down + down);
}

/// Daily usage keyed by local calendar day.
class UsageState {
  const UsageState({this.days = const {}});

  final Map<DateTime, DayUsage> days;

  static DateTime dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  DayUsage on(DateTime day) => days[dayOf(day)] ?? const DayUsage();

  /// Sum of the [count] days ending with [today].
  DayUsage lastDays(int count, DateTime today) {
    var sum = const DayUsage();
    for (var i = 0; i < count; i++) {
      final day = on(dayOf(today).subtract(Duration(days: i)));
      sum = sum.add(day.up, day.down);
    }
    return sum;
  }
}
