import 'package:flutter/material.dart';

import '../../models/semester_inspection.dart';
import '../../services/semester_inspection_service.dart';
import '../qr/qr_scanner_screen.dart';
import 'semester_inspect_screen.dart';

class SemesterInspectionDetailScreen extends StatefulWidget {
  final int campaignId;

  const SemesterInspectionDetailScreen({super.key, required this.campaignId});

  @override
  State<SemesterInspectionDetailScreen> createState() =>
      _SemesterInspectionDetailScreenState();
}

class _SemesterInspectionDetailScreenState
    extends State<SemesterInspectionDetailScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF2563EB);

  final SemesterInspectionService _service = SemesterInspectionService();
  final TextEditingController _search = TextEditingController();

  String _filter = "pending";
  String? _room;
  late Future<SemesterCampaignDetail> _future;
  List<String> _conditions = const [
    "OK",
    "Malfunctioning",
    "Defective",
    "Destroyed",
  ];

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
      _future = _service
          .getCampaign(
            widget.campaignId,
            filter: _filter,
            search: _search.text.trim().isEmpty ? null : _search.text.trim(),
            room: _room,
          )
          .then((detail) {
        _conditions = detail.conditions;
        return detail;
      });
    });
  }

  Future<void> _openItem(SemesterInspectionItem item) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SemesterInspectScreen(
          campaignId: widget.campaignId,
          item: item,
          conditions: _conditions,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _scan() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          destination: ScanDestination.semesterInspect,
          campaignId: widget.campaignId,
          conditions: _conditions,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "Campaign checklist",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        actions: [
          IconButton(
            tooltip: "Scan equipment QR",
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scan,
        backgroundColor: _blue,
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text(
          "Scan to inspect",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          FutureBuilder<SemesterCampaignDetail>(
            future: _future,
            builder: (context, snap) {
              final campaign = snap.data?.campaign;
              if (campaign == null) return const SizedBox.shrink();
              final p = campaign.progress;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${campaign.scopeLabel} · ${p.inspected}/${p.total} done",
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: p.total == 0 ? 0 : p.percent / 100,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: _blue,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: "Search equipment, tag, room…",
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: "Pending",
                  selected: _filter == "pending",
                  onTap: () {
                    setState(() => _filter = "pending");
                    _reload();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: "Inspected",
                  selected: _filter == "inspected",
                  onTap: () {
                    setState(() => _filter = "inspected");
                    _reload();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: "All",
                  selected: _filter == "all",
                  onTap: () {
                    setState(() => _filter = "all");
                    _reload();
                  },
                ),
              ],
            ),
          ),
          FutureBuilder<SemesterCampaignDetail>(
            future: _future,
            builder: (context, snap) {
              final rooms = snap.data?.rooms ?? const <String>[];
              if (rooms.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    _FilterChip(
                      label: "All rooms",
                      selected: _room == null,
                      onTap: () {
                        setState(() => _room = null);
                        _reload();
                      },
                    ),
                    const SizedBox(width: 8),
                    ...rooms.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: r,
                          selected: _room == r,
                          onTap: () {
                            setState(() => _room = r);
                            _reload();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<SemesterCampaignDetail>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      snap.error.toString().replaceFirst("Exception: ", ""),
                      style: const TextStyle(color: _muted),
                    ),
                  );
                }

                final items = snap.data?.items ?? [];
                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            "No equipment matches this filter.",
                            style: TextStyle(color: _muted),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openItem(item),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: item.isPending
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.equipmentName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (item.room.isNotEmpty) item.room,
                                          if ((item.assetTag ?? "").isNotEmpty)
                                            item.assetTag!,
                                          item.status,
                                          if (item.condition != null)
                                            item.condition!,
                                        ].join(" · "),
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: _muted,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0F172A) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
