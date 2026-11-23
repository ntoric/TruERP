import 'package:intl/intl.dart';

import '../../../core/api/json.dart';

enum PeriodKind {
  daily('daily', 'Day'),
  weekly('weekly', 'Week'),
  monthly('monthly', 'Month'),
  yearly('yearly', 'Year'),
  custom('custom', 'Custom');

  const PeriodKind(this.value, this.label);
  final String value;
  final String label;
}

/// The period selector shared by the dashboard reports
/// (`period`, `date`, `start_date`, `end_date` on the backend).
class ReportPeriod {
  const ReportPeriod({
    required this.kind,
    required this.anchor,
    this.start,
    this.end,
  });

  ReportPeriod.thisMonth() : this(kind: PeriodKind.monthly, anchor: _today());
  ReportPeriod.today() : this(kind: PeriodKind.daily, anchor: _today());

  final PeriodKind kind;

  /// Any date inside the period (daily/weekly/monthly/yearly).
  final DateTime anchor;

  /// Inclusive range for [PeriodKind.custom].
  final DateTime? start;
  final DateTime? end;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Map<String, dynamic> toQuery() => {
    'period': kind.value,
    'date': ymd(anchor),
    if (kind == PeriodKind.custom && start != null) 'start_date': ymd(start!),
    if (kind == PeriodKind.custom && end != null) 'end_date': ymd(end!),
  };

  ReportPeriod withKind(PeriodKind k) =>
      ReportPeriod(kind: k, anchor: anchor, start: start, end: end);

  ReportPeriod custom(DateTime s, DateTime e) =>
      ReportPeriod(kind: PeriodKind.custom, anchor: e, start: s, end: e);

  /// Previous / next period of the same size.
  ReportPeriod shift(int step) {
    final a = anchor;
    final next = switch (kind) {
      PeriodKind.daily => DateTime(a.year, a.month, a.day + step),
      PeriodKind.weekly => DateTime(a.year, a.month, a.day + 7 * step),
      // Clamp to day 1 so Jan 31 + 1 month doesn't skip February.
      PeriodKind.monthly => DateTime(a.year, a.month + step, 1),
      PeriodKind.yearly => DateTime(a.year + step, a.month, 1),
      PeriodKind.custom => a,
    };
    return ReportPeriod(kind: kind, anchor: next, start: start, end: end);
  }

  bool get canShift => kind != PeriodKind.custom;

  /// Whether moving forward would go into the future.
  bool get isCurrent {
    final t = _today();
    return switch (kind) {
      PeriodKind.daily => !anchor.isBefore(t),
      PeriodKind.weekly => t.difference(anchor).inDays < 7,
      PeriodKind.monthly => anchor.year == t.year && anchor.month == t.month,
      PeriodKind.yearly => anchor.year == t.year,
      PeriodKind.custom => true,
    };
  }

  /// Local label used until the server's own label arrives.
  String get label {
    switch (kind) {
      case PeriodKind.daily:
        return DateFormat('EEE, d MMM yyyy').format(anchor);
      case PeriodKind.weekly:
        final mon = anchor.subtract(Duration(days: anchor.weekday - 1));
        final sun = mon.add(const Duration(days: 6));
        return '${DateFormat('d MMM').format(mon)} – ${DateFormat('d MMM yyyy').format(sun)}';
      case PeriodKind.monthly:
        return DateFormat('MMMM yyyy').format(anchor);
      case PeriodKind.yearly:
        return '${anchor.year}';
      case PeriodKind.custom:
        final f = DateFormat('d MMM yyyy');
        return '${f.format(start ?? anchor)} – ${f.format(end ?? anchor)}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.kind == kind &&
      other.anchor == anchor &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, anchor, start, end);
}
