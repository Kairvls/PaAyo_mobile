import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _accent = Color(0xFFEA580C);

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
      _future = _service.listHistory(limit: 40);
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

  Color _statusColor(String status) {
    final t = status.toLowerCase();
    if (t.contains("replace")) return const Color(0xFFEA580C);
    if (t.contains("pending")) return const Color(0xFFF59E0B);
    if (t.contains("processing")) return const Color(0xFF7C3AED);
    if (t.contains("resolved")) return const Color(0xFF16A34A);
    return _accent;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d · h:mm a");

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "Record Fix",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanToRecord,
        backgroundColor: _accent,
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text(
          "New fix",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "Recent fixes appear below. Tap New fix and scan a QR to log another repair.",
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              "Recent fixes",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink,
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
                final items = _filter(all);
                final searching = _search.text.trim().isNotEmpty;

                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.build_circle_outlined,
                              size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text(
                            "No fixes recorded yet",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Scan an equipment QR to log your first repair.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _scanToRecord,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                            ),
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text("Scan to record"),
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
                        "No fixes match your search.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, height: 1.4),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
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
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.build_rounded,
                                    color: _accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.equipmentName ?? "Equipment",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        r.findings?.isNotEmpty == true
                                            ? r.findings!
                                            : r.status,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
