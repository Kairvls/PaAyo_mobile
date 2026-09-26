import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../utils/equipment_icon.dart';
import '../../widgets/product_list_row.dart';
import '../../widgets/chart_tooltip.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

enum _HistoryChartRange { week, month }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF9CA3AF);
  static const _blue = Color(0xFF0025CC);
  static const _page = Colors.white;

  final MaintenanceService _service = MaintenanceService();
  late final TextEditingController _search;
  late Future<List<MaintenanceRecord>> _future;
  _HistoryChartRange _chartRange = _HistoryChartRange.month;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.listHistory();
    });
  }

  List<MaintenanceRecord> _filter(List<MaintenanceRecord> items) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((r) {
      final hay = [
        r.equipmentName ?? "",
        r.room ?? "",
        r.status,
        r.personnel,
        r.findings ?? "",
        r.repairAction ?? "",
        r.replacementRemarks ?? "",
      ].join(" ").toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  bool _isResolved(MaintenanceRecord r) {
    final t = r.status.toLowerCase();
    return t.contains("resolve") ||
        t.contains("complete") ||
        t.contains("done") ||
        t.contains("fixed");
  }

  bool _isPending(MaintenanceRecord r) {
    final t = r.status.toLowerCase();
    return t.contains("pending") ||
        t.contains("processing") ||
        t.contains("progress");
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int _countThisWeek(List<MaintenanceRecord> all) {
    final start = _today.subtract(Duration(days: _today.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 7));
    return all.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return !d.isBefore(start) && d.isBefore(end);
    }).length;
  }

  /// Daily / monthly fix counts for the chart.
  /// Week = last 7 days; Month = last 6 calendar months.
  ({List<double> values, List<String> labels}) _chartSeries(
    List<MaintenanceRecord> all,
  ) {
    if (_chartRange == _HistoryChartRange.week) {
      // Last 7 days ending today, labeled by weekday.
      final values = List<double>.filled(7, 0);
      final labels = <String>[];
      for (var i = 6; i >= 0; i--) {
        final day = _today.subtract(Duration(days: i));
        labels.add(DateFormat("E").format(day)); // Sun, Mon, ...
        values[6 - i] = all
            .where((r) {
              final d = r.date.toLocal();
              return d.year == day.year &&
                  d.month == day.month &&
                  d.day == day.day;
            })
            .length
            .toDouble();
      }
      return (values: values, labels: labels);
    }

    // Last 6 calendar months (includes older history like Jun/Jul).
    const monthCount = 6;
    final values = List<double>.filled(monthCount, 0);
    final labels = <String>[];
    for (var m = monthCount - 1; m >= 0; m--) {
      final monthStart = DateTime(_today.year, _today.month - m, 1);
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
      labels.add(DateFormat("MMM").format(monthStart));
      final idx = monthCount - 1 - m;
      values[idx] = all.where((r) {
        final d = r.date.toLocal();
        final day = DateTime(d.year, d.month, d.day);
        return !day.isBefore(monthStart) && day.isBefore(monthEnd);
      }).length.toDouble();
    }
    return (values: values, labels: labels);
  }

  Future<void> _openRecord(MaintenanceRecord record) {
    return promptScanToManage(
      context,
      equipmentName: record.equipmentName,
      destination: ScanDestination.history,
    );
  }

  Future<void> _openScanner() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const QRScannerScreen(destination: ScanDestination.history),
      ),
    ).then((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _pickChartRange() async {
    final chosen = await showModalBottomSheet<_HistoryChartRange>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                title: const Text("Week"),
                trailing: _chartRange == _HistoryChartRange.week
                    ? const Icon(Icons.check_rounded, color: _blue)
                    : null,
                onTap: () => Navigator.pop(context, _HistoryChartRange.week),
              ),
              ListTile(
                title: const Text("Month"),
                trailing: _chartRange == _HistoryChartRange.month
                    ? const Icon(Icons.check_rounded, color: _blue)
                    : null,
                onTap: () => Navigator.pop(context, _HistoryChartRange.month),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen != null && mounted) setState(() => _chartRange = chosen);
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k >= 10 ? "${k.round()}K" : "${k.toStringAsFixed(1)}K";
    }
    return "$n";
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final dateFmt = DateFormat("MMM d, yyyy");

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _page,
        body: FutureBuilder<List<MaintenanceRecord>>(
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
                    const Text("Couldn't load history."),
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
            final items = _filter(all);
            final searching = _search.text.trim().isNotEmpty;
            final total = all.length;
            final resolved = all.where(_isResolved).length;
            final pending = all.where(_isPending).length;
            final weekCount = _countThisWeek(all);
            final resolvedPct =
                total == 0 ? 0.0 : (resolved / total) * 100;
            final series = _chartSeries(all);

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeroHeader(
                      topInset: topInset,
                      onBack: () => Navigator.maybePop(context),
                      onScan: _openScanner,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "History summary",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Maintenance records shown in stats and charts.",
                            style: TextStyle(
                              fontSize: 13,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 118,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _StatCard(
                            icon: Icons.history_rounded,
                            value: _formatCount(total),
                            label: "Total records",
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.touch_app_rounded,
                            value: "${resolvedPct.toStringAsFixed(1)}%",
                            label: "Resolved rate",
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.hourglass_empty_rounded,
                            value: _formatCount(pending),
                            label: "Pending fixes",
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.groups_rounded,
                            value: _formatCount(weekCount),
                            label: "Fixes this week",
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "History overview",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                              ),
                              Material(
                                color: Colors.white,
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: InkWell(
                                  customBorder: const StadiumBorder(),
                                  onTap: _pickChartRange,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _chartRange ==
                                                  _HistoryChartRange.week
                                              ? "Week"
                                              : "Month",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: _ink,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: _ink,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: _HistoryLineChart(
                              values: series.values,
                              labels: series.labels,
                              lineColor: _blue,
                              fillColor: _blue.withValues(alpha: 0.12),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            "Recent history",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _SearchField(
                            controller: _search,
                            onChanged: () => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (all.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyHistory(),
                    )
                  else if (items.isEmpty && searching)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            "No history matches your search.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, height: 1.4),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final r = items[i];
                          return ProductListRow(
                            leading: ProductListRow.thumbnail(
                              child: EquipmentGraphic(
                                name: r.equipmentName ?? "Equipment",
                                size: 32,
                                fallbackColor: _blue,
                              ),
                            ),
                            title: r.equipmentName ?? "Equipment",
                            subtitle: ProductListRow.joinMeta([
                              r.status,
                              if (r.room != null && r.room!.isNotEmpty) r.room,
                              dateFmt.format(r.date.toLocal()),
                            ]),
                            actionLabel: "View",
                            showDivider: i < items.length - 1,
                            onTap: () => _openRecord(r),
                          );
                        },
                        childCount: items.length,
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

class _HeroHeader extends StatelessWidget {
  final double topInset;
  final VoidCallback onBack;
  final VoidCallback onScan;

  const _HeroHeader({
    required this.topInset,
    required this.onBack,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0025CC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                tooltip: "Scan for history",
                onPressed: onScan,
                icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "Maintenance history at a glance",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "Track past fixes, resolution rates, and weekly activity across campus equipment.",
              style: TextStyle(
                color: Color(0xFFE0EAFF),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF2FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF0025CC), size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: "Search history...",
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded,
                size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              "No maintenance history yet",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Record a fix from Quick Actions or by scanning QR.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, "/maintenance"),
              icon: const Icon(Icons.build_rounded),
              label: const Text("Record a fix"),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryLineChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color fillColor;

  const _HistoryLineChart({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  State<_HistoryLineChart> createState() => _HistoryLineChartState();
}

class _HistoryLineChartState extends State<_HistoryLineChart> {
  int? _focus;

  void _setFocus(Offset local, double width) {
    if (widget.labels.isEmpty || width <= 0) return;
    final i = chartNearestIndex(local.dx, width, widget.labels.length);
    if (_focus != i) setState(() => _focus = i);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final focusX = _focus == null || widget.labels.length <= 1
                  ? null
                  : constraints.maxWidth *
                      (_focus! / (widget.labels.length - 1));
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
                        painter: _LineChartPainter(
                          values: widget.values,
                          lineColor: widget.lineColor,
                          fillColor: widget.fillColor,
                          gridColor: const Color(0xFFE5E7EB),
                          focusIndex: _focus,
                        ),
                      ),
                    ),
                    if (_focus != null && focusX != null)
                      Positioned(
                        left: (focusX - 60).clamp(
                          0.0,
                          math.max(0.0, constraints.maxWidth - 120),
                        ),
                        top: 8,
                        child: ChartTooltipBubble(
                          title: widget.labels[_focus!],
                          rows: [
                            ChartTooltipRow(
                              color: widget.lineColor,
                              label: "Fixes",
                              value: chartFmtValue(
                                _focus! < widget.values.length
                                    ? widget.values[_focus!]
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
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in widget.labels)
              Expanded(
                child: Text(
                  label.length > 3 ? label.substring(0, 3) : label,
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
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final int? focusIndex;

  _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    this.focusIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxV = values.reduce(math.max);
    final peak = maxV <= 0 ? 1.0 : maxV * 1.25;
    final n = values.length;

    Offset pointAt(int i) {
      final x = n == 1 ? size.width / 2 : size.width * (i / (n - 1));
      final y = size.height - (values[i] / peak) * size.height;
      return Offset(x, y.clamp(4.0, size.height - 4));
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var g = 0; g < 4; g++) {
      final y = size.height * (g / 3);
      _drawDashedLine(
        canvas,
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final path = Path();
    final fill = Path();
    for (var i = 0; i < n; i++) {
      final p = pointAt(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        fill.moveTo(p.dx, size.height);
        fill.lineTo(p.dx, p.dy);
      } else {
        final prev = pointAt(i - 1);
        final cx = (prev.dx + p.dx) / 2;
        path.cubicTo(cx, prev.dy, cx, p.dy, p.dx, p.dy);
        fill.cubicTo(cx, prev.dy, cx, p.dy, p.dx, p.dy);
      }
    }
    final last = pointAt(n - 1);
    fill.lineTo(last.dx, size.height);
    fill.close();

    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (focusIndex != null) {
      final fi = focusIndex!.clamp(0, n - 1);
      final p = pointAt(fi);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * math.min(dist + dash, total);
      canvas.drawLine(start, end, paint);
      dist += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.focusIndex != focusIndex;
  }
}
