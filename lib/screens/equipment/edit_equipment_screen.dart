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
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _page = Color(0xFFF3F3F3);
  static const _soft = Color(0xFFF7F7F7);
  static const _border = Color(0xFFE8E8E8);

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
                              "Edit details",
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
                            _field("Asset Tag", _assetTag, "e.g. AC-2024-014"),
                            _field("Brand", _brand, "e.g. Panasonic"),
                            _field("Model", _model, "e.g. CS-XN12"),
                            _field("Serial Number", _serial, "e.g. SN-88213-KX"),
                            _field(
                              "Current Location",
                              _location,
                              "Optional room or area",
                            ),
                            const SizedBox(height: 6),
                            _sectionLabel("Condition"),
                            const SizedBox(height: 12),
                            _pillChoices(
                              _conditions,
                              _condition,
                              (v) => setState(() => _condition = v),
                            ),
                            const SizedBox(height: 22),
                            _sectionLabel("Inventory Status"),
                            const SizedBox(height: 12),
                            _pillChoices(
                              _inventoryStatuses,
                              _inventoryStatus,
                              (v) => setState(() => _inventoryStatus = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _YellowSaveBar(
                        label: "Save Changes",
                        saving: _saving,
                        onPressed: _save,
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
                      "Edit Details",
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

  Widget _field(String label, TextEditingController c, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 1),
            ),
            child: TextField(
              controller: c,
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
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      );

  Widget _pillChoices(
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

class _YellowSaveBar extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onPressed;

  const _YellowSaveBar({
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: saving ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFBBF24),
          foregroundColor: const Color(0xFF111111),
          disabledBackgroundColor:
              const Color(0xFFFBBF24).withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF111111),
                  ),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }
}
