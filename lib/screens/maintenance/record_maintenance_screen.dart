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
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF2563EB);

  // Matches the API's allowed values (in:Pending,Processing,Resolved,For Replacement).
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
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "Record Maintenance",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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

          _sectionLabel("Status"),
          const SizedBox(height: 10),
          _card(
            child: Column(
              children: [
                for (int i = 0; i < _statuses.length; i++) ...[
                  _RadioTile(
                    label: _statuses[i],
                    selected: _status == _statuses[i],
                    onTap: () => setState(() => _status = _statuses[i]),
                  ),
                  if (i != _statuses.length - 1)
                    const Divider(height: 1, indent: 52),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          _sectionLabel("Findings"),
          const SizedBox(height: 10),
          _inputCard(
            controller: _findings,
            hint: "What did you find during this maintenance?",
          ),
          const SizedBox(height: 22),

          _sectionLabel("Repair Action"),
          _optional(),
          const SizedBox(height: 10),
          _inputCard(
            controller: _repairAction,
            hint: "What action did you take?",
          ),
          const SizedBox(height: 22),

          if (_isReplacement) ...[
            _sectionLabel("Replacement Remarks"),
            _optional(),
            const SizedBox(height: 10),
            _inputCard(
              controller: _replacementRemarks,
              hint: "Notes about the replacement.",
            ),
            const SizedBox(height: 22),
          ],

          _sectionLabel("Proof Photo"),
          _optional(),
          const SizedBox(height: 10),
          _buildProofPicker(),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      "Save",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickImage,
        child: Container(
          height: 96,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
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

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      );

  Widget _optional() => const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text(
          "Optional",
          style: TextStyle(fontSize: 11.5, color: _muted),
        ),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _inputCard({
    required TextEditingController controller,
    required String hint,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: const TextStyle(color: _muted),
          ),
        ),
      );
}

class _RadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFCBD5E1),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
