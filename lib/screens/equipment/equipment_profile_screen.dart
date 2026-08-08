import 'package:flutter/material.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../history/equipment_history_screen.dart';
import '../maintenance/record_maintenance_screen.dart';
import '../schedule/equipment_schedule_screen.dart';
import 'edit_equipment_screen.dart';

class EquipmentProfileScreen extends StatefulWidget {
  final Equipment equipment;

  const EquipmentProfileScreen({super.key, required this.equipment});

  @override
  State<EquipmentProfileScreen> createState() => _EquipmentProfileScreenState();
}

class _EquipmentProfileScreenState extends State<EquipmentProfileScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF2563EB);

  final MaintenanceService _service = MaintenanceService();
  late Equipment _equipment = widget.equipment;

  Color get _statusColor {
    final s = _equipment.status.toLowerCase();
    if (s.contains("dispose")) return const Color(0xFFEF4444);
    if (s.contains("replace")) return const Color(0xFFEA580C);
    if (s.contains("maintenance")) return const Color(0xFFF59E0B);
    if (s.contains("borrow")) return const Color(0xFF0EA5E9);
    return const Color(0xFF16A34A); // Active / operational
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _service.getEquipmentByQr(_equipment.qrId);
      if (mounted) setState(() => _equipment = fresh);
    } catch (_) {
      // Keep showing current data if the refresh fails.
    }
  }

  Future<void> _openRecordMaintenance() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordMaintenanceScreen(equipment: _equipment),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<Equipment>(
      context,
      MaterialPageRoute(
        builder: (_) => EditEquipmentScreen(equipment: _equipment),
      ),
    );
    if (updated != null && mounted) setState(() => _equipment = updated);
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
          "Equipment Profile",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildDetailsCard(),
          const SizedBox(height: 20),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.ac_unit_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _equipment.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _equipment.status,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final rows = <List<dynamic>>[
      [Icons.qr_code_2_rounded, "QR ID", _equipment.qrId],
      [Icons.sell_outlined, "Asset Tag", _equipment.assetTag],
      [Icons.business_rounded, "Brand", _equipment.brand],
      [Icons.devices_other_rounded, "Model", _equipment.model],
      [Icons.numbers_rounded, "Serial", _equipment.serial],
      [Icons.meeting_room_outlined, "Room", _equipment.room],
      [Icons.category_outlined, "Category", _equipment.category],
      [Icons.verified_user_outlined, "Warranty", _equipment.warranty],
      [Icons.health_and_safety_outlined, "Condition", _equipment.condition],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _DetailRow(
              icon: rows[i][0] as IconData,
              label: rows[i][1] as String,
              value: rows[i][2] as String,
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _openRecordMaintenance,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.build_rounded, size: 20),
            label: const Text(
              "Record Maintenance",
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                icon: Icons.history_rounded,
                label: "History",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EquipmentHistoryScreen(equipment: _equipment),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SecondaryButton(
                icon: Icons.event_rounded,
                label: "Schedule",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EquipmentScheduleScreen(equipment: _equipment),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _SecondaryButton(
            icon: Icons.edit_outlined,
            label: "Edit Information",
            onTap: _openEdit,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 18),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
