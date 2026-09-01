import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/maintenance_report.dart';
import '../../services/purchaser_service.dart';
import 'purchaser_report_detail_screen.dart';

class PurchaserUrgentReportsScreen extends StatefulWidget {
  const PurchaserUrgentReportsScreen({super.key});

  @override
  State<PurchaserUrgentReportsScreen> createState() =>
      _PurchaserUrgentReportsScreenState();
}

class _PurchaserUrgentReportsScreenState
    extends State<PurchaserUrgentReportsScreen>
    with TickerProviderStateMixin {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);

  final PurchaserService _service = PurchaserService();
  late TabController _tabs;
  late final TextEditingController _search;
  late Future<List<MaintenanceReport>> _future;

  bool _archiveMode = false;

  static const _activeFilters = [
    ("Pending", "Pending"),
    ("Processing", "Processing"),
    ("Resolved", "Resolved"),
    ("For Replacement", "For Replacement"),
    ("Rejected", "Rejected"),
  ];

  static const _archiveFilters = [
    ("Resolved", "Resolved"),
    ("For Replacement", "For Replacement"),
    ("Rejected", "Rejected"),
  ];

  List<(String, String)> get _filters =>
      _archiveMode ? _archiveFilters : _activeFilters;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    _search = TextEditingController();
    _reload();
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) _reload();
  }

  void _setArchiveMode(bool archive) {
    if (_archiveMode == archive) return;

    final oldTabs = _tabs;
    oldTabs.removeListener(_onTabChanged);

    final newTabs = TabController(
      length: archive ? _archiveFilters.length : _activeFilters.length,
      vsync: this,
    );
    newTabs.addListener(_onTabChanged);

    setState(() {
      _archiveMode = archive;
      _tabs = newTabs;
    });

    oldTabs.dispose();
    _reload();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.listReports(
        status: _filters[_tabs.index].$1,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        archive: _archiveMode,
      );
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Pending":
        return const Color(0xFFF59E0B);
      case "Processing":
        return const Color(0xFF7C3AED);
      case "Resolved":
        return const Color(0xFF16A34A);
      case "For Replacement":
        return const Color(0xFFEA580C);
      case "Rejected":
        return const Color(0xFFDC2626);
      default:
        return _muted;
    }
  }

  Future<void> _openReport(MaintenanceReport report) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaserReportDetailScreen(reportId: report.id),
      ),
    );
    if (updated == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d, yyyy · h:mm a");

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(
          _archiveMode ? "Archived Urgent" : "Urgent Reports",
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        actions: [
          IconButton(
            onPressed: () => _setArchiveMode(!_archiveMode),
            icon: Icon(
              _archiveMode
                  ? Icons.inventory_2_outlined
                  : Icons.archive_outlined,
            ),
            tooltip: _archiveMode ? "Active reports" : "Archived reports",
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: _ink,
          unselectedLabelColor: _muted,
          indicatorColor: const Color(0xFFDC2626),
          tabs: _filters.map((f) => Tab(text: f.$2)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: "Search ticket, room, equipment…",
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _reload(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MaintenanceReport>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data ?? [];

                if (reports.isEmpty) {
                  return Center(
                    child: Text(
                      _archiveMode
                          ? "No archived ${_filters[_tabs.index].$2.toLowerCase()} reports."
                          : "No ${_filters[_tabs.index].$2.toLowerCase()} urgent reports.",
                      style: const TextStyle(color: _muted),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final report = reports[index];

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openReport(report),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.ticketCode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _ink,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        "Urgent",
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  report.equipmentDisplay,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  report.issueDisplay,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: _muted),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _statusColor(report.status),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      report.status,
                                      style: TextStyle(
                                        color: _statusColor(report.status),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (report.isMultiItem) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        "${report.itemCount} items",
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    if (report.submittedAt != null)
                                      Text(
                                        dateFmt.format(report.submittedAt!),
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                if (report.assignedPurchaserName != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    "Handled by ${report.assignedPurchaserName}",
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ] else if (report.assignedPersonnelName !=
                                    null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    "Maintenance: ${report.assignedPersonnelName}",
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (report.room.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    report.room,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
