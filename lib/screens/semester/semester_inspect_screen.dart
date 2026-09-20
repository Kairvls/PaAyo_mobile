import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/semester_inspection.dart';
import '../../services/semester_inspection_service.dart';

class SemesterInspectScreen extends StatefulWidget {
  final int campaignId;
  final SemesterInspectionItem item;
  final List<String> conditions;

  const SemesterInspectScreen({
    super.key,
    required this.campaignId,
    required this.item,
    this.conditions = const [
      "OK",
      "Malfunctioning",
      "Defective",
      "Destroyed",
    ],
  });

  @override
  State<SemesterInspectScreen> createState() => _SemesterInspectScreenState();
}

class _SemesterInspectScreenState extends State<SemesterInspectScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF2563EB);

  final SemesterInspectionService _service = SemesterInspectionService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _findings = TextEditingController();
  final TextEditingController _action = TextEditingController();

  late String _condition;
  bool _applyStatus = true;
  bool _saving = false;
  File? _proof;

  @override
  void initState() {
    super.initState();
    _condition = widget.item.condition ??
        (widget.conditions.isNotEmpty ? widget.conditions.first : "OK");
    if (widget.item.findings != null) {
      _findings.text = widget.item.findings!;
    }
    if (widget.item.actionTaken != null) {
      _action.text = widget.item.actionTaken!;
    }
  }

  @override
  void dispose() {
    _findings.dispose();
    _action.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() => _proof = File(picked.path));
    }
  }

  Future<void> _save() async {
    final findings = _findings.text.trim();
    if (findings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Findings are required.")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _service.inspect(
        campaignId: widget.campaignId,
        itemId: widget.item.id,
        condition: _condition,
        findings: findings,
        actionTaken: _action.text.trim().isEmpty ? null : _action.text.trim(),
        applyStatus: _applyStatus,
        proofImage: _proof,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst("Exception: ", ""),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "Record inspection",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.equipmentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if ((item.assetTag ?? "").isNotEmpty) item.assetTag!,
                    if (item.room.isNotEmpty) item.room,
                    if (item.category.isNotEmpty) item.category,
                  ].join(" · "),
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                if (item.isInspected) ...[
                  const SizedBox(height: 8),
                  const Text(
                    "Already inspected — saving will update the record.",
                    style: TextStyle(
                      color: Color(0xFFEA580C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Condition",
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.conditions.map((c) {
              final selected = _condition == c;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => setState(() => _condition = c),
                selectedColor: _blue.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? _blue : _muted,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            "Findings",
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _findings,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "What did you observe?",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Action taken (optional)",
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _action,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Temporary fix, tagged for disposal, etc.",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Proof photo (optional)",
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 8),
          if (_proof != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    _proof!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => setState(() => _proof = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pickProof,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text("Take photo"),
            ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _applyStatus,
            onChanged: (v) => setState(() => _applyStatus = v),
            title: const Text(
              "Update equipment status from condition",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _ink,
              ),
            ),
            subtitle: const Text(
              "OK→Good · Malfunctioning→Under Maintenance · Defective/Destroyed→For Replacement",
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Save inspection",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
