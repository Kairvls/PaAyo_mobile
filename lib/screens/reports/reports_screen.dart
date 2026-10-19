import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/maintenance_report.dart';
import '../../services/maintenance_service.dart';
import '../../utils/input_limits.dart';
import '../../utils/report_status.dart';
import 'report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);

  final MaintenanceService _service = MaintenanceService();
  late TabController _tabs;
  late final TextEditingController _search;
  late Future<List<MaintenanceReport>> _future;

  bool _archiveMode = false;

  /// null = all priorities; otherwise Critical / High / Medium / Low
  String? _priorityFilter;

  List<String> get _filters =>
      _archiveMode ? ReportStatuses.archive : ReportStatuses.active;

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
      length: archive
          ? ReportStatuses.archive.length
          : ReportStatuses.active.length,
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

  void _setPriorityFilter(String? priority) {
    if (_priorityFilter == priority) return;
    setState(() => _priorityFilter = priority);
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.listReports(
        status: _filters[_tabs.index],
        priority: _priorityFilter,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        archive: _archiveMode,
      );
    });
  }

  Future<void> _openReport(MaintenanceReport report) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(reportId: report.id),
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
          _archiveMode ? "Archived Reports" : "Reports",
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
          indicatorColor: const Color(0xFF2563EB),
          tabs: _filters.map((status) => Tab(text: status)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              maxLength: InputLimits.search,
              inputFormatters: [
                LengthLimitingTextInputFormatter(InputLimits.search),
              ],
              buildCounter: (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) =>
                  null,
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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                _PriorityChip(
                  label: "All Priorities",
                  selected: _priorityFilter == null,
                  onTap: () => _setPriorityFilter(null),
                ),
                const SizedBox(width: 8),
                ...ReportPriorities.all.map((level) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PriorityChip(
                      label: level,
                      selected: _priorityFilter == level,
                      accent: ReportPriorities.color(level),
                      onTap: () => _setPriorityFilter(level),
                    ),
                  );
                }),
              ],
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
                  final statusLabel = _filters[_tabs.index].toLowerCase();
                  final priorityLabel = _priorityFilter == null
                      ? ""
                      : "${_priorityFilter!.toLowerCase()} ";
                  return Center(
                    child: Text(
                      _archiveMode
                          ? "No archived $priorityLabel$statusLabel reports."
                          : "No $priorityLabel$statusLabel reports.",
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
                      final priorityColor =
                          ReportPriorities.color(report.priority);

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
                                        color: ReportPriorities.softBackground(
                                          report.priority,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        report.priority,
                                        style: TextStyle(
                                          color: priorityColor,
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
                                        color: ReportStatuses.color(
                                          report.status,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      report.status,
                                      style: TextStyle(
                                        color: ReportStatuses.color(
                                          report.status,
                                        ),
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

class _PriorityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? const Color(0xFF0F172A);
    return Material(
      color: selected
          ? color.withValues(alpha: accent == null ? 1 : 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? (accent ?? const Color(0xFF0F172A))
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? (accent == null ? Colors.white : color)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
