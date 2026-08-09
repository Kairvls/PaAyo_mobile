import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

enum ScheduleAlertFilter { all, dueSoon, overdue }

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
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);

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
      // Mobile scope: only QR-tagged equipment schedules.
      _future = _service.listSchedules(limit: 100).then(
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

  Future<void> _open(MaintenanceSchedule schedule) {
    return promptScanToManage(
      context,
      equipmentName: schedule.equipmentName,
      destination: ScanDestination.schedule,
    );
  }

  String get _title {
    switch (widget.filter) {
      case ScheduleAlertFilter.dueSoon:
        return "Due Soon";
      case ScheduleAlertFilter.overdue:
        return "Overdue";
      case ScheduleAlertFilter.all:
        return "Schedule Alerts";
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d, yyyy");
    final filter = widget.filter;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Container(
              height: 52,
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: _muted, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: "Search...",
                        hintStyle: TextStyle(color: _muted, fontSize: 14.5),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: const Color(0xFFCBD5E1),
                  ),
                  IconButton(
                    tooltip: "Filter",
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.tune_rounded, color: _muted, size: 22),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
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
                        const Text("Couldn't load alerts."),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _reload, child: const Text("Retry")),
                      ],
                    ),
                  );
                }

                final all = _filter(snap.data ?? []);
                final overdue = all.where((s) => s.isOverdue).toList();
                final dueSoon =
                    all.where((s) => s.isDueSoon && !s.isOverdue).toList();

                final showOverdue = filter != ScheduleAlertFilter.dueSoon;
                final showDueSoon = filter != ScheduleAlertFilter.overdue;
                final visibleOverdue =
                    showOverdue ? overdue : <MaintenanceSchedule>[];
                final visibleDueSoon =
                    showDueSoon ? dueSoon : <MaintenanceSchedule>[];
                final searching = _search.text.trim().isNotEmpty;

                if (visibleOverdue.isEmpty && visibleDueSoon.isEmpty) {
                  final emptyTitle = searching
                      ? "No matches found"
                      : filter == ScheduleAlertFilter.dueSoon
                          ? "No due-soon schedules"
                          : filter == ScheduleAlertFilter.overdue
                              ? "No overdue schedules"
                              : "No schedule alerts";
                  final emptySubtitle = searching
                      ? "No alerts match your search."
                      : filter == ScheduleAlertFilter.dueSoon
                          ? "Nothing is due within ${MaintenanceSchedule.dueSoonDays} days."
                          : filter == ScheduleAlertFilter.overdue
                              ? "No equipment schedules are past due."
                              : "Overdue and due-soon equipment will show up here.";

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            searching
                                ? Icons.search_off_rounded
                                : Icons.notifications_none_rounded,
                            size: 48,
                            color: const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            emptyTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            emptySubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      if (visibleOverdue.isNotEmpty) ...[
                        _sectionLabel(
                          "Overdue",
                          visibleOverdue.length,
                          const Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 10),
                        for (final s in visibleOverdue)
                          _AlertCard(
                            schedule: s,
                            color: const Color(0xFFEF4444),
                            dateFmt: dateFmt,
                            onTap: () => _open(s),
                          ),
                        if (visibleDueSoon.isNotEmpty)
                          const SizedBox(height: 16),
                      ],
                      if (visibleDueSoon.isNotEmpty) ...[
                        _sectionLabel(
                          "Due within ${MaintenanceSchedule.dueSoonDays} days",
                          visibleDueSoon.length,
                          const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 10),
                        for (final s in visibleDueSoon)
                          _AlertCard(
                            schedule: s,
                            color: const Color(0xFFF59E0B),
                            dateFmt: dateFmt,
                            onTap: () => _open(s),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, int count, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final MaintenanceSchedule schedule;
  final Color color;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _AlertCard({
    required this.schedule,
    required this.color,
    required this.dateFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    schedule.isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.schedule_rounded,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.equipmentName ?? "Equipment",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        schedule.title,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schedule.nextDate != null
                            ? "Next: ${dateFmt.format(schedule.nextDate!)}"
                            : schedule.urgencyLabel,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    schedule.urgencyLabel,
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
      ),
    );
  }
}
