import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../utils/equipment_icon.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

enum _FixPeriod { thisWeek, lastWeek, all }

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  static const _ink = Color(0xFF1A1C1E);
  static const _muted = Color(0xFF9AA0A6);
  static const _blue = Color(0xFF3B82F6);
  static const _page = Colors.white;
  static const _divider = Color(0xFFE8EAED);

  final MaintenanceService _service = MaintenanceService();
  final TextEditingController _search = TextEditingController();
  late Future<List<MaintenanceRecord>> _future;
  _FixPeriod _period = _FixPeriod.thisWeek;

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
      _future = _service.listHistory(limit: 80);
    });
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Monday of the current week (local).
  DateTime get _thisWeekStart {
    final d = _today;
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  DateTime get _lastWeekStart =>
      _thisWeekStart.subtract(const Duration(days: 7));

  bool _inRange(DateTime date, DateTime start, DateTime endExclusive) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && d.isBefore(endExclusive);
  }

  List<MaintenanceRecord> _periodItems(List<MaintenanceRecord> all) {
    List<MaintenanceRecord> ranged;
    switch (_period) {
      case _FixPeriod.thisWeek:
        ranged = all
            .where((r) => _inRange(
                  r.date.toLocal(),
                  _thisWeekStart,
                  _thisWeekStart.add(const Duration(days: 7)),
                ))
            .toList();
      case _FixPeriod.lastWeek:
        ranged = all
            .where((r) => _inRange(
                  r.date.toLocal(),
                  _lastWeekStart,
                  _thisWeekStart,
                ))
            .toList();
      case _FixPeriod.all:
        ranged = all;
    }
    return _filterSearch(ranged);
  }

  List<MaintenanceRecord> _filterSearch(List<MaintenanceRecord> items) {
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
                hintText: "Search fixes...",
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

  bool _isResolved(MaintenanceRecord r) {
    final t = r.status.toLowerCase();
    return t.contains("resolve") ||
        t.contains("complete") ||
        t.contains("done") ||
        t.contains("fixed");
  }

  /// Share of resolved fixes in the selected period (0–1).
  double _completionRate(List<MaintenanceRecord> items) {
    if (items.isEmpty) return 0;
    final resolved = items.where(_isResolved).length;
    return resolved / items.length;
  }

  String get _periodLabel {
    switch (_period) {
      case _FixPeriod.thisWeek:
        return "This Week";
      case _FixPeriod.lastWeek:
        return "Last Week";
      case _FixPeriod.all:
        return "All Time";
    }
  }

  Future<void> _scanToRecord() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const QRScannerScreen(destination: ScanDestination.record),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _openRecord(MaintenanceRecord record) {
    return promptScanToManage(
      context,
      equipmentName: record.equipmentName,
      destination: ScanDestination.record,
    );
  }

  Future<void> _pickPeriod() async {
    final chosen = await showModalBottomSheet<_FixPeriod>(
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
              const SizedBox(height: 8),
              for (final p in _FixPeriod.values)
                ListTile(
                  title: Text(
                    switch (p) {
                      _FixPeriod.thisWeek => "This Week",
                      _FixPeriod.lastWeek => "Last Week",
                      _FixPeriod.all => "All Time",
                    },
                    style: TextStyle(
                      fontWeight: _period == p
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                  trailing: _period == p
                      ? const Icon(Icons.check_rounded, color: _blue)
                      : null,
                  onTap: () => Navigator.pop(context, p),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen != null && mounted) setState(() => _period = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d");

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _page,
        appBar: AppBar(
          backgroundColor: _page,
          elevation: 0,
          foregroundColor: _ink,
          title: const Text(
            "Record Fix",
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          actions: [
            IconButton(
              tooltip: "New fix",
              onPressed: _scanToRecord,
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
          ],
        ),
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
                    const Text("Couldn't load recent fixes."),
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
            final items = _periodItems(all);
            final rate = _completionRate(items);
            final percent = (rate * 100).round();

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: _buildSearchField(),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildGaugeSection(percent)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(height: 1, color: _divider),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildReportHeader()),
                  if (all.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyFixes(),
                    )
                  else if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _search.text.trim().isNotEmpty
                                ? "No fixes match your search."
                                : "No fixes in $_periodLabel.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _buildTableHeader()),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final r = items[i];
                          return _FixReportRow(
                            index: i + 1,
                            record: r,
                            dateLabel: dateFmt.format(r.date.toLocal()),
                            showDivider: i < items.length - 1,
                            onTap: () => _openRecord(r),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGaugeSection(int percent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Fix Progress",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: "Filter period",
                onPressed: _pickPeriod,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 260,
              height: 150,
              child: CustomPaint(
                painter: _SemiGaugePainter(
                  progress: (percent / 100).clamp(0.0, 1.0),
                  activeColor: _blue,
                  trackColor: const Color(0xFFE8EEF9),
                  needleColor: _ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  color: _muted,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "You completed "),
                  TextSpan(
                    text: "$percent%",
                    style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: _period == _FixPeriod.all
                        ? " of recorded fixes as resolved"
                        : " of your fixes ${_periodLabel.toLowerCase()} as resolved",
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Fix Report",
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
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _pickPeriod,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _periodLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 4),
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
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              "No",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              "Equipment",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Status",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Date",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixReportRow extends StatelessWidget {
  final int index;
  final MaintenanceRecord record;
  final String dateLabel;
  final bool showDivider;
  final VoidCallback onTap;

  const _FixReportRow({
    required this.index,
    required this.record,
    required this.dateLabel,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = record.equipmentName ?? "Equipment";
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      "$index",
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        ProductListThumb(
                          child: EquipmentGraphic(
                            name: name,
                            size: 28,
                            fallbackColor: const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1C1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      record.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1C1E),
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
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE8EAED)),
          ),
      ],
    );
  }
}

/// Small square thumbnail matching the Sales Report product image slot.
class ProductListThumb extends StatelessWidget {
  final Widget child;

  const ProductListThumb({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _EmptyFixes extends StatelessWidget {
  const _EmptyFixes();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined,
                size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              "No fixes recorded yet",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF1A1C1E),
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Scan an equipment QR to log your first repair.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9AA0A6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Semi-circular progress gauge with a needle, matching the Target Orders look.
class _SemiGaugePainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;
  final Color needleColor;

  _SemiGaugePainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.needleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.width * 0.42;
    const start = math.pi;
    const sweep = math.pi;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      trackPaint,
    );

    final p = progress.clamp(0.0, 1.0);
    if (p > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * p,
        false,
        activePaint,
      );
    }

    // Inner decorative ring
    final innerPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.55),
      start,
      sweep,
      false,
      innerPaint,
    );

    // Needle
    final angle = start + sweep * p;
    final needleLen = radius * 0.78;
    final tip = Offset(
      center.dx + needleLen * math.cos(angle),
      center.dy + needleLen * math.sin(angle),
    );
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needlePaint);

    // Hub
    canvas.drawCircle(center, 7, Paint()..color = needleColor);
    canvas.drawCircle(center, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SemiGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor;
  }
}
