import 'package:flutter/material.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';

class EditEquipmentScreen extends StatefulWidget {
  final Equipment equipment;

  const EditEquipmentScreen({super.key, required this.equipment});

  @override
  State<EditEquipmentScreen> createState() => _EditEquipmentScreenState();
}

class _EditEquipmentScreenState extends State<EditEquipmentScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF2563EB);

  // Allowed values enforced by the API validator.
  static const _conditions = [
    "Good",
    "Damaged",
    "Under Maintenance",
    "Disposed",
  ];
  static const _inventoryStatuses = [
    "Active",
    "Under Maintenance",
    "Borrowed",
    "For Replacement",
    "Disposed",
  ];

  final MaintenanceService _service = MaintenanceService();

  late final TextEditingController _assetTag;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _location;

  late String _condition;
  late String _inventoryStatus;
  bool _saving = false;

  String _initial(String value, List<String> allowed, String fallback) {
    return allowed.contains(value) ? value : fallback;
  }

  String _clean(String value) => value == "—" ? "" : value;

  @override
  void initState() {
    super.initState();
    final e = widget.equipment;
    _assetTag = TextEditingController(text: _clean(e.assetTag));
    _brand = TextEditingController(text: _clean(e.brand));
    _model = TextEditingController(text: _clean(e.model));
    _serial = TextEditingController(text: _clean(e.serial));
    _location = TextEditingController();
    _condition = _initial(e.condition, _conditions, "Good");
    _inventoryStatus = _initial(e.status, _inventoryStatuses, "Active");
  }

  @override
  void dispose() {
    _assetTag.dispose();
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final res = await _service.updateEquipment(
        id: widget.equipment.id,
        assetTag: _assetTag.text.trim(),
        brandName: _brand.text.trim(),
        model: _model.text.trim(),
        serialNumber: _serial.text.trim(),
        conditionStatus: _condition,
        inventoryStatus: _inventoryStatus,
        currentLocation: _location.text.trim(),
      );

      final ok = res.statusCode == 200 ||
          (res.data is Map && res.data["success"] == true);

      if (!ok) {
        if (!mounted) return;
        setState(() => _saving = false);
        final msg = res.data is Map ? res.data["message"]?.toString() : null;
        _snack(msg ?? "Could not update the equipment.");
        return;
      }

      // Re-fetch the full (joined) profile so the caller shows fresh data.
      final refreshed =
          await _service.getEquipmentByQr(widget.equipment.qrId);

      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, refreshed);
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
          "Edit Information",
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

          _field("Asset Tag", _assetTag, "e.g. AC-2024-014"),
          _field("Brand", _brand, "e.g. Panasonic"),
          _field("Model", _model, "e.g. CS-XN12"),
          _field("Serial Number", _serial, "e.g. SN-88213-KX"),
          _field("Current Location", _location, "Optional"),

          const SizedBox(height: 6),
          _sectionLabel("Condition"),
          const SizedBox(height: 10),
          _choiceCard(_conditions, _condition,
              (v) => setState(() => _condition = v)),
          const SizedBox(height: 22),

          _sectionLabel("Inventory Status"),
          const SizedBox(height: 10),
          _choiceCard(_inventoryStatuses, _inventoryStatus,
              (v) => setState(() => _inventoryStatus = v)),
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
                      "Save Changes",
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

  Widget _field(String label, TextEditingController c, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: c,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: _muted),
              ),
            ),
          ),
        ],
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

  Widget _choiceCard(
    List<String> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < options.length; i++) ...[
            InkWell(
              onTap: () => onChanged(options[i]),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      selected == options[i]
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: selected == options[i]
                          ? _blue
                          : const Color(0xFFCBD5E1),
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected == options[i]
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != options.length - 1)
              const Divider(height: 1, indent: 52),
          ],
        ],
      ),
    );
  }
}
