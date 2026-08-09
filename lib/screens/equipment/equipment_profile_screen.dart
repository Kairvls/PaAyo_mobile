import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/equipment.dart';
import '../../utils/equipment_icon.dart';
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
  static const _muted = Color(0xFF94A3B8);
  static const _bg = Color(0xFFF4F6F8);
  static const _blue = Color(0xFF2563EB);
  static const _navy = Color(0xFF0B2F64);

  final MaintenanceService _service = MaintenanceService();
  late Equipment _equipment = widget.equipment;
  int _tab = 0; // 0 Overview, 1 Specs
  List<MaintenanceSchedule>? _schedules;
  bool _loadingSchedules = true;

  final PageController _heroController = PageController();
  int _heroPage = 0;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    final s = _equipment.status.toLowerCase();
    if (s.contains("dispose")) return const Color(0xFFEF4444);
    if (s.contains("replace")) return const Color(0xFFEA580C);
    if (s.contains("maintenance")) return const Color(0xFFF59E0B);
    if (s.contains("borrow")) return const Color(0xFF0EA5E9);
    return const Color(0xFF16A34A);
  }

  Color _scheduleColor(MaintenanceSchedule s) {
    if (s.isOverdue) return const Color(0xFFEF4444);
    if (s.isDueSoon) return const Color(0xFFF59E0B);
    final t = s.status.toLowerCase();
    if (t.contains("completed")) return const Color(0xFF16A34A);
    return _blue;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero()),
              // Pull the white sheet up over the hero.
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: _buildSheet(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _RoundIconButton(
                    icon: Icons.edit_outlined,
                    onTap: _openEdit,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Container(
        color: _bg,
        child: Column(
          children: [
            const SizedBox(height: 60),
            SizedBox(
              height: 188,
              child: PageView(
                controller: _heroController,
                onPageChanged: (i) => setState(() => _heroPage = i),
                children: [
                  _heroIconPage(),
                  _heroQrPage(),
                  _heroSnapshotPage(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  _Dot(active: _heroPage == i, color: _blue),
                  if (i < 2) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroIconPage() {
    return Center(
      child: Container(
        width: 168,
        height: 168,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: EquipmentGraphic(
            name: _equipment.name,
            category: _equipment.category,
            size: 100,
            fallbackColor: _navy.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  Widget _heroQrPage() {
    return Center(
      child: Container(
        width: 178,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: _equipment.qrId,
              version: QrVersions.auto,
              size: 122,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: _navy,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _equipment.qrId,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroSnapshotPage() {
    final dateFmt = DateFormat("MMM d, yyyy");
    final next = _nextSchedule;
    final lastServiced = _lastServicedDate;

    return Center(
      child: Container(
        width: 240,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety_rounded,
                    size: 18, color: _blue),
                const SizedBox(width: 8),
                const Text(
                  "Snapshot",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                if (_loadingSchedules)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _snapshotRow(
              Icons.event_rounded,
              "Next due",
              next?.nextDate != null
                  ? dateFmt.format(next!.nextDate!)
                  : "None scheduled",
              trailing: next == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _scheduleColor(next).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        next.urgencyLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _scheduleColor(next),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            _snapshotRow(
              Icons.history_rounded,
              "Last serviced",
              lastServiced != null ? dateFmt.format(lastServiced) : "—",
            ),
            const SizedBox(height: 12),
            _snapshotRow(
              Icons.verified_rounded,
              "Condition",
              _equipment.condition,
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotRow(IconData icon, String label, String value,
      {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _muted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          trailing
        else
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
      ],
    );
  }

  /// Soonest upcoming (or overdue) schedule with a next date.
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
        .where((s) => !s.nextDate!.isBefore(DateTime(now.year, now.month, now.day)))
        .toList();
    return upcoming.isNotEmpty ? upcoming.first : items.first;
  }

  /// Most recent completed/last date across this equipment's schedules.
  DateTime? get _lastServicedDate {
    final dates = (_schedules ?? [])
        .map((s) => s.lastDate)
        .whereType<DateTime>()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return dates.isNotEmpty ? dates.first : null;
  }

  Widget _buildSheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _equipment.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: _statusColor),
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _equipment.qrId,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _equipment.room == "—" ? _equipment.category : _equipment.room,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            "Quick info",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(label: _equipment.category),
              _InfoChip(label: _equipment.condition),
              _InfoChip(label: _equipment.brand),
            ],
          ),
          const SizedBox(height: 24),
          _buildSchedulePreview(),
          const SizedBox(height: 26),
          _buildTabs(),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _tab == 0 ? _buildOverview() : _buildSpecs(),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePreview() {
    final dateFmt = DateFormat("MMM d, yyyy");
    final schedules = _schedules ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Maintenance schedule",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            TextButton(
              onPressed: _openSchedule,
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                schedules.isEmpty ? "Create" : "Manage",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingSchedules)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          )
        else if (schedules.isEmpty)
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: _openSchedule,
              borderRadius: BorderRadius.circular(18),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Row(
                  children: [
                    Icon(Icons.event_busy_rounded, color: _muted),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "No schedule yet. Tap to create one for this unit.",
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: _muted),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              for (final s in schedules.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: _openSchedule,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _scheduleColor(s).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.event_rounded,
                                color: _scheduleColor(s),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      if (s.nextDate != null)
                                        dateFmt.format(s.nextDate!),
                                      s.frequency,
                                    ].join(" · "),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
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
                                color: _scheduleColor(s).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.urgencyLabel,
                                style: TextStyle(
                                  color: _scheduleColor(s),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (schedules.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _openSchedule,
                    child: Text(
                      "+${schedules.length - 3} more",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _TabPill(
            label: "Overview",
            selected: _tab == 0,
            onTap: () => setState(() => _tab = 0),
          ),
          _TabPill(
            label: "Specifications",
            selected: _tab == 1,
            onTap: () => setState(() => _tab = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Column(
      key: const ValueKey("overview"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "This unit is currently marked as ${_equipment.status.toLowerCase()}. "
          "Use the scanner-linked schedule to plan inspections, record fixes on-site, "
          "and review its maintenance history.",
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.55,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        _SoftStat(
          icon: Icons.meeting_room_outlined,
          label: "Location",
          value: _equipment.room,
        ),
        const SizedBox(height: 10),
        _SoftStat(
          icon: Icons.health_and_safety_outlined,
          label: "Condition",
          value: _equipment.condition,
        ),
        const SizedBox(height: 10),
        _SoftStat(
          icon: Icons.verified_user_outlined,
          label: "Warranty",
          value: _equipment.warranty,
        ),
      ],
    );
  }

  Widget _buildSpecs() {
    final rows = <(String, String)>[
      ("QR ID", _equipment.qrId),
      ("Asset Tag", _equipment.assetTag),
      ("Brand", _equipment.brand),
      ("Model", _equipment.model),
      ("Serial", _equipment.serial),
      ("Room", _equipment.room),
      ("Category", _equipment.category),
      ("Condition", _equipment.condition),
      ("Status", _equipment.status),
      ("Warranty", _equipment.warranty),
    ];

    return Column(
      key: const ValueKey("specs"),
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(
                  rows[i].$1,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i != rows.length - 1)
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          height: 64,
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _BarIconButton(
                icon: Icons.history_rounded,
                onTap: _openHistory,
              ),
              const SizedBox(width: 4),
              _BarIconButton(
                icon: Icons.build_rounded,
                onTap: _openRecordMaintenance,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: double.infinity,
                  child: FilledButton(
                    onPressed: _openSchedule,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Schedule",
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  final Color color;

  const _Dot({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 16 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label == "—" || label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SoftStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BarIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
