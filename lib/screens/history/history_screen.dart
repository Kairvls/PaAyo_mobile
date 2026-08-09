import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _accent = Color(0xFF0EA5E9);

  final MaintenanceService _service = MaintenanceService();
  late final TextEditingController _search;
  late Future<List<MaintenanceRecord>> _future;

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

  Color _statusColor(String status) {
    final t = status.toLowerCase();
    if (t.contains("replace")) return const Color(0xFFEA580C);
    if (t.contains("pending")) return const Color(0xFFF59E0B);
    if (t.contains("processing")) return const Color(0xFF7C3AED);
    if (t.contains("resolved")) return const Color(0xFF16A34A);
    return _accent;
  }

  Future<void> _openRecord(MaintenanceRecord record) {
    return promptScanToManage(
      context,
      equipmentName: record.equipmentName,
      destination: ScanDestination.history,
    );
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
        title: const Text(
          "History",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        actions: [
          IconButton(
            tooltip: "Scan for history",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const QRScannerScreen(destination: ScanDestination.history),
              ),
            ).then((_) {
              if (mounted) _reload();
            }),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
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
            child: FutureBuilder<List<MaintenanceRecord>>(
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
                            onPressed: _reload, child: const Text("Retry")),
                      ],
                    ),
                  );
                }

                final all = snap.data ?? [];
                final items = _filter(all);
                final searching = _search.text.trim().isNotEmpty;

                if (all.isEmpty) {
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
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Record a fix from Quick Actions or by scanning QR.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              "/maintenance",
                            ),
                            icon: const Icon(Icons.build_rounded),
                            label: const Text("Record a fix"),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (items.isEmpty && searching) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "No history matches your search.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, height: 1.4),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = items[i];
                      final color = _statusColor(r.status);
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openRecord(r),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.equipmentName ?? "Equipment",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: _ink,
                                        ),
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
                                        r.status,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    if (r.room != null && r.room!.isNotEmpty)
                                      r.room!,
                                    r.personnel,
                                  ].join(" · "),
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                                if (r.findings != null &&
                                    r.findings!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    r.findings!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 13.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  dateFmt.format(r.date.toLocal()),
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
