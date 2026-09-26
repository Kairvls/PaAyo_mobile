import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../widgets/chart_tooltip.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

enum ScheduleAlertFilter { all, dueSoon, overdue }

enum _AlertRange { monthly, weekly, today }

/// Notification inbox for schedules that need action soon or are overdue.
class ScheduleAlertsScreen extends StatefulWidget {
  final ScheduleAlertFilter filter;

  const ScheduleAlertsScreen({
    super.key,
    this.filter = ScheduleAlertFilter.all,
  });

  @override
  State<ScheduleAlertsScreen> createState() => _ScheduleAlertsScreenState();
}

class _ScheduleAlertsScreenState extends State<ScheduleAlertsScreen> {
  static const _ink = Color(0xFF111827);
  static const _blue = Color(0xFF0025CC);
  static const _bg = Colors.white;
  static const _barGrey = Color(0xFFD1D5DB);
  static const _barLavender = Color(0xFFC7D2FE);

  final MaintenanceService _service = MaintenanceService();
  final TextEditingController _search = TextEditingController();
  late Future<List<MaintenanceSchedule>> _future;
  late _AlertRange _chartRange;
  late _AlertRange _listRange;

  @override
  void initState() {
    super.initState();
    final overdueFocused = widget.filter == ScheduleAlertFilter.overdue;
    _chartRange = _AlertRange.weekly;
    // Overdue lists default to Monthly so older past-due items stay visible.
    _listRange = overdueFocused ? _AlertRange.monthly : _AlertRange.weekly;
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.listSchedules(limit: 100).then(
            (items) => items.where((s) {
              final q = (s.equipmentQr ?? "").trim();
              return q.isNotEmpty && q != "—";
            }).toList(),
          );
    });
  }

  String get _pageTitle {
    switch (widget.filter) {
      case ScheduleAlertFilter.dueSoon:
        return "Due Soon";
      case ScheduleAlertFilter.overdue:
        return "Overdue";
      case ScheduleAlertFilter.all:
        return "Schedule Alerts";
    }
  }

  String get _listTitle {
    switch (widget.filter) {
      case ScheduleAlertFilter.dueSoon:
        return "Due Soon List";
      case ScheduleAlertFilter.overdue:
        return "Overdue List";
      case ScheduleAlertFilter.all:
        return "Alert List";
    }
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Inclusive start of the selected range window for list filtering.
  DateTime _rangeStart(_AlertRange range) {
    switch (range) {
      case _AlertRange.today:
        return _today;
      case _AlertRange.weekly:
        return _today.subtract(const Duration(days: 6));
      case _AlertRange.monthly:
        return DateTime(_today.year, _today.month - 1, _today.day);
    }
  }

  bool _inListRange(MaintenanceSchedule s, _AlertRange range) {
    if (s.nextDate == null) return range == _AlertRange.monthly;

    final due = DateTime(s.nextDate!.year, s.nextDate!.month, s.nextDate!.day);

    // Overdue page: toggle filters by how long past due.
    if (widget.filter == ScheduleAlertFilter.overdue) {
      if (!s.isOverdue) return false;
      final daysPast = _today.difference(due).inDays;
      switch (range) {
        case _AlertRange.today:
          return daysPast <= 1;
        case _AlertRange.weekly:
          return daysPast <= 7;
        case _AlertRange.monthly:
          return true;
      }
    }

    final start = _rangeStart(range);
    final end =
        _today.add(const Duration(days: MaintenanceSchedule.dueSoonDays));
    return !due.isBefore(start) && !due.isAfter(end);
  }

  Future<void> _open(MaintenanceSchedule schedule) {
    return promptScanToManage(
      context,
      equipmentName: schedule.equipmentName,
      destination: ScanDestination.schedule,
    );
  }

  /// Builds 4 time buckets with overdue / due-soon / other counts.
  ({List<String> labels, List<double> overdue, List<double> dueSoon, List<double> other})
      _chartSeries(List<MaintenanceSchedule> all) {
    final labels = <String>[];
    final overdueVals = <double>[];
    final dueSoonVals = <double>[];
    final otherVals = <double>[];

    late final List<({DateTime start, DateTime end, String label})> buckets;

    switch (_chartRange) {
      case _AlertRange.today:
        // Last 4 days ending today.
        buckets = List.generate(4, (i) {
          final day = _today.subtract(Duration(days: 3 - i));
          return (
            start: day,
            end: day,
            label: DateFormat("MMM d").format(day),
          );
        });
      case _AlertRange.weekly:
        // Last 4 weeks (Mon–Sun style rolling 7-day windows).
        buckets = List.generate(4, (i) {
          final end = _today.subtract(Duration(days: (3 - i) * 7));
          final start = end.subtract(const Duration(days: 6));
          return (
            start: start,
            end: end,
            label: DateFormat("MMM d").format(end),
          );
        });
      case _AlertRange.monthly:
        buckets = List.generate(4, (i) {
          final endMonth = DateTime(_today.year, _today.month - (3 - i) + 1, 0);
          final start = DateTime(endMonth.year, endMonth.month, 1);
          return (
            start: start,
            end: endMonth,
            label: DateFormat("MMM").format(start),
          );
        });
    }

    for (final b in buckets) {
      var overdue = 0;
      var dueSoon = 0;
      var other = 0;
      for (final s in all) {
        if (s.nextDate == null) continue;
        final d = DateTime(s.nextDate!.year, s.nextDate!.month, s.nextDate!.day);
        if (d.isBefore(b.start) || d.isAfter(b.end)) continue;
        if (s.isOverdue) {
          overdue++;
        } else if (s.isDueSoon) {
          dueSoon++;
        } else {
          other++;
        }
      }
      labels.add(b.label);
      overdueVals.add(overdue.toDouble());
      dueSoonVals.add(dueSoon.toDouble());
      otherVals.add(other.toDouble());
    }

    return (
      labels: labels,
      overdue: overdueVals,
      dueSoon: dueSoonVals,
      other: otherVals,
    );
  }

  String _daysPastValue(MaintenanceSchedule s) {
    if (s.nextDate == null) return "+ —";
    final due = DateTime(s.nextDate!.year, s.nextDate!.month, s.nextDate!.day);
    final days = _today.difference(due).inDays;
    if (days <= 0) {
      final left = due.difference(_today).inDays;
      return left == 0 ? "Today" : "+ $left d";
    }
    return "+ $days d";
  }

  String _initials(String? name) {
    final parts = (name ?? "EQ")
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return "EQ";
    if (parts.length == 1) {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  List<MaintenanceSchedule> _filterSearch(List<MaintenanceSchedule> items) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((s) {
      final hay = [
        s.title,
        s.equipmentName ?? "",
        s.room ?? "",
        s.frequency,
        s.status,
        s.urgencyLabel,
      ].join(" ").toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Widget _buildSearchField() {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _ink, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => setState(() {}),
              style: const TextStyle(
                color: _ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: "Search alerts...",
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: const Color(0xFFEEF0F4),
          ),
          IconButton(
            tooltip: "Search",
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d, yyyy");
    final filter = widget.filter;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          foregroundColor: _ink,
          title: Text(
            _pageTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 20,
            ),
          ),
        ),
        body: FutureBuilder<List<MaintenanceSchedule>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Couldn't load alerts."),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              );
            }

            final all = snap.data ?? [];
            final overdue = all.where((s) => s.isOverdue).toList();
            final dueSoon =
                all.where((s) => s.isDueSoon && !s.isOverdue).toList();

            List<MaintenanceSchedule> listItems;
            switch (filter) {
              case ScheduleAlertFilter.overdue:
                listItems = overdue;
              case ScheduleAlertFilter.dueSoon:
                listItems = dueSoon;
              case ScheduleAlertFilter.all:
                listItems = [...overdue, ...dueSoon];
            }

            listItems = listItems
                .where((s) => _inListRange(s, _listRange))
                .toList();
            listItems = _filterSearch(listItems);

            // Keep overdue sorted most overdue first.
            listItems.sort((a, b) {
              final ad = a.nextDate ?? DateTime(2100);
              final bd = b.nextDate ?? DateTime(2100);
              return ad.compareTo(bd);
            });

            final series = _chartSeries(all);

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: _buildSearchField(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _pageTitle == "Schedule Alerts"
                                      ? "Overview"
                                      : _pageTitle,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              _RangeToggle(
                                value: _chartRange,
                                onChanged: (v) =>
                                    setState(() => _chartRange = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 18, 20, 0),
                      child: SizedBox(
                        height: 210,
                        child: _GroupedBarChart(
                          labels: series.labels,
                          seriesA: series.overdue,
                          seriesB: series.dueSoon,
                          seriesC: series.other,
                          colorA: _blue,
                          colorB: _barGrey,
                          colorC: _barLavender,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _listTitle,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          _RangeToggle(
                            value: _listRange,
                            onChanged: (v) => setState(() => _listRange = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (listItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _search.text.trim().isNotEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  "No alerts match your search.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            )
                          : _EmptyAlerts(filter: filter),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final s = listItems[i];
                          return _AlertOrderRow(
                            initials: _initials(s.equipmentName),
                            name: s.equipmentName ?? "Equipment",
                            dateText: s.nextDate != null
                                ? dateFmt.format(s.nextDate!)
                                : "No date",
                            valueText: _daysPastValue(s),
                            statusText: s.urgencyLabel,
                            showDivider: i < listItems.length - 1,
                            onTap: () => _open(s),
                          );
                        },
                        childCount: listItems.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final _AlertRange value;
  final ValueChanged<_AlertRange> onChanged;

  const _RangeToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _AlertRange range) {
      final selected = value == range;
      return GestureDetector(
        onTap: () => onChanged(range),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0025CC) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip("Monthly", _AlertRange.monthly),
          chip("Weekly", _AlertRange.weekly),
          chip("Today", _AlertRange.today),
        ],
      ),
    );
  }
}

class _GroupedBarChart extends StatefulWidget {
  final List<String> labels;
  final List<double> seriesA;
  final List<double> seriesB;
  final List<double> seriesC;
  final Color colorA;
  final Color colorB;
  final Color colorC;

  const _GroupedBarChart({
    required this.labels,
    required this.seriesA,
    required this.seriesB,
    required this.seriesC,
    required this.colorA,
    required this.colorB,
    required this.colorC,
  });

  @override
  State<_GroupedBarChart> createState() => _GroupedBarChartState();
}

class _GroupedBarChartState extends State<_GroupedBarChart> {
  int? _focus;

  void _setFocus(Offset local, double width) {
    if (widget.labels.isEmpty || width <= 0) return;
    final i = chartNearestIndex(local.dx, width, widget.labels.length);
    if (_focus != i) setState(() => _focus = i);
  }

  @override
  Widget build(BuildContext context) {
    final maxRaw = [
      ...widget.seriesA,
      ...widget.seriesB,
      ...widget.seriesC,
    ].fold<double>(0, (m, v) => math.max(m, v));
    final peak = maxRaw <= 0 ? 4.0 : maxRaw * 1.15;

    final mid = (peak / 2).ceilToDouble();
    final yLabels = [
      chartFmtValue(peak),
      chartFmtValue(mid * 1.5 > peak ? peak * 0.75 : mid * 1.5),
      chartFmtValue(mid),
      '0',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final y in yLabels)
                Text(
                  y,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB0B5BD),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final focusX = _focus == null || widget.labels.length <= 1
                        ? null
                        : (constraints.maxWidth / widget.labels.length) *
                            (_focus! + 0.5);
                    return TapRegion(
                      onTapOutside: (_) {
                        if (_focus != null) setState(() => _focus = null);
                      },
                      child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) =>
                          _setFocus(d.localPosition, constraints.maxWidth),
                      onPanUpdate: (d) =>
                          _setFocus(d.localPosition, constraints.maxWidth),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GroupedBarPainter(
                                seriesA: widget.seriesA,
                                seriesB: widget.seriesB,
                                seriesC: widget.seriesC,
                                colorA: widget.colorA,
                                colorB: widget.colorB,
                                colorC: widget.colorC,
                                peak: peak,
                                gridColor: const Color(0xFFE5E7EB),
                                focusIndex: _focus,
                              ),
                            ),
                          ),
                          if (_focus != null && focusX != null)
                            Positioned(
                              left: (focusX - 70).clamp(
                                0.0,
                                math.max(0.0, constraints.maxWidth - 150),
                              ),
                              top: 6,
                              child: ChartTooltipBubble(
                                title: widget.labels[_focus!],
                                rows: [
                                  ChartTooltipRow(
                                    color: widget.colorA,
                                    label: 'Overdue',
                                    value: chartFmtValue(
                                      _focus! < widget.seriesA.length
                                          ? widget.seriesA[_focus!]
                                          : 0,
                                    ),
                                  ),
                                  ChartTooltipRow(
                                    color: widget.colorB,
                                    label: 'Due soon',
                                    value: chartFmtValue(
                                      _focus! < widget.seriesB.length
                                          ? widget.seriesB[_focus!]
                                          : 0,
                                    ),
                                  ),
                                  ChartTooltipRow(
                                    color: widget.colorC,
                                    label: 'Other',
                                    value: chartFmtValue(
                                      _focus! < widget.seriesC.length
                                          ? widget.seriesC[_focus!]
                                          : 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final label in widget.labels)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupedBarPainter extends CustomPainter {
  final List<double> seriesA;
  final List<double> seriesB;
  final List<double> seriesC;
  final Color colorA;
  final Color colorB;
  final Color colorC;
  final double peak;
  final Color gridColor;
  final int? focusIndex;

  _GroupedBarPainter({
    required this.seriesA,
    required this.seriesB,
    required this.seriesC,
    required this.colorA,
    required this.colorB,
    required this.colorC,
    required this.peak,
    required this.gridColor,
    this.focusIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = seriesA.length;
    if (n == 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var g = 0; g < 4; g++) {
      final y = size.height * (g / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final groupWidth = size.width / n;
    const barWidth = 10.0;
    const gap = 4.0;
    final cluster = barWidth * 3 + gap * 2;

    for (var i = 0; i < n; i++) {
      final cx = groupWidth * i + groupWidth / 2;
      final left = cx - cluster / 2;
      final dim = focusIndex != null && focusIndex != i;
      _drawBar(canvas, size, left, seriesA[i], colorA, dim: dim);
      _drawBar(canvas, size, left + barWidth + gap, seriesB[i], colorB, dim: dim);
      _drawBar(canvas, size, left + (barWidth + gap) * 2, seriesC[i], colorC, dim: dim);
    }

    if (focusIndex != null) {
      final fi = focusIndex!.clamp(0, n - 1);
      final fx = groupWidth * fi + groupWidth / 2;
      canvas.drawLine(
        Offset(fx, 0),
        Offset(fx, size.height),
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawBar(
    Canvas canvas,
    Size size,
    double x,
    double value,
    Color color, {
    bool dim = false,
  }) {
    const barWidth = 10.0;
    final h = peak <= 0 ? 0.0 : (value / peak) * size.height;
    final top = size.height - h;
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, top, barWidth, math.max(h, value > 0 ? 3 : 0)),
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = dim ? color.withValues(alpha: 0.35) : color,
    );
  }

  @override
  bool shouldRepaint(covariant _GroupedBarPainter oldDelegate) {
    return oldDelegate.seriesA != seriesA ||
        oldDelegate.seriesB != seriesB ||
        oldDelegate.seriesC != seriesC ||
        oldDelegate.peak != peak ||
        oldDelegate.focusIndex != focusIndex;
  }
}

class _AlertOrderRow extends StatelessWidget {
  final String initials;
  final String name;
  final String dateText;
  final String valueText;
  final String statusText;
  final bool showDivider;
  final VoidCallback onTap;

  const _AlertOrderRow({
    required this.initials,
    required this.name,
    required this.dateText,
    required this.valueText,
    required this.statusText,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0025CC),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateText,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    valueText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0025CC),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F3)),
          ),
      ],
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  final ScheduleAlertFilter filter;

  const _EmptyAlerts({required this.filter});

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      ScheduleAlertFilter.dueSoon => "No due-soon schedules",
      ScheduleAlertFilter.overdue => "No overdue schedules",
      ScheduleAlertFilter.all => "No schedule alerts",
    };
    final subtitle = switch (filter) {
      ScheduleAlertFilter.dueSoon =>
        "Nothing is due within ${MaintenanceSchedule.dueSoonDays} days.",
      ScheduleAlertFilter.overdue =>
        "No equipment schedules are past due.",
      ScheduleAlertFilter.all =>
        "Overdue and due-soon equipment will show up here.",
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
