import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../equipment/equipment_profile_screen.dart';
import '../history/equipment_history_screen.dart';
import '../maintenance/record_maintenance_screen.dart';
import '../schedule/equipment_schedule_screen.dart';

/// Where to land after a successful equipment QR scan.
enum ScanDestination { profile, record, history, schedule }

enum _ScanPhase { scanning, found }

class QRScannerScreen extends StatefulWidget {
  final ScanDestination destination;

  const QRScannerScreen({
    super.key,
    this.destination = ScanDestination.profile,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  static const _missLimit = 5;
  static const _missCooldown = Duration(milliseconds: 1200);

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final MaintenanceService _service = MaintenanceService();

  late final AnimationController _lineController;

  _ScanPhase _phase = _ScanPhase.scanning;
  bool _handling = false;
  int _missCount = 0;
  String? _lastMissedCode;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code == null) return;

    // Ignore the same failed code until a different one is scanned.
    if (_lastMissedCode != null && code == _lastMissedCode) return;

    _handling = true;
    await _controller.stop();

    Equipment equipment;
    try {
      // Keep showing "Scanning…" while we hit the API.
      equipment = await _service.getEquipmentByQr(code);
    } on EquipmentNotFoundException {
      _missCount += 1;
      _lastMissedCode = code;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No equipment matches this QR code.")),
      );
      setState(() => _phase = _ScanPhase.scanning);

      if (_missCount >= _missLimit) {
        await _showTroubleSheet();
        return;
      }

      await Future<void>.delayed(_missCooldown);
      if (!mounted) return;
      _handling = false;
      await _controller.start();
      return;
    } catch (_) {
      await _resumeWithMessage(
        "Couldn't reach the server. Check your connection.",
      );
      return;
    }

    // Successful match — reset miss tracking.
    _missCount = 0;
    _lastMissedCode = null;

    if (!mounted) return;
    setState(() => _phase = _ScanPhase.found);

    // Hold the "Equipment Found" state briefly before transitioning.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _screenFor(equipment)),
    );

    // Resume scanning when the user comes back.
    if (!mounted) return;
    setState(() => _phase = _ScanPhase.scanning);
    _handling = false;
    await _controller.start();
  }

  Widget _screenFor(Equipment equipment) {
    switch (widget.destination) {
      case ScanDestination.record:
        return RecordMaintenanceScreen(equipment: equipment);
      case ScanDestination.history:
        return EquipmentHistoryScreen(equipment: equipment);
      case ScanDestination.schedule:
        return EquipmentScheduleScreen(equipment: equipment);
      case ScanDestination.profile:
        return EquipmentProfileScreen(equipment: equipment);
    }
  }

  Future<void> _resumeWithMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    setState(() => _phase = _ScanPhase.scanning);

    // Short cooldown so failed scans can't spam the API.
    await Future<void>.delayed(_missCooldown);
    if (!mounted) return;

    _handling = false;
    await _controller.start();
  }

  Future<void> _showTroubleSheet() async {
    await _controller.stop();
    if (!mounted) return;

    final keepScanning = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 40,
                  color: Color(0xFF0B2F64),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Having trouble scanning?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "No matching equipment after several scans.\n"
                  "Check lighting, hold steady, and aim at the equipment QR label.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2F64),
                    ),
                    child: const Text(
                      "Keep scanning",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Close scanner"),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (keepScanning == false) {
      Navigator.of(context).pop();
      return;
    }

    // Reset and continue — user chose to keep trying.
    _missCount = 0;
    _lastMissedCode = null;
    _handling = false;
    setState(() => _phase = _ScanPhase.scanning);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final found = _phase == _ScanPhase.found;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Dim overlay + scan window.
          _ScannerOverlay(found: found, line: _lineController),

          // Top bar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Text(
                    "Scan Equipment",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _GlassButton(
                    icon: Icons.flash_on_rounded,
                    onTap: () => _controller.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),

          // Bottom status text / found badge.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: found
                      ? Column(
                          key: const ValueKey("found"),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Equipment Found",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey("scanning"),
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            _PulsingDot(),
                            SizedBox(height: 12),
                            Text(
                              "Scanning…",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Point the camera at the equipment QR code",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
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
}

class _ScannerOverlay extends StatelessWidget {
  final bool found;
  final Animation<double> line;

  const _ScannerOverlay({required this.found, required this.line});

  @override
  Widget build(BuildContext context) {
    final accent = found ? const Color(0xFF16A34A) : Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth * 0.7;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Darken everything except the centered window.
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Frame border.
            Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),

            // Animated scan line (hidden once found).
            if (!found)
              SizedBox(
                width: side,
                height: side,
                child: AnimatedBuilder(
                  animation: line,
                  builder: (context, _) {
                    return Align(
                      alignment: Alignment(0, (line.value * 2) - 1),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF60A5FA),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF60A5FA)
                                  .withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: Color(0xFF60A5FA),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
