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
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _page = Color(0xFFF3F3F3);
  static const _soft = Color(0xFFF7F7F7);
  static const _yellow = Color(0xFFFBBF24);
  static const _border = Color(0xFFE8E8E8);

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF22C55E), size: 40),
          title: const Text(
            "Maintenance saved",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            "$_status record saved for ${widget.equipment.name}.",
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: _yellow,
                foregroundColor: _ink,
              ),
              child: const Text(
                "Done",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
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
                            const Text(
                              "Record fix",
                              style: TextStyle(
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.build_rounded, size: 18),
                                    SizedBox(width: 10),
                                    Text(
                                      "Save Record",
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
                  _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      "Record Fix",
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
            borderRadius: BorderRadius.circular(16),
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
      color: _soft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: _ink, size: 26),
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
                color: selected == option ? _ink : _soft,
                borderRadius: BorderRadius.circular(22),
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

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
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
