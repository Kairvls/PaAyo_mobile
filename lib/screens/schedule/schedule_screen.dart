import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

class ScheduleScreen extends StatefulWidget {
  /// When embedded as a bottom-nav tab there is nothing to pop back to, so the
  /// AppBar should not render a back arrow.
  final bool embedded;

  const ScheduleScreen({super.key, this.embedded = false});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF5F5F5);

  final MaintenanceService _service = MaintenanceService();
  late final TextEditingController _search;
  late Future<List<MaintenanceSchedule>> _future;

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
      // Mobile only manages QR-tagged equipment; drop schedules whose
      // equipment has no generated QR code.
      _future = _service.listSchedules().then(
            (items) => items.where((s) {
              final q = (s.equipmentQr ?? "").trim();
              return q.isNotEmpty && q != "—";
            }).toList(),
          );
    });
  }

  List<MaintenanceSchedule> _filter(List<MaintenanceSchedule> items) {
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

  Color _statusColor(MaintenanceSchedule schedule) {
    if (schedule.isOverdue) return const Color(0xFFEF4444);
    if (schedule.isDueSoon) return const Color(0xFFF59E0B);
    final s = schedule.status.toLowerCase();
    if (s.contains("completed")) return const Color(0xFF16A34A);
    return const Color(0xFF2563EB);
  }

  Future<void> _open(MaintenanceSchedule schedule) {
    return promptScanToManage(
      context,
      equipmentName: schedule.equipmentName,
      destination: ScanDestination.schedule,
    );
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

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmbeddedHeader(),
              Expanded(child: _buildListBody(embedded: true)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "Schedule",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        actions: [
          IconButton(
            tooltip: "Scan for schedule",
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      body: _buildListBody(embedded: false),
    );
  }

  Widget _buildEmbeddedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color: _ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Schedule",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Upcoming maintenance tasks",
                      style: TextStyle(
                        fontSize: 13,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openScanner,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: _ink,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPillSearch(),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              "Scan each unit’s QR on-site to update its schedule.",
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillSearch() {
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
                hintText: "Search...",
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

  Widget _buildDirectorySearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
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
                  hintText: "Search...",
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
              tooltip: "Filter",
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListBody({required bool embedded}) {
    final dateFmt = DateFormat("MMM d, yyyy");
    final bottomPad = embedded ? 100.0 : 24.0;

    return ColoredBox(
      color: _bg,
      child: Column(
        children: [
          if (!embedded) _buildDirectorySearch(),
          Expanded(
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
                            onPressed: _reload, child: const Text("Retry")),
                      ],
                    ),
                  );
                }

                final items = _filter(snap.data ?? []);
                if (items.isEmpty) {
                  final searching = _search.text.trim().isNotEmpty;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        searching
                            ? "No schedules match your search."
                            : "No schedules yet.\nCreate them in the web admin or per equipment.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, height: 1.4),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = items[i];
                      final color = _statusColor(s);
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _open(s),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF1FF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    s.isDueSoon
                                        ? Icons.schedule_rounded
                                        : Icons.event_rounded,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        [
                                          s.equipmentName ?? "Equipment",
                                          if (s.room != null &&
                                              s.room!.isNotEmpty)
                                            s.room!,
                                        ].join(" · "),
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        s.nextDate != null
                                            ? "Next: ${dateFmt.format(s.nextDate!)} · ${s.frequency}"
                                            : s.frequency,
                                        style: const TextStyle(
                                          color: _ink,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    s.urgencyLabel,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
