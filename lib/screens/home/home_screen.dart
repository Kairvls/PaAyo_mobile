import 'dart:math' as math;

import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeAction {
  final String title;
  final String subtitle;
  final String cta;
  final String route;
  final IconData icon;
  final IconData badgeIcon;

  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.route,
    required this.icon,
    required this.badgeIcon,
  });
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  static const _actions = [
    _HomeAction(
      title: "Submit Report",
      subtitle: "Broken or faulty equipment around campus.",
      cta: "Open report form",
      route: "/report",
      icon: Icons.assignment_outlined,
      badgeIcon: Icons.edit_note_rounded,
    ),
    _HomeAction(
      title: "Manage Equipment",
      subtitle: "Scan QR codes to track and update assets.",
      cta: "Open QR scanner",
      route: "/login",
      icon: Icons.qr_code_2_rounded,
      badgeIcon: Icons.sensors_rounded,
    ),
  ];

  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFF60A5FA);
  static const _yellow = Color(0xFFFACC15);
  static const _bg = Color(0xFF050507);

  late final PageController _pageController;
  late final AnimationController _meshController;
  late final AnimationController _enterController;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  int _index = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.12, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _enterController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _meshController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final next = index.clamp(0, _actions.length - 1);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _openSelected() {
    Navigator.pushNamed(context, _actions[_index].route);
  }

  @override
  Widget build(BuildContext context) {
    final action = _actions[_index];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Column(
              children: [
                // Logo header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Image.asset(
                    "assets/images/paayo_logo.png",
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),

                // Hero: blueprint skyline + icon mark
                Expanded(
                  flex: 11,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _meshController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _BlueprintSkylinePainter(
                              progress: _meshController.value,
                              variant: _index,
                            ),
                            child: const SizedBox.expand(),
                          );
                        },
                      ),
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _actions.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) {
                          return Center(
                            child: _HeroIconMark(
                              icon: _actions[i].icon,
                              badgeIcon: _actions[i].badgeIcon,
                              pulse: _meshController,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Title carousel
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Row(
                    children: [
                      _RoundNavButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: _index > 0 ? () => _goTo(_index - 1) : null,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            key: ValueKey(_index),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              children: [
                                Text(
                                  action.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.9,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  action.subtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_actions.length, (i) {
                                    final active = i == _index;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      width: active ? 18 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? _yellow
                                            : Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _RoundNavButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: _index < _actions.length - 1
                            ? () => _goTo(_index + 1)
                            : null,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Blue CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      onPressed: _openSelected,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          action.cta,
                          key: ValueKey(action.cta),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroIconMark extends StatelessWidget {
  final IconData icon;
  final IconData badgeIcon;
  final Animation<double> pulse;

  const _HeroIconMark({
    required this.icon,
    required this.badgeIcon,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = math.sin(pulse.value * 2 * math.pi);
        return Transform.scale(
          scale: 1 + (t * 0.02),
          child: child,
        );
      },
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    blurRadius: 48,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Container(
              width: 188,
              height: 188,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF60A5FA).withValues(alpha: 0.28),
                  width: 1.2,
                ),
              ),
            ),
            Container(
              width: 142,
              height: 142,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF0B1220),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF93C5FD).withValues(alpha: 0.4),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 62,
                color: const Color(0xFFE0F2FE),
              ),
            ),
            Positioned(
              right: 30,
              bottom: 36,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF050507),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  badgeIcon,
                  size: 20,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundNavButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.28,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.9),
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlueprintSkylinePainter extends CustomPainter {
  final double progress;
  final int variant;

  _BlueprintSkylinePainter({
    required this.progress,
    required this.variant,
  });

  static const _line = Color(0xFF60A5FA);
  static const _bright = Color(0xFF93C5FD);
  static const _deep = Color(0xFF1D4ED8);

  @override
  void paint(Canvas canvas, Size size) {
    final field = Offset.zero & size;

    canvas.drawRect(
      field,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF050507),
            Color(0xFF0A1628),
            Color(0xFF050507),
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(field),
    );

    // Soft blue glow behind skyline (breathes)
    final breath = 0.16 + 0.06 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi));
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.42),
      size.width * 0.42,
      Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: breath)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42),
    );

    _drawGrid(canvas, size);
    _drawMovingGuides(canvas, size);

    final sway = math.sin(progress * 2 * math.pi) * 5;
    final shift = variant == 0 ? 0.0 : 8.0;

    _drawSkyline(
      canvas,
      size,
      offsetX: -10 + sway * 0.55 + shift,
      baseY: size.height * 0.92,
      maxH: size.height * 0.88,
      density: 0.92,
      alpha: 0.35,
      layer: 0,
    );
    _drawSkyline(
      canvas,
      size,
      offsetX: 6 - sway * 0.35,
      baseY: size.height * 0.94,
      maxH: size.height * 0.92,
      density: 1.05,
      alpha: 0.55,
      layer: 1,
    );
    _drawSkyline(
      canvas,
      size,
      offsetX: sway * 0.2 - shift * 0.3,
      baseY: size.height * 0.96,
      maxH: size.height * 0.96,
      density: 1.15,
      alpha: 0.85,
      strong: true,
      layer: 2,
    );

    _drawScanSweep(canvas, size);

    // Fade into chrome
    canvas.drawRect(
      field,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF050507).withValues(alpha: 0.25),
            Colors.transparent,
            Colors.transparent,
            const Color(0xFF050507).withValues(alpha: 0.88),
          ],
          stops: const [0.0, 0.08, 0.7, 1.0],
        ).createShader(field),
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _line.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;

    const step = 22.0;
    final gridTop = size.height * 0.12;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, gridTop), Offset(x, size.height), grid);
    }
    for (double y = gridTop; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  /// Slow dashed construction guides that drift.
  void _drawMovingGuides(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = _bright.withValues(alpha: 0.14)
      ..strokeWidth = 1.0;

    final drift = progress * size.width;
    final y1 = size.height * 0.22;
    final y2 = size.height * 0.55;
    _dashedHLine(canvas, y1, size.width, drift, guide);
    _dashedHLine(canvas, y2, size.width, -drift * 0.7, guide);

    final x1 = (progress * size.width * 1.2) % (size.width + 40) - 20;
    _dashedVLine(canvas, x1, size.height * 0.12, size.height * 0.96, guide);
  }

  void _dashedHLine(
    Canvas canvas,
    double y,
    double width,
    double offset,
    Paint paint,
  ) {
    const dash = 10.0;
    const gap = 8.0;
    double x = -((offset % (dash + gap)) + dash + gap);
    while (x < width + dash) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  void _dashedVLine(
    Canvas canvas,
    double x,
    double y0,
    double y1,
    Paint paint,
  ) {
    const dash = 8.0;
    const gap = 7.0;
    double y = y0;
    while (y < y1) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + dash, y1)), paint);
      y += dash + gap;
    }
  }

  /// Glowing blueprint scan band sweeping across the city.
  void _drawScanSweep(Canvas canvas, Size size) {
    final x = (progress * (size.width + 120)) - 60;

    final band = Rect.fromLTWH(x - 28, size.height * 0.1, 56, size.height * 0.86);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            _bright.withValues(alpha: 0.07),
            _bright.withValues(alpha: 0.2),
            _bright.withValues(alpha: 0.07),
            Colors.transparent,
          ],
        ).createShader(band),
    );

    canvas.drawLine(
      Offset(x, size.height * 0.1),
      Offset(x, size.height * 0.96),
      Paint()
        ..color = _bright.withValues(alpha: 0.55)
        ..strokeWidth = 1.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );

    // Secondary horizontal scan
    final y = size.height * (0.14 + progress * 0.72);
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = _line.withValues(alpha: 0.22)
        ..strokeWidth = 1.1,
    );
  }

  void _drawSkyline(
    Canvas canvas,
    Size size, {
    required double offsetX,
    required double baseY,
    required double maxH,
    required double density,
    required double alpha,
    required int layer,
    bool strong = false,
  }) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 1.25 : 0.9
      ..color = (strong ? _bright : _line).withValues(alpha: alpha);

    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _deep.withValues(alpha: alpha * 0.45);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = _deep.withValues(alpha: alpha * 0.08);

    final litBlue = Paint()
      ..style = PaintingStyle.fill
      ..color = _bright.withValues(alpha: 0.35);

    final heights = <double>[
      0.58, 0.82, 0.7, 0.98, 0.64, 0.9, 0.76, 1.0, 0.66, 0.88, 0.72, 0.96,
    ];
    final widths = <double>[
      34, 46, 30, 54, 38, 48, 32, 60, 36, 44, 28, 52,
    ];

    double x = offsetX - 8;
    int i = 0;

    while (x < size.width + 40) {
      final idx = i % heights.length;
      final w = widths[idx] * density.clamp(0.85, 1.25);
      // Subtle vertical breathe so towers feel alive
      final lift = math.sin((progress * 2 * math.pi) + i * 0.55 + layer) * 3.5;
      final h = maxH * heights[idx] + lift;
      final top = baseY - h;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, w, h + 8),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, stroke);

      // Window grid with soft blue twinkle
      final cols = w > 46 ? 3 : 2;
      final rows = h > maxH * 0.7 ? 14 : 9;
      final padX = w * 0.16;
      final padY = h * 0.1;
      final gapX = (w - padX * 2) / cols;
      final gapY = (h - padY * 2) / rows;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final win = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x + padX + c * gapX + 1.5,
              top + padY + r * gapY + 1.5,
              gapX * 0.45,
              gapY * 0.38,
            ),
            const Radius.circular(1.2),
          );
          canvas.drawRRect(win, soft);

          final phase =
              progress * 2 * math.pi + i * 1.3 + r * 0.4 + c * 0.9 + layer;
          if (strong && math.sin(phase) > 0.72) {
            canvas.drawRRect(win, litBlue);
          }
        }
      }

      // Floor lines
      for (int f = 1; f < rows; f++) {
        final fy = top + padY + f * gapY;
        canvas.drawLine(
          Offset(x + 3, fy),
          Offset(x + w - 3, fy),
          soft,
        );
      }

      x += w + 8;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintSkylinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.variant != variant;
  }
}
