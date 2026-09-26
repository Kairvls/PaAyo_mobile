import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/semester_inspection.dart';
import '../../services/semester_inspection_service.dart';
import 'semester_inspection_detail_screen.dart';

class SemesterInspectionsScreen extends StatefulWidget {
  const SemesterInspectionsScreen({super.key});

  @override
  State<SemesterInspectionsScreen> createState() =>
      _SemesterInspectionsScreenState();
}

class _SemesterInspectionsScreenState extends State<SemesterInspectionsScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF9CA3AF);
  static const _bg = Colors.white;
  static const _blue = Color(0xFF0025CC);
  static const _border = Color(0xFFE5E7EB);

  final SemesterInspectionService _service = SemesterInspectionService();
  final TextEditingController _search = TextEditingController();
  late Future<List<SemesterCampaign>> _future;

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
      _future = _service.listCampaigns();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case "In Progress":
        return _blue;
      case "Active":
        return const Color(0xFF16A34A);
      case "Completed":
        return _muted;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  List<SemesterCampaign> _filter(List<SemesterCampaign> all) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) {
      final hay = [
        c.title,
        c.semester,
        c.academicYear ?? "",
        c.scopeLabel,
        c.status,
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
        border: Border.all(color: _border),
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
              style: const TextStyle(
                color: _ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: "Search campaigns...",
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

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d, yyyy");

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          foregroundColor: _ink,
          title: const Text(
            "Semester Check",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 20,
            ),
          ),
        ),
        body: FutureBuilder<List<SemesterCampaign>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snap.error
                            .toString()
                            .replaceFirst("Exception: ", ""),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _reload,
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                        ),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }

            final campaigns = _filter(snap.data ?? []);
            final total = snap.data?.length ?? 0;
            final open = (snap.data ?? []).where((c) => c.isOpen).length;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: _buildSearchField(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              icon: Icons.assignment_outlined,
                              value: "$total",
                              label: "Campaigns",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _KpiCard(
                              icon: Icons.play_circle_outline_rounded,
                              value: "$open",
                              label: "Open now",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                        child: Text(
                          campaigns.isEmpty && _search.text.trim().isNotEmpty
                              ? "No matches"
                              : "Campaigns",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                    if (campaigns.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _search.text.trim().isNotEmpty
                                  ? "No campaigns match your search."
                                  : "No active semester inspection campaigns.",
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
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final c = campaigns[index];
                              final p = c.progress;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      index < campaigns.length - 1 ? 12 : 0,
                                ),
                                child: Material(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: _border),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SemesterInspectionDetailScreen(
                                            campaignId: c.id,
                                          ),
                                        ),
                                      );
                                      if (mounted) _reload();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  c.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                    color: _ink,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _statusColor(c.status)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  c.status,
                                                  style: TextStyle(
                                                    color:
                                                        _statusColor(c.status),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            [
                                              if (c.semester.isNotEmpty)
                                                c.semester,
                                              if ((c.academicYear ?? "")
                                                  .isNotEmpty)
                                                c.academicYear!,
                                              c.scopeLabel,
                                            ].join(" · "),
                                            style: const TextStyle(
                                              color: _muted,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (c.dueDate != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              "Due ${dateFmt.format(c.dueDate!)}",
                                              style: const TextStyle(
                                                color: _muted,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: p.total == 0
                                                  ? 0
                                                  : p.percent / 100,
                                              minHeight: 7,
                                              backgroundColor:
                                                  const Color(0xFFE8EAED),
                                              color: _blue,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "${p.inspected}/${p.total} inspected · ${p.pending} pending",
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
                                ),
                              );
                            },
                            childCount: campaigns.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0025CC)),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
