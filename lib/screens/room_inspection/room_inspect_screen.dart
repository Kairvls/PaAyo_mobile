import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/room_inspection_service.dart';

class RoomInspectScreen extends StatefulWidget {
  final int scheduleId;

  const RoomInspectScreen({super.key, required this.scheduleId});

  @override
  State<RoomInspectScreen> createState() => _RoomInspectScreenState();
}

class _RoomInspectScreenState extends State<RoomInspectScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF0025CC);
  static const _border = Color(0xFFE5E7EB);

  final RoomInspectionService _service = RoomInspectionService();
  final _findings = TextEditingController();
  final _action = TextEditingController();
  final _picker = ImagePicker();

  late Future<RoomInspectionDetail> _future;
  List<String> _checkAnswers = [];
  String _result = "Good";
  File? _proof;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _service.getSchedule(widget.scheduleId).then((detail) {
      _checkAnswers = List.filled(
        detail.schedule.checklist.length,
        detail.checkStatuses.isNotEmpty ? detail.checkStatuses.first : "Pass",
      );
      if (detail.results.isNotEmpty) {
        _result = detail.results.first;
      }
      return detail;
    });
  }

  @override
  void dispose() {
    _findings.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (shot == null || !mounted) return;
    setState(() => _proof = File(shot.path));
  }

  Future<void> _submit(RoomInspectionDetail detail) async {
    if (_saving) return;

    final needsFindings = _result != "Good" ||
        _checkAnswers.any((a) => a == "Issue");
    if (needsFindings && _findings.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Describe what needs attention in findings."),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final message = await _service.inspect(
        id: widget.scheduleId,
        checks: _checkAnswers,
        result: _result,
        findings: _findings.text,
        actionTaken: _action.text,
        proofImage: _proof,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d, yyyy");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "Inspect room",
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
      ),
      body: FutureBuilder<RoomInspectionDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snap.error?.toString().replaceFirst("Exception: ", "") ??
                      "Could not load inspection.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
              ),
            );
          }

          final detail = snap.data!;
          final s = detail.schedule;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                s.roomName.isEmpty ? s.title : s.roomName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  s.title,
                  if (s.department.isNotEmpty) s.department,
                  if (s.frequency.isNotEmpty) s.frequency,
                  if (s.nextDate != null)
                    "Due ${dateFmt.format(s.nextDate!)}",
                ].join(" · "),
                style: const TextStyle(color: _muted, fontSize: 13.5),
              ),
              const SizedBox(height: 20),
              const Text(
                "Checklist",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < s.checklist.length; i++) ...[
                _CheckRow(
                  label: s.checklist[i],
                  value: _checkAnswers[i],
                  options: detail.checkStatuses,
                  onChanged: (v) => setState(() => _checkAnswers[i] = v),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              const Text(
                "Overall result",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in detail.results)
                    ChoiceChip(
                      label: Text(r),
                      selected: _result == r,
                      onSelected: (_) => setState(() => _result = r),
                      selectedColor: _blue,
                      labelStyle: TextStyle(
                        color: _result == r ? Colors.white : _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _result == r ? _blue : _border,
                      ),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _findings,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Findings",
                  hintText: "What did you notice?",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _action,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: "Action taken (optional)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickProof,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_proof == null ? "Add proof photo" : "Retake proof"),
              ),
              if (_proof != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_proof!, height: 140, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : () => _submit(detail),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_saving ? "Saving…" : "Save inspection"),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _CheckRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final opt in options) ...[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: opt == options.last ? 0 : 6,
                    ),
                    child: InkWell(
                      onTap: () => onChanged(opt),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: value == opt
                              ? const Color(0xFF0025CC)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: value == opt
                                ? const Color(0xFF0025CC)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: value == opt
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
