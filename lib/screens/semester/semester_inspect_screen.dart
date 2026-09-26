import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF9CA3AF);
  static const _bg = Colors.white;
  static const _blue = Color(0xFF0025CC);
  static const _fieldBorder = Color(0xFFE5E7EB);

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

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _muted,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _blue, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final meta = [
      if ((item.assetTag ?? "").isNotEmpty) item.assetTag!,
      if (item.room.isNotEmpty) item.room,
      if (item.category.isNotEmpty) item.category,
    ].join(" · ");

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: _ink,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        "Record inspection",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _fieldBorder),
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
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              meta,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (item.isInspected) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                "Already inspected — saving will update",
                                style: TextStyle(
                                  color: Color(0xFFEA580C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      "Condition",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.conditions.map((c) {
                        final selected = _condition == c;
                        return GestureDetector(
                          onTap: () => setState(() => _condition = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? _blue : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected ? _blue : _fieldBorder,
                              ),
                            ),
                            child: Text(
                              c,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : _muted,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      "Findings",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _findings,
                      maxLines: 4,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _fieldDecoration("What did you observe?"),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      "Action taken (optional)",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _action,
                      maxLines: 2,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _fieldDecoration(
                        "Temporary fix, tagged for disposal, etc.",
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      "Proof photo (optional)",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_proof != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
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
                      Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: _fieldBorder),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _pickProof,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.photo_camera_outlined,
                                  color: _ink,
                                  size: 22,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Take photo",
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: _blue,
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
                      height: 52,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          disabledBackgroundColor:
                              _blue.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
