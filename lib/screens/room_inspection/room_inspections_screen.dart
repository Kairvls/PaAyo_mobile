import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/room_inspection.dart';
import '../../services/room_inspection_service.dart';
import 'room_inspect_screen.dart';

class RoomInspectionsScreen extends StatefulWidget {
  const RoomInspectionsScreen({super.key});

  @override
  State<RoomInspectionsScreen> createState() => _RoomInspectionsScreenState();
}

class _RoomInspectionsScreenState extends State<RoomInspectionsScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF9CA3AF);
  static const _bg = Colors.white;
  static const _blue = Color(0xFF0025CC);
  static const _border = Color(0xFFE5E7EB);

  final RoomInspectionService _service = RoomInspectionService();
  final TextEditingController _search = TextEditingController();
  late Future<List<RoomInspectionSchedule>> _future;
  String _status = "";

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
      _future = _service.listSchedules(
        status: _status.isEmpty ? null : _status,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Overdue":
        return const Color(0xFFDC2626);
      case "Active":
        return _blue;
      case "Completed":
        return const Color(0xFF16A34A);
      default:
        return _muted;
    }
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
            "Room inspections",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 20,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _SearchField(
                controller: _search,
                onSubmitted: (_) => _reload(),
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final entry in const [
                    ("", "Open"),
                    ("Overdue", "Overdue"),
                    ("Active", "Active"),
                    ("due_week", "Due this week"),
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.$2),
                        selected: _status == entry.$1,
                        onSelected: (_) {
                          setState(() => _status = entry.$1);
                          _reload();
                        },
                        selectedColor: _blue,
                        labelStyle: TextStyle(
                          color: _status == entry.$1 ? Colors.white : _ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _status == entry.$1 ? _blue : _border,
                        ),
                        showCheckmark: false,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<RoomInspectionSchedule>>(
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

                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _search.text.trim().isNotEmpty
                              ? "No rooms match your search."
                              : "No open room inspections.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted, height: 1.4),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final s = items[index];
                        return Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: _border),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final saved = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RoomInspectScreen(scheduleId: s.id),
                                ),
                              );
                              if (saved == true && mounted) _reload();
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
                                          s.roomName.isEmpty
                                              ? s.title
                                              : s.roomName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: _ink,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(s.status)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          s.status,
                                          style: TextStyle(
                                            color: _statusColor(s.status),
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
                                      s.title,
                                      if (s.department.isNotEmpty) s.department,
                                      if (s.frequency.isNotEmpty) s.frequency,
                                    ].join(" · "),
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (s.nextDate != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      "Next ${dateFmt.format(s.nextDate!)}",
                                      style: TextStyle(
                                        color: s.isOverdue
                                            ? const Color(0xFFDC2626)
                                            : _muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onChanged;

  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF111827), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onChanged: (_) => onChanged(),
              onSubmitted: onSubmitted,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: "Search room, title…",
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: "Search",
            onPressed: () => onSubmitted(controller.text),
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF111827), size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
