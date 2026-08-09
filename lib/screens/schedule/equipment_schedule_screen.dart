import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';

class EquipmentScheduleScreen extends StatefulWidget {
  final Equipment equipment;

  const EquipmentScheduleScreen({super.key, required this.equipment});

  @override
  State<EquipmentScheduleScreen> createState() =>
      _EquipmentScheduleScreenState();
}

class _EquipmentScheduleScreenState extends State<EquipmentScheduleScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF2563EB);

  final MaintenanceService _service = MaintenanceService();
  late Future<List<MaintenanceSchedule>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _service.getSchedules(widget.equipment.id);
  }

  Color _statusColor(MaintenanceSchedule schedule) {
    if (schedule.isOverdue) return const Color(0xFFEF4444);
    if (schedule.isDueSoon) return const Color(0xFFF59E0B);
    final s = schedule.status.toLowerCase();
    if (s.contains("completed")) return const Color(0xFF16A34A);
    return const Color(0xFF2563EB); // Active
  }

  Future<void> _edit(MaintenanceSchedule schedule) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ScheduleFormScreen(
          equipment: widget.equipment,
          schedule: schedule,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ScheduleFormScreen(equipment: widget.equipment),
      ),
    );
    if (created == true && mounted) {
      setState(_reload);
    }
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
          "Maintenance Schedule",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: _blue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "Create schedule",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<List<MaintenanceSchedule>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final schedules = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
              if (schedules.isEmpty)
                _buildEmpty()
              else
                for (final s in schedules)
                  _ScheduleCard(
                    schedule: s,
                    color: _statusColor(s),
                    onTap: () => _edit(s),
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, size: 40, color: _muted),
          const SizedBox(height: 12),
          const Text(
            "No maintenance schedule",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Create a schedule so this equipment can be inspected on time.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _create,
            style: FilledButton.styleFrom(backgroundColor: _blue),
            icon: const Icon(Icons.add_rounded),
            label: const Text("Create schedule"),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final MaintenanceSchedule schedule;
  final Color color;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.schedule,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final next = schedule.nextDate;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        schedule.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        schedule.urgencyLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (schedule.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    schedule.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.repeat_rounded,
                        size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      schedule.frequency,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.event_rounded,
                        size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      next == null
                          ? "No date"
                          : DateFormat("MMM d, yyyy").format(next),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleFormScreen extends StatefulWidget {
  final Equipment equipment;
  final MaintenanceSchedule? schedule;

  const _ScheduleFormScreen({
    required this.equipment,
    this.schedule,
  });

  @override
  State<_ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<_ScheduleFormScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF94A3B8);
  static const _bg = Color(0xFFF4F6F8);
  static const _blue = Color(0xFF2563EB);

  static const _statuses = ["Active", "Completed", "Overdue"];
  static const _frequencies = [
    "Weekly",
    "Monthly",
    "Quarterly",
    "Semi-Annual",
    "Annual",
  ];

  final MaintenanceService _service = MaintenanceService();

  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _frequency;
  late String _status;
  DateTime? _nextDate;
  bool _saving = false;

  bool get _isCreate => widget.schedule == null;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _title = TextEditingController(
      text: s == null || s.title == "—" ? "" : s.title,
    );
    _description = TextEditingController(text: s?.description ?? "");
    _frequency =
        s != null && _frequencies.contains(s.frequency) ? s.frequency : "Monthly";
    _status = s != null && _statuses.contains(s.status) ? s.status : "Active";
    _nextDate = s?.nextDate ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _nextDate = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _snack("Please enter a title.");
      return;
    }
    if (_nextDate == null) {
      _snack("Please choose the next date.");
      return;
    }

    setState(() => _saving = true);
    try {
      final res = _isCreate
          ? await _service.createSchedule(
              equipmentId: widget.equipment.id,
              title: _title.text.trim(),
              description: _description.text.trim(),
              frequency: _frequency,
              nextDate: _nextDate!,
            )
          : await _service.updateSchedule(
              scheduleId: widget.schedule!.id,
              title: _title.text.trim(),
              description: _description.text.trim(),
              frequency: _frequency,
              nextDate: _nextDate!,
              lastDate: widget.schedule!.lastDate,
              status: _status,
            );

      final ok = res.statusCode == 200 ||
          res.statusCode == 201 ||
          (res.data is Map && res.data["success"] == true);

      if (!mounted) return;
      setState(() => _saving = false);

      if (!ok) {
        final msg = res.data is Map ? res.data["message"]?.toString() : null;
        _snack(msg ??
            (_isCreate
                ? "Could not create the schedule."
                : "Could not update the schedule."));
        return;
      }

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack("Couldn't reach the server. Check your connection.");
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.top + 78,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.equipment.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.equipment.qrId,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _label("Title"),
                        const SizedBox(height: 8),
                        _textCard(_title, "e.g. Filter cleaning"),
                        const SizedBox(height: 18),
                        _label("Description"),
                        const SizedBox(height: 8),
                        _textCard(_description, "Optional details", maxLines: 3),
                        const SizedBox(height: 18),
                        _label("Frequency"),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final f in _frequencies)
                              _chip(
                                f,
                                _frequency == f,
                                () => setState(() => _frequency = f),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _label("Next Date"),
                        const SizedBox(height: 10),
                        Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                    color: _blue,
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    _nextDate == null
                                        ? "Select a date"
                                        : DateFormat("MMMM d, yyyy")
                                            .format(_nextDate!),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: _nextDate == null ? _muted : _ink,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: _muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!_isCreate) ...[
                          const SizedBox(height: 22),
                          _label("Status"),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in _statuses)
                                _chip(
                                  s,
                                  _status == s,
                                  () => setState(() => _status = s),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      Material(
                        color: const Color(0xFFF1F5F9),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(context),
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _isCreate ? "Create Schedule" : "Edit Schedule",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _blue.withValues(alpha: 0.55),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isCreate
                                  ? "Create Schedule"
                                  : "Save Changes",
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      );

  Widget _textCard(TextEditingController c, String hint, {int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _blue : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _blue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _ink,
          ),
        ),
      ),
    );
  }
}
