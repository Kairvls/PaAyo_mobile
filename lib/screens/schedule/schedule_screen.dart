import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../widgets/product_list_row.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/view_details_sheets.dart';

enum _ScheduleRange { monthly, weekly, today }

const _scheduleBlue = Color(0xFF002784);
const _scheduleAccent = Color(0xFFFFF200);

class ScheduleScreen extends StatefulWidget {
  /// When embedded as a bottom-nav tab there is nothing to pop back to, so the
  /// AppBar should not render a back arrow.
  final bool embedded;

  const ScheduleScreen({super.key, this.embedded = false});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF9CA3AF);
  static const _bg = Color(0xFFFAFAFA);

  final MaintenanceService _service = MaintenanceService();
  final TextEditingController _search = TextEditingController();
  late Future<List<MaintenanceSchedule>> _future;
  _ScheduleRange _range = _ScheduleRange.weekly;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.listSchedules().then(
            (items) => items.where((s) {
              final q = (s.equipmentQr ?? "").trim();
              return q.isNotEmpty && q != "—";
            }).toList(),
          );
    });
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _open(MaintenanceSchedule schedule) {
    return showScheduleDetailsSheet(context, schedule);
  }

  Future<void> _openScanner() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const QRScannerScreen(
          destination: ScanDestination.schedule,
        ),
      ),
    ).then((_) {
      if (mounted) _reload();
    });
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k >= 10 ? "${k.round()}K" : "${k.toStringAsFixed(1)}K";
    }
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  List<MaintenanceSchedule> _listItems(List<MaintenanceSchedule> all) {
    final sorted = [...all]..sort((a, b) {
        final ad = a.nextDate ?? DateTime(2100);
        final bd = b.nextDate ?? DateTime(2100);
        return ad.compareTo(bd);
      });

    DateTime start;
    DateTime end;
    switch (_range) {
      case _ScheduleRange.today:
        start = _today;
        end = _today;
      case _ScheduleRange.weekly:
        start = _today.subtract(const Duration(days: 3));
        end = _today.add(const Duration(days: 7));
      case _ScheduleRange.monthly:
        start = DateTime(_today.year, _today.month - 1, _today.day);
        end = _today.add(const Duration(days: 30));
    }

    final filtered = sorted.where((s) {
      if (s.nextDate == null) return _range == _ScheduleRange.monthly;
      final d = DateTime(s.nextDate!.year, s.nextDate!.month, s.nextDate!.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    return _filterSearch(filtered);
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
                hintText: "Search schedules...",
                hintStyle: TextStyle(
                  color: _muted,
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

  /// Tiny sparkline — 5 points matching the card mock shapes.
  List<double> _sparkline(MaintenanceSchedule s) {
    // Up: baseline → slight up → sharp up → small dip → moderate up.
    const up = [0.0, 0.35, 1.0, 0.72, 0.92];
    // Down: baseline → slight down → sharp down → recovery → small dip.
    const down = [1.0, 0.78, 0.08, 0.48, 0.28];

    if (s.isOverdue) return List<double>.from(down);

    // Slight variation so rows don't all look identical.
    final shift = (s.id.abs() % 3) * 0.04;
    if (s.isDueSoon) {
      return [0.15, 0.25 + shift, 0.55, 0.4, 0.7 + shift];
    }
    return [
      up[0],
      (up[1] + shift).clamp(0.0, 1.0),
      up[2],
      (up[3] - shift * 0.5).clamp(0.0, 1.0),
      up[4],
    ];
  }

  int _daysDelta(MaintenanceSchedule s) {
    if (s.nextDate == null) return 0;
    final due = DateTime(s.nextDate!.year, s.nextDate!.month, s.nextDate!.day);
    return due.difference(_today).inDays;
  }

  String _changeLabel(MaintenanceSchedule s) {
    final days = _daysDelta(s);
    if (s.isOverdue) {
      final past = -days;
      return "Past -$past d";
    }
    if (days == 0) return "Due +0%";
    if (days > 0) return "Left +$days d";
    return "Due ${days}d";
  }

  bool _isPositiveChange(MaintenanceSchedule s) => !s.isOverdue;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<List<MaintenanceSchedule>>(
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
                      const Text("Couldn't load schedules."),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _reload,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                );
              }

              final dateFmt = DateFormat("MMM d, yyyy");
              final all = snap.data ?? [];
              final items = _listItems(all);
              final total = items.length;
              final attention =
                  items.where((s) => s.isOverdue || s.isDueSoon).length;
              final dated = items.where((s) => s.nextDate != null).toList();
              final avg = dated.isEmpty
                  ? 0
                  : (dated.map(_daysDelta).fold<int>(0, (a, b) => a + b.abs()) /
                          dated.length)
                      .round();
              final bottomPad = widget.embedded ? 100.0 : 28.0;

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                        child: Row(
                          children: [
                            if (!widget.embedded)
                              IconButton(
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: _ink,
                                ),
                              ),
                            const Expanded(
                              child: Text(
                                "Schedule",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: "Scan for schedule",
                              onPressed: _openScanner,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: _buildSearchField(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    "Overview",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                _RangeToggle(
                                  value: _range,
                                  onChanged: (v) =>
                                      setState(() => _range = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _KpiCard(
                                    icon: Icons.event_note_rounded,
                                    value: _formatCount(total),
                                    label: "Total Schedules",
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _KpiCard(
                                    icon: Icons.priority_high_rounded,
                                    value: attention > 0
                                        ? _formatCount(attention)
                                        : _formatCount(avg),
                                    label: attention > 0
                                        ? "Need Attention"
                                        : "Avg. Days",
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                        child: Text(
                          switch (_range) {
                            _ScheduleRange.today => "Due today",
                            _ScheduleRange.weekly => "This week",
                            _ScheduleRange.monthly => "This month",
                          },
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                    if (items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _search.text.trim().isNotEmpty
                                  ? "No schedules match your search."
                                  : "No schedules in this range.\nTry Weekly / Monthly, or create one per equipment.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _muted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final s = items[i];
                              return _TrendingScheduleRow(
                                schedule: s,
                                dateFmt: dateFmt,
                                sparkline: _sparkline(s),
                                volume: s.nextDate != null
                                    ? (_daysDelta(s).abs() == 0
                                        ? 1
                                        : _daysDelta(s).abs())
                                    : 0,
                                changeLabel: _changeLabel(s),
                                positive: _isPositiveChange(s),
                                onTap: () => _open(s),
                              );
                            },
                            childCount: items.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final _ScheduleRange value;
  final ValueChanged<_ScheduleRange> onChanged;

  const _RangeToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _ScheduleRange range) {
      final selected = value == range;
      return GestureDetector(
        onTap: () => onChanged(range),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? _scheduleBlue : Colors.transparent,
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
          chip("Monthly", _ScheduleRange.monthly),
          chip("Weekly", _ScheduleRange.weekly),
          chip("Today", _ScheduleRange.today),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF6B7280), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _scheduleBlue,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingScheduleRow extends StatelessWidget {
  final MaintenanceSchedule schedule;
  final DateFormat dateFmt;
  final List<double> sparkline;
  final int volume;
  final String changeLabel;
  final bool positive;
  final VoidCallback onTap;

  const _TrendingScheduleRow({
    required this.schedule,
    required this.dateFmt,
    required this.sparkline,
    required this.volume,
    required this.changeLabel,
    required this.positive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = ProductListRow.joinMeta([
      schedule.equipmentName ?? "Equipment",
      if (schedule.room != null && schedule.room!.isNotEmpty) schedule.room,
      if (schedule.nextDate != null)
        "Next: ${dateFmt.format(schedule.nextDate!)}",
      if (schedule.frequency.trim().isNotEmpty && schedule.frequency != "—")
        schedule.frequency,
      schedule.urgencyLabel,
    ]);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: Icon(
                    schedule.isOverdue
                        ? Icons.warning_amber_rounded
                        : schedule.isDueSoon
                            ? Icons.schedule_rounded
                            : Icons.event_rounded,
                    color: _scheduleBlue,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9CA3AF),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                height: 26,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    values: sparkline,
                    color: positive ? _scheduleBlue : _scheduleAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "$volume",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      changeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    // Leave a little vertical padding so sharp peaks don't clip.
    const pad = 2.0;
    final usableH = size.height - pad * 2;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = pad + usableH - ((values[i] - minV) / span) * usableH;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.miter
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
