import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';

class EquipmentHistoryScreen extends StatefulWidget {
  final Equipment equipment;

  const EquipmentHistoryScreen({super.key, required this.equipment});

  @override
  State<EquipmentHistoryScreen> createState() =>
      _EquipmentHistoryScreenState();
}

class _EquipmentHistoryScreenState extends State<EquipmentHistoryScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);

  final MaintenanceService _service = MaintenanceService();
  late Future<List<MaintenanceRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getHistory(widget.equipment.id);
  }

  Color _statusColor(String status) {
    final t = status.toLowerCase();
    if (t.contains("replace")) return const Color(0xFFEA580C);
    if (t.contains("pending")) return const Color(0xFFF59E0B);
    if (t.contains("processing")) return const Color(0xFF7C3AED);
    if (t.contains("resolved")) return const Color(0xFF16A34A);
    return const Color(0xFF0EA5E9);
  }

  String _relativeLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return "Today";
    }
    return DateFormat("MMMM yyyy").format(date);
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
          "Maintenance History",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ),
      body: FutureBuilder<List<MaintenanceRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                widget.equipment.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(
                "QR ID · ${widget.equipment.qrId}",
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
              const SizedBox(height: 20),
              if (records.isEmpty)
                _buildEmpty()
              else
                for (int i = 0; i < records.length; i++)
                  _TimelineTile(
                    record: records[i],
                    color: _statusColor(records[i].status),
                    periodLabel: _relativeLabel(records[i].date),
                    isFirst: i == 0,
                    isLast: i == records.length - 1,
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: const [
          Icon(Icons.history_toggle_off_rounded, size: 40, color: _muted),
          SizedBox(height: 12),
          Text(
            "No maintenance records yet",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _ink,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Records you save will appear here as a timeline.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final MaintenanceRecord record;
  final Color color;
  final String periodLabel;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({
    required this.record,
    required this.color,
    required this.periodLabel,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst ? Colors.transparent : const Color(0xFFCBD5E1),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        isLast ? Colors.transparent : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    periodLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.status,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Text(
                              DateFormat("MMM d, yyyy").format(record.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 15, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 5),
                            Text(
                              record.personnel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (record.findings != null) ...[
                          const SizedBox(height: 10),
                          _NoteLine(label: "Findings", value: record.findings!),
                        ],
                        if (record.repairAction != null) ...[
                          const SizedBox(height: 6),
                          _NoteLine(
                            label: "Repair",
                            value: record.repairAction!,
                          ),
                        ],
                        if (record.replacementRemarks != null) ...[
                          const SizedBox(height: 6),
                          _NoteLine(
                            label: "Replacement",
                            value: record.replacementRemarks!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  final String label;
  final String value;

  const _NoteLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Color(0xFF475569),
        ),
        children: [
          TextSpan(
            text: "$label: ",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
