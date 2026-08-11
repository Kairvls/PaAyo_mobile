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
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _page = Color(0xFFF3F3F3);
  static const _yellow = Color(0xFFFBBF24);

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
    if (schedule.isDueSoon) return _yellow;
    final s = schedule.status.toLowerCase();
    if (s.contains("completed")) return const Color(0xFF22C55E);
    return _ink;
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
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _page,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: _yellow,
        foregroundColor: _ink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          "Create schedule",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 8, 20, 12),
            child: Row(
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.arrow_back_rounded,
                          size: 20, color: _ink),
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    "Schedule",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MaintenanceSchedule>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: _ink,
                    ),
                  );
                }

                final schedules = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                          Text(
                            widget.equipment.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -0.4,
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
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 18),
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, size: 36, color: _muted),
          const SizedBox(height: 12),
          const Text(
            "No maintenance schedule",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Create a schedule so this equipment can be inspected on time.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _create,
            style: FilledButton.styleFrom(
              backgroundColor: _yellow,
              foregroundColor: _ink,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              "Create schedule",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        schedule.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        schedule.relativeDueLabel,
                        style: TextStyle(
                          color: color == const Color(0xFFFBBF24)
                              ? const Color(0xFF92400E)
                              : color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (schedule.description != null &&
                    schedule.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    schedule.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A8A8A),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.repeat_rounded,
                        size: 16, color: Color(0xFF8A8A8A)),
                    const SizedBox(width: 6),
                    Text(
                      schedule.frequency,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF8A8A8A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.event_rounded,
                        size: 16, color: Color(0xFF8A8A8A)),
                    const SizedBox(width: 6),
                    Text(
                      next == null
                          ? "No date"
                          : DateFormat("MMM d, yyyy").format(next),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF8A8A8A),
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
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _page = Color(0xFFF3F3F3);
  static const _soft = Color(0xFFF7F7F7);
  static const _yellow = Color(0xFFFBBF24);
  static const _border = Color(0xFFE8E8E8);

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
      helpText: "Select next date",
      cancelText: "Cancel",
      confirmText: "Confirm",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _yellow,
              onPrimary: _ink,
              secondary: _yellow,
              onSecondary: _ink,
              surface: Colors.white,
              onSurface: _ink,
              onSurfaceVariant: _muted,
              outline: _border,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              headerBackgroundColor: _ink,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
              headerHelpStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              weekdayStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
              dayStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
              yearStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
              todayBorder: const BorderSide(color: _yellow, width: 1.4),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _ink;
                return _ink;
              }),
              todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _yellow;
                return Colors.transparent;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _ink;
                if (states.contains(WidgetState.disabled)) {
                  return _muted.withValues(alpha: 0.35);
                }
                return _ink;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _yellow;
                return Colors.transparent;
              }),
              dayOverlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered)) {
                  return _yellow.withValues(alpha: 0.18);
                }
                return null;
              }),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _ink;
                return _ink;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _yellow;
                return Colors.transparent;
              }),
              dayShape: WidgetStateProperty.all(const CircleBorder()),
              rangePickerHeaderBackgroundColor: _ink,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _ink,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
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
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _page,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top + 64)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: Column(
                    children: [
                      Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
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
                        Text(
                          _isCreate ? "Create schedule" : "Edit schedule",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.equipment.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.5,
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
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 22),
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
                          color: Colors.white,
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
                                border: Border.all(color: _border, width: 1),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                    color: _ink,
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
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _yellow,
                            foregroundColor: _ink,
                            disabledBackgroundColor:
                                _yellow.withValues(alpha: 0.55),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(_ink),
                                  ),
                                )
                              : Text(
                                  _isCreate
                                      ? "Create Schedule"
                                      : "Save Changes",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 8, 20, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.arrow_back_rounded,
                            size: 20, color: _ink),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _isCreate ? "Create Schedule" : "Edit Schedule",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
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
          color: selected ? _ink : _soft,
          borderRadius: BorderRadius.circular(22),
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
