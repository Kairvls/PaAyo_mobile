import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _line = Color(0xFFEEEEEE);
  static const _page = Color(0xFFF3F3F3);
  static const _yellow = Color(0xFFFBBF24);
  static const _soft = Color(0xFFF7F7F7);

  final MaintenanceService _service = MaintenanceService();
  late Equipment _equipment = widget.equipment;
  int _tab = 0; // 0 Overview, 1 Specs — primary scan payoff
  List<MaintenanceSchedule>? _schedules;
  bool _loadingSchedules = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Color get _statusColor {
    final s = _equipment.status.toLowerCase();
    if (s.contains("dispose")) return const Color(0xFFEF4444);
    if (s.contains("replace")) return const Color(0xFFEA580C);
    if (s.contains("maintenance")) return _yellow;
    if (s.contains("borrow")) return const Color(0xFF38BDF8);
    return const Color(0xFF22C55E);
  }

  Color _scheduleColor(MaintenanceSchedule s) {
    if (s.isOverdue) return const Color(0xFFEF4444);
    if (s.isDueSoon) return _yellow;
    final t = s.status.toLowerCase();
    if (t.contains("completed")) return const Color(0xFF22C55E);
    return _ink;
  }

  Future<void> _loadSchedules() async {
    setState(() => _loadingSchedules = true);
    try {
      final items = await _service.getSchedules(_equipment.id);
      if (!mounted) return;
      setState(() {
        _schedules = items;
        _loadingSchedules = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _schedules = [];
        _loadingSchedules = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _service.getEquipmentByQr(_equipment.qrId);
      if (mounted) setState(() => _equipment = fresh);
    } catch (_) {}
    await _loadSchedules();
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

  Future<void> _openSchedule() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EquipmentScheduleScreen(equipment: _equipment),
      ),
    );
    if (mounted) await _loadSchedules();
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EquipmentHistoryScreen(equipment: _equipment),
      ),
    );
  }

  Future<void> _copyQr() async {
    await Clipboard.setData(ClipboardData(text: _equipment.qrId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("QR ID copied"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  MaintenanceSchedule? get _nextSchedule {
    final items = (_schedules ?? [])
        .where((s) => s.nextDate != null)
        .toList()
      ..sort((a, b) => a.nextDate!.compareTo(b.nextDate!));
    if (items.isEmpty) return null;
    final overdue = items.where((s) => s.isOverdue).toList();
    if (overdue.isNotEmpty) return overdue.first;
    final now = DateTime.now();
    final upcoming = items
        .where((s) =>
            !s.nextDate!.isBefore(DateTime(now.year, now.month, now.day)))
        .toList();
    return upcoming.isNotEmpty ? upcoming.first : items.first;
  }

  DateTime? get _lastServicedDate {
    final dates = (_schedules ?? [])
        .map((s) => s.lastDate)
        .whereType<DateTime>()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return dates.isNotEmpty ? dates.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _page,
      body: Stack(
        children: [
          // Soft top wash (like blurred map behind Move sheet)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 180,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8E8E8), _page],
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top + 8)),
              SliverToBoxAdapter(child: _buildBackRow()),
              SliverToBoxAdapter(child: _buildSheet()),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          _CircleButton(
            icon: Icons.edit_outlined,
            onTap: _openEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildSheet() {
    final dateFmt = DateFormat("MMM d, yyyy");
    final next = _nextSchedule;
    final lastServiced = _lastServicedDate;
    final schedules = _schedules ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status — first glance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Equipment",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _equipment.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(
                label: _equipment.status,
                color: _statusColor,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Black QR hero block (Move tracking-number moment)
          Material(
            color: _ink,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: _copyQr,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "QR ID",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.55),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _equipment.qrId,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Overview / Specs — why staff scan: details on-site, immediately
          Row(
            children: [
              _SheetTab(
                label: "Overview",
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 18),
              _SheetTab(
                label: "Specifications",
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _tab == 0 ? _buildOverview() : _buildSpecs(),
          ),

          const SizedBox(height: 12),

          // Soft maintenance note box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Maintenance",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Next due",
                        style: TextStyle(
                          fontSize: 13.5,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (next != null) ...[
                      Text(
                        dateFmt.format(next.nextDate!),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(
                        label: next.relativeDueLabel,
                        color: _scheduleColor(next),
                        compact: true,
                      ),
                    ] else
                      const Text(
                        "None scheduled",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Last serviced",
                        style: TextStyle(
                          fontSize: 13.5,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      lastServiced != null
                          ? dateFmt.format(lastServiced)
                          : "—",
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Upcoming schedule preview
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Upcoming",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (!_loadingSchedules && schedules.isNotEmpty)
                GestureDetector(
                  onTap: _openSchedule,
                  child: const Text(
                    "See all",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingSchedules)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _ink,
                  ),
                ),
              ),
            )
          else if (schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "No schedule yet for this unit.",
                style: TextStyle(
                  fontSize: 13.5,
                  color: _muted.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Column(
              children: [
                for (final s in schedules.take(2))
                  _ScheduleRow(
                    title: s.title,
                    subtitle: [
                      if (s.nextDate != null) dateFmt.format(s.nextDate!),
                      s.frequency,
                    ].join(" · "),
                    badge: s.relativeDueLabel,
                    badgeColor: _scheduleColor(s),
                    onTap: _openSchedule,
                  ),
              ],
            ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 4),

          // Move-style nav rows
          _NavRow(
            icon: Icons.event_rounded,
            label: "Schedule",
            hint: schedules.isEmpty ? "Create" : "${schedules.length} items",
            onTap: _openSchedule,
          ),
          _NavRow(
            icon: Icons.history_rounded,
            label: "History",
            hint: "Past fixes",
            onTap: _openHistory,
          ),
          _NavRow(
            icon: Icons.tune_rounded,
            label: "Edit details",
            hint: "Update info",
            onTap: _openEdit,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton(
            onPressed: _openRecordMaintenance,
            style: FilledButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build_rounded, size: 18, color: _yellow),
                SizedBox(width: 10),
                Text(
                  "Record Fix",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Quick on-site snapshot after scan.
  Widget _buildOverview() {
    return Column(
      key: const ValueKey("overview"),
      children: [
        _Kv(label: "Location", value: _equipment.room),
        _Kv(label: "Category", value: _equipment.category),
        _Kv(label: "Condition", value: _equipment.condition),
        _Kv(label: "Status", value: _equipment.status),
        _Kv(label: "Warranty", value: _equipment.warranty),
      ],
    );
  }

  /// Full inventory / technical fields after scan.
  Widget _buildSpecs() {
    return Column(
      key: const ValueKey("specs"),
      children: [
        _Kv(label: "QR ID", value: _equipment.qrId),
        _Kv(label: "Asset tag", value: _equipment.assetTag),
        _Kv(label: "Brand", value: _equipment.brand),
        _Kv(label: "Model", value: _equipment.model),
        _Kv(label: "Serial", value: _equipment.serial),
        _Kv(label: "Room", value: _equipment.room),
        _Kv(label: "Category", value: _equipment.category),
        _Kv(label: "Condition", value: _equipment.condition),
        _Kv(label: "Status", value: _equipment.status),
        _Kv(label: "Warranty", value: _equipment.warranty),
      ],
    );
  }
}

class _SheetTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected
                    ? const Color(0xFF111111)
                    : const Color(0xFFAAAAAA),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2.5,
              width: selected ? 26 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: const Color(0xFF111111)),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _StatusChip({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == const Color(0xFFFBBF24)
              ? const Color(0xFF92400E)
              : color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  final String label;
  final String value;

  const _Kv({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final display = (value.trim().isEmpty) ? "—" : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8A8A8A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: display == "—"
                    ? const Color(0xFFBBBBBB)
                    : const Color(0xFF111111),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _ScheduleRow({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8A8A8A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(label: badge, color: badgeColor, compact: true),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool showDivider;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: const Color(0xFF111111)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF8A8A8A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFBBBBBB),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}
