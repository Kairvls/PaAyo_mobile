import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/equipment.dart';
import '../../models/equipment_full_profile.dart';
import '../../services/maintenance_service.dart';
import '../../widgets/equipment_full_profile_view.dart';
import '../qr/qr_scanner_screen.dart';

/// View-only equipment profile opened from the equipment list.
///
/// Managing the unit (record fix, edit, schedule) still requires scanning its
/// QR code on-site; this page only shows the full asset profile.
class EquipmentDetailsScreen extends StatefulWidget {
  final Equipment equipment;

  const EquipmentDetailsScreen({super.key, required this.equipment});

  @override
  State<EquipmentDetailsScreen> createState() => _EquipmentDetailsScreenState();
}

class _EquipmentDetailsScreenState extends State<EquipmentDetailsScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF9CA3AF);
  static const _blue = Color(0xFF0025CC);
  static const _accent = Color(0xFFFFF200);
  static const _page = Color(0xFFF3F4F6);
  static const _line = Color(0xFFEEEEEE);

  final MaintenanceService _service = MaintenanceService();
  late Future<EquipmentFullProfile> _future;
  int _tab = 0;

  Equipment get _eq => widget.equipment;

  @override
  void initState() {
    super.initState();
    _future = _service.getEquipmentProfile(_eq.id);
  }

  void _reload() {
    setState(() => _future = _service.getEquipmentProfile(_eq.id));
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains("dispose")) return const Color(0xFFEF4444);
    if (s.contains("replace")) return const Color(0xFFEA580C);
    if (s.contains("maintenance")) return const Color(0xFFD97706);
    if (s.contains("borrow")) return const Color(0xFF38BDF8);
    return const Color(0xFF22C55E);
  }

  Future<void> _copyQr(String qr) async {
    await Clipboard.setData(ClipboardData(text: qr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("QR ID copied"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          destination: ScanDestination.profile,
          expectedEquipmentId: _eq.id,
          expectedEquipmentName: _eq.name,
          expectedQr: _eq.qrId,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _page,
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
                    "Equipment Details",
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
            child: RefreshIndicator(
              color: _blue,
              onRefresh: () async {
                _reload();
                try {
                  await _future;
                } catch (_) {}
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
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
                      FutureBuilder<EquipmentFullProfile>(
                        future: _future,
                        builder: (context, snapshot) =>
                            _buildHeader(snapshot.data),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _Tab(
                            label: "Overview",
                            selected: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          ),
                          const SizedBox(width: 18),
                          _Tab(
                            label: "Lifecycle",
                            selected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                        ],
                      ),
                      const Divider(height: 1, color: _line),
                      const SizedBox(height: 16),
                      FutureBuilder<EquipmentFullProfile>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: _blue,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return _buildError();
                          }
                          final profile = snapshot.data!;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _tab == 0
                                ? EquipmentOverviewSections(
                                    key: const ValueKey("overview"),
                                    profile: profile,
                                  )
                                : EquipmentLifecycleSections(
                                    key: const ValueKey("lifecycle"),
                                    profile: profile,
                                  ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _openScanner,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded,
                          size: 18, color: _accent),
                      SizedBox(width: 10),
                      Text(
                        "Scan to manage",
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(EquipmentFullProfile? profile) {
    String pick(String? loaded, String fallback) {
      final v = loaded?.trim();
      return (v == null || v.isEmpty) ? fallback : v;
    }

    final name = pick(profile?.name, _eq.name);
    final category = pick(profile?.category, _eq.category);
    final room = pick(profile?.roomName, _eq.room);
    final status = pick(profile?.inventoryStatus, _eq.status);
    final qr = pick(profile?.qrCode, _eq.qrId);
    final statusColor = _statusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category == "—" ? "Equipment" : category,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (room != "—") ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: _blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            room,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (status != "—") ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Material(
          color: _blue,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => _copyQr(qr),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "QR ID",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.6),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          qr,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.copy_rounded,
                        color: Colors.white, size: 17),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 34, color: _muted),
          const SizedBox(height: 10),
          const Text(
            "Couldn't load the full profile.",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _ink,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _reload,
            style: TextButton.styleFrom(foregroundColor: _blue),
            child: const Text(
              "Try again",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected
                    ? const Color(0xFF111827)
                    : const Color(0xFFAAAAAA),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2.5,
              width: selected ? 26 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF200),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
