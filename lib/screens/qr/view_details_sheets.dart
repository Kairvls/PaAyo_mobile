import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../equipment/equipment_details_screen.dart';
import 'qr_scanner_screen.dart';

/// Read-only previews for list items. Viewing never needs a scan; the
/// "Scan to manage" button is the only path to actions on the unit.
const _ink = Color(0xFF111827);
const _muted = Color(0xFF9CA3AF);
const _blue = Color(0xFF0025CC);
const _accent = Color(0xFFFFF200);
const _line = Color(0xFFEEEEEE);

final _dateFmt = DateFormat("MMM d, yyyy");

Future<void> showScheduleDetailsSheet(
  BuildContext context,
  MaintenanceSchedule schedule,
) {
  Color chipColor() {
    if (schedule.isOverdue) return const Color(0xFFEF4444);
    if (schedule.isDueSoon) return const Color(0xFFD97706);
    if (schedule.status.toLowerCase().contains("complete")) {
      return const Color(0xFF22C55E);
    }
    return _blue;
  }

  final next = schedule.nextDate;
  return _showSheet(
    context,
    icon: Icons.event_rounded,
    eyebrow: "Maintenance schedule",
    title: schedule.title,
    chipLabel: schedule.relativeDueLabel,
    chipColor: chipColor(),
    rows: [
      _Detail("Status", schedule.urgencyLabel),
      _Detail(
        "Next due",
        next == null ? null : _dateFmt.format(next.toLocal()),
      ),
      _Detail(
        "Last done",
        schedule.lastDate == null
            ? null
            : _dateFmt.format(schedule.lastDate!.toLocal()),
      ),
      _Detail("Frequency", schedule.frequency),
      _Detail("Description", schedule.description, stacked: true),
    ],
    equipmentId: schedule.equipmentId,
    equipmentName: schedule.equipmentName,
    equipmentQr: schedule.equipmentQr,
    room: schedule.room,
    destination: ScanDestination.schedule,
  );
}

Future<void> showMaintenanceRecordSheet(
  BuildContext context,
  MaintenanceRecord record, {
  ScanDestination destination = ScanDestination.history,
  String scanLabel = "Scan to manage",
}) {
  Color chipColor() {
    final t = record.status.toLowerCase();
    if (t.contains("resolve") ||
        t.contains("complete") ||
        t.contains("done") ||
        t.contains("fixed")) {
      return const Color(0xFF22C55E);
    }
    if (t.contains("replace") || t.contains("dispose")) {
      return const Color(0xFFEA580C);
    }
    if (t.contains("pending") || t.contains("progress")) {
      return const Color(0xFFD97706);
    }
    return _blue;
  }

  return _showSheet(
    context,
    icon: Icons.build_rounded,
    eyebrow: "Maintenance record",
    title: record.equipmentName ?? "Equipment",
    chipLabel: record.status,
    chipColor: chipColor(),
    rows: [
      _Detail("Date", _dateFmt.format(record.date.toLocal())),
      _Detail("Personnel", record.personnel),
      _Detail("Findings", record.findings, stacked: true),
      _Detail("Repair action", record.repairAction, stacked: true),
      _Detail("Replacement", record.replacementRemarks, stacked: true),
    ],
    equipmentId: record.equipmentId,
    equipmentName: record.equipmentName,
    equipmentQr: record.equipmentQr,
    room: record.room,
    destination: destination,
    scanLabel: scanLabel,
  );
}

class _Detail {
  final String label;
  final String? value;
  final bool stacked;

  const _Detail(this.label, this.value, {this.stacked = false});

  bool get hasValue {
    final v = value?.trim();
    return v != null && v.isNotEmpty && v != "—";
  }
}

Future<void> _showSheet(
  BuildContext context, {
  required IconData icon,
  required String eyebrow,
  required String title,
  required String chipLabel,
  required Color chipColor,
  required List<_Detail> rows,
  required int? equipmentId,
  required String? equipmentName,
  required String? equipmentQr,
  required String? room,
  required ScanDestination destination,
  String scanLabel = "Scan to manage",
}) {
  String? clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty || t == "—") ? null : t;
  }

  final roomLabel = clean(room);
  final qrLabel = clean(equipmentQr);
  final visible = rows.where((r) => r.hasValue).toList();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;

      void openEquipment() {
        Navigator.pop(ctx);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EquipmentDetailsScreen(
              equipment: Equipment(
                id: equipmentId!,
                qrId: qrLabel ?? "—",
                name: clean(equipmentName) ?? "Equipment",
                assetTag: "—",
                brand: "—",
                model: "—",
                serial: "—",
                room: roomLabel ?? "—",
                category: "—",
                condition: "—",
                status: "—",
                warranty: "—",
              ),
            ),
          ),
        );
      }

      void openScanner() {
        Navigator.pop(ctx);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRScannerScreen(
              destination: destination,
              expectedEquipmentId: equipmentId,
              expectedEquipmentName: clean(equipmentName),
              expectedQr: qrLabel,
            ),
          ),
        );
      }

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: _blue, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eyebrow,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              chipLabel,
                              style: TextStyle(
                                color: chipColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _EquipmentTile(
                        name: clean(equipmentName) ?? "Equipment",
                        meta: [?roomLabel, ?qrLabel].join(" · "),
                        onTap: equipmentId == null ? null : openEquipment,
                      ),
                      const SizedBox(height: 6),
                      for (var i = 0; i < visible.length; i++)
                        _DetailRow(
                          detail: visible[i],
                          showDivider: i < visible.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: openScanner,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 18,
                          color: _accent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          scanLabel,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _EquipmentTile extends StatelessWidget {
  final String name;
  final String meta;
  final VoidCallback? onTap;

  const _EquipmentTile({
    required this.name,
    required this.meta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 20, color: _ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const Text(
                  "Details",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _blue),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final _Detail detail;
  final bool showDivider;

  const _DetailRow({required this.detail, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 13.5,
      color: Color(0xFF8A8A8A),
      fontWeight: FontWeight.w500,
    );
    const valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: _ink,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: detail.stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.label, style: labelStyle),
                    const SizedBox(height: 4),
                    Text(detail.value!.trim(), style: valueStyle),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(detail.label, style: labelStyle),
                    ),
                    Expanded(
                      child: Text(
                        detail.value!.trim(),
                        textAlign: TextAlign.right,
                        style: valueStyle,
                      ),
                    ),
                  ],
                ),
        ),
        if (showDivider) const Divider(height: 1, color: _line),
      ],
    );
  }
}
