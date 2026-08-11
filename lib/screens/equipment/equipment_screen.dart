import 'package:flutter/material.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../utils/equipment_icon.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

class EquipmentScreen extends StatefulWidget {
  final String? initialSearch;
  final bool attentionOnly;

  /// When embedded as a bottom-nav tab there is nothing to pop back to, so the
  /// AppBar should not render a back arrow.
  final bool embedded;

  const EquipmentScreen({
    super.key,
    this.initialSearch,
    this.attentionOnly = false,
    this.embedded = false,
  });

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _pageBg = Color(0xFFF5F5F5);

  final MaintenanceService _service = MaintenanceService();
  late final TextEditingController _search;

  late Future<List<Equipment>> _future;

  bool get _attentionOnly => widget.attentionOnly;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSearch?.trim() ?? "";
    _search = TextEditingController(text: initial);
    _reload(initial.isEmpty ? null : initial);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _needsAttention(Equipment e) {
    final s = e.status.toLowerCase();
    return s.contains("maintenance") || s.contains("replace");
  }

  /// Mobile only manages QR-tagged equipment; drop anything without a QR code.
  bool _hasQr(Equipment e) {
    final q = e.qrId.trim();
    return q.isNotEmpty && q != "—";
  }

  void _reload([String? search]) {
    setState(() {
      _future = _service.listEquipment(search: search).then((items) {
        final qrOnly = items.where(_hasQr).toList();
        if (!_attentionOnly) return qrOnly;
        return qrOnly.where(_needsAttention).toList();
      });
    });
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains("dispose")) return const Color(0xFFEF4444);
    if (s.contains("replace")) return const Color(0xFFEA580C);
    if (s.contains("maintenance")) return const Color(0xFFF59E0B);
    if (s.contains("borrow")) return const Color(0xFF0EA5E9);
    return const Color(0xFF16A34A);
  }

  Future<void> _open(Equipment equipment) async {
    // Directory only — full manage requires an on-site QR scan.
    await promptScanToManage(
      context,
      equipmentName: equipment.name,
      destination: ScanDestination.profile,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmbeddedHeader(),
              Expanded(child: _buildListBody()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(
          _attentionOnly ? "Needs Attention" : "Equipment directory",
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        actions: [
          IconButton(
            tooltip: "Scan QR",
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                _attentionOnly
                    ? "Equipment under maintenance or for replacement. Scan its QR on-site to manage it."
                    : "This list helps you find a unit. Scan its QR on-site to open details, schedule, and history.",
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _buildDirectorySearch(fill: Colors.white),
          ),
          Expanded(child: _buildListBody()),
        ],
      ),
    );
  }

  Future<void> _openScanner() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const QRScannerScreen(destination: ScanDestination.profile),
      ),
    ).then((_) {
      if (mounted) _reload(_search.text);
    });
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
                  Icons.inventory_2_rounded,
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
                      "Equipment",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Find a unit, then scan on-site",
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
              "Only QR-tagged equipment appears here. Scan on-site to manage it.",
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
              onSubmitted: _reload,
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
            onPressed: () => _reload(_search.text),
            icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorySearch({required Color fill}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: fill == Colors.white
              ? const Color(0xFFE5E7EB)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _ink, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _reload,
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
            onPressed: () => _reload(_search.text),
            icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildListBody() {
    return ColoredBox(
      color: _pageBg,
      child: FutureBuilder<List<Equipment>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _EmptyState(
              icon: Icons.wifi_off_rounded,
              title: "Couldn't load equipment",
              subtitle: "Check your connection and try again.",
              actionLabel: "Retry",
              onAction: () => _reload(_search.text),
            );
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            final searching = _search.text.trim().isNotEmpty;
            if (_attentionOnly) {
              return _EmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: "No equipment needs attention",
                subtitle:
                    "Nothing is under maintenance or for replacement right now.",
                actionLabel: "Scan QR",
                onAction: () => Navigator.pushNamed(context, "/scanner"),
              );
            }
            if (searching) {
              return _EmptyState(
                icon: Icons.search_off_rounded,
                title: "No matches found",
                subtitle:
                    "No QR-tagged equipment matches your search. Try another keyword or scan a QR code.",
                actionLabel: "Scan QR",
                onAction: () => Navigator.pushNamed(context, "/scanner"),
              );
            }
            return _EmptyState(
              icon: Icons.qr_code_2_rounded,
              title: "No QR-tagged equipment yet",
              subtitle:
                  "Generate QR codes on the web to enroll equipment for maintenance monitoring. Only QR-tagged items appear here.",
              actionLabel: "Scan QR",
              onAction: () => Navigator.pushNamed(context, "/scanner"),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(_search.text),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                widget.embedded ? 100 : 24,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = items[i];
                final color = _statusColor(e.status);
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _open(e),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                            padding: const EdgeInsets.all(8),
                            child: EquipmentGraphic(
                              name: e.name,
                              category: e.category,
                              size: 30,
                              fallbackColor: const Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (e.room != "—") e.room,
                                    if (e.assetTag != "—") e.assetTag,
                                  ].join(" · "),
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12.5,
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
                              e.status,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
