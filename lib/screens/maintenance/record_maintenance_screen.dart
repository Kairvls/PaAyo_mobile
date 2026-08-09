import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';

class RecordMaintenanceScreen extends StatefulWidget {
  final Equipment equipment;

  const RecordMaintenanceScreen({super.key, required this.equipment});

  @override
  State<RecordMaintenanceScreen> createState() =>
      _RecordMaintenanceScreenState();
}

class _RecordMaintenanceScreenState extends State<RecordMaintenanceScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF94A3B8);
  static const _bg = Color(0xFFF4F6F8);
  static const _blue = Color(0xFF2563EB);

  static const _statuses = [
    "Pending",
    "Processing",
    "Resolved",
    "For Replacement",
  ];

  final MaintenanceService _service = MaintenanceService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _findings = TextEditingController();
  final TextEditingController _repairAction = TextEditingController();
  final TextEditingController _replacementRemarks = TextEditingController();

  String _status = "Resolved";
  File? _proof;
  bool _saving = false;

  bool get _isReplacement => _status == "For Replacement";

  @override
  void dispose() {
    _findings.dispose();
    _repairAction.dispose();
    _replacementRemarks.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text("Take a photo"),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text("Choose from gallery"),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) setState(() => _proof = File(picked.path));
  }

  Future<void> _save() async {
    if (_findings.text.trim().isEmpty) {
      _snack("Please describe your findings.");
      return;
    }

    final personnelIdStr = await _storage.read(key: "user_id");
    final personnelId = int.tryParse(personnelIdStr ?? "");
    if (personnelId == null) {
      _snack("Your session is missing an account ID. Please sign in again.");
      return;
    }

    setState(() => _saving = true);

    try {
      final res = await _service.storeHistory(
        equipmentId: widget.equipment.id,
        personnelId: personnelId,
        findings: _findings.text.trim(),
        status: _status,
        repairAction: _repairAction.text.trim(),
        replacementRemarks: _replacementRemarks.text.trim(),
        proofImage: _proof,
      );

      final ok = res.statusCode == 201 ||
          (res.data is Map && res.data["success"] == true);

      if (!mounted) return;
      setState(() => _saving = false);

      if (!ok) {
        final msg = res.data is Map ? res.data["message"]?.toString() : null;
        _snack(msg ?? "Could not save the maintenance record.");
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF16A34A), size: 40),
          title: const Text("Maintenance saved"),
          content: Text(
            "$_status record saved for ${widget.equipment.name}.",
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: _blue),
              child: const Text("Done"),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context, true);
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
                        _label("Status"),
                        const SizedBox(height: 12),
                        _pills(
                          _statuses,
                          _status,
                          (v) => setState(() => _status = v),
                        ),
                        const SizedBox(height: 22),
                        _label("Findings"),
                        const SizedBox(height: 8),
                        _input(
                          _findings,
                          "What did you find during this maintenance?",
                          maxLines: 4,
                        ),
                        const SizedBox(height: 18),
                        _label("Repair Action", optional: true),
                        const SizedBox(height: 8),
                        _input(
                          _repairAction,
                          "What action did you take?",
                          maxLines: 3,
                        ),
                        if (_isReplacement) ...[
                          const SizedBox(height: 18),
                          _label("Replacement Remarks", optional: true),
                          const SizedBox(height: 8),
                          _input(
                            _replacementRemarks,
                            "Notes about the replacement.",
                            maxLines: 3,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _label("Proof Photo", optional: true),
                        const SizedBox(height: 10),
                        _buildProofPicker(),
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
                      _RoundIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        "Record Fix",
                        style: TextStyle(
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
            child: _BottomSaveBar(
              label: "Save Record",
              saving: _saving,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofPicker() {
    if (_proof != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              _proof!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _proof = null),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child:
                      Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: _blue, size: 26),
              SizedBox(height: 8),
              Text(
                "Attach a photo",
                style: TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 8),
          const Text(
            "Optional",
            style: TextStyle(fontSize: 11.5, color: _muted),
          ),
        ],
      ],
    );
  }

  Widget _input(
    TextEditingController c,
    String hint, {
    int maxLines = 1,
  }) {
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

  Widget _pills(
    List<String> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: () => onChanged(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected == option ? _blue : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected == option
                      ? _blue
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected == option ? Colors.white : _ink,
                ),
              ),
            ),
          ),
      ],
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
      color: const Color(0xFFF1F5F9),
      shape: const CircleBorder(),
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

class _BottomSaveBar extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onPressed;

  const _BottomSaveBar({
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              onPressed: saving ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  const Color(0xFF2563EB).withValues(alpha: 0.55),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
