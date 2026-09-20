import 'package:flutter/material.dart';
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
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF2563EB);

  final SemesterInspectionService _service = SemesterInspectionService();
  late Future<List<SemesterCampaign>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.listCampaigns();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case "In Progress":
        return const Color(0xFF2563EB);
      case "Active":
        return const Color(0xFF16A34A);
      case "Completed":
        return _muted;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d, yyyy");

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "Semester Checks",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
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
                      snap.error.toString().replaceFirst("Exception: ", ""),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _reload, child: const Text("Retry")),
                  ],
                ),
              ),
            );
          }

          final campaigns = snap.data ?? [];
          if (campaigns.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      "No active semester inspection campaigns.",
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: campaigns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final c = campaigns[index];
                final p = c.progress;
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SemesterInspectionDetailScreen(campaignId: c.id),
                        ),
                      );
                      if (mounted) _reload();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(c.status)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  c.status,
                                  style: TextStyle(
                                    color: _statusColor(c.status),
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
                              if (c.semester.isNotEmpty) c.semester,
                              if ((c.academicYear ?? "").isNotEmpty)
                                c.academicYear!,
                              c.scopeLabel,
                            ].join(" · "),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
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
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: p.total == 0 ? 0 : p.percent / 100,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFE2E8F0),
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
