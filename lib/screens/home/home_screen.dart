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
      title: "Report an issue,\nfast.",
      subtitle:
          "Spotted broken or faulty equipment around campus? Snap it and send a report in seconds.",
      cta: "Open report form",
      route: "/report",
      icon: Icons.assignment_outlined,
      badgeIcon: Icons.edit_note_rounded,
    ),
    _HomeAction(
      title: "Manage every\nasset.",
      subtitle:
          "Scan equipment QR codes to track status, log maintenance, and keep everything running.",
      cta: "Open QR scanner",
      route: "/login",
      icon: Icons.qr_code_2_rounded,
      badgeIcon: Icons.sensors_rounded,
    ),
  ];

  // Reference-style palette: dark hero + warm accent button.
  static const _accent = Color(0xFFE8901E);
  static const _dark = Color(0xFF0B1220);

  late final PageController _pageController;
  late final AnimationController _meshController;
  late final AnimationController _enterController;

  late final Animation<double> _fadeIn;

  int _index = 0;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
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

  void _openSelected() {
    Navigator.pushNamed(context, _actions[_index].route);
  }

  @override
  Widget build(BuildContext context) {
    final action = _actions[_index];

    return Scaffold(
      backgroundColor: _dark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed animated dark hero background.
          AnimatedBuilder(
            animation: _meshController,
            builder: (context, _) {
              return CustomPaint(
                painter: _HeroBackgroundPainter(
                  progress: _meshController.value,
                  variant: _index,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),

          // Swipeable hero icon per action (fills the screen so you can
          // swipe anywhere on the artwork).
          PageView.builder(
            controller: _pageController,
            itemCount: _actions.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 200),
                  child: Center(
                    child: _HeroIconMark(
                      icon: _actions[i].icon,
                      badgeIcon: _actions[i].badgeIcon,
                      pulse: _meshController,
                    ),
                  ),
                ),
              );
            },
          ),

          // Dark gradient so the bottom text stays readable. Ignores touches
          // so swipes still reach the PageView beneath it.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xB30B1220),
                    Color(0xF20B1220),
                  ],
                  stops: [0.0, 0.4, 0.68, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Minimal top bar.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.handyman_rounded,
                                size: 20,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "PaAyo",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Bottom content: title, subtitle, dots, CTA.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.12),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            key: ValueKey(_index),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                action.subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 14.5,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Page dots.
                        Row(
                          children: List.generate(_actions.length, (i) {
                            final active = i == _index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              margin: const EdgeInsets.only(right: 7),
                              height: 7,
                              width: active ? 26 : 7,
                              decoration: BoxDecoration(
                                color: active
                                    ? _accent
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 22),

                        // Big rounded accent CTA.
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: FilledButton(
                            onPressed: _openSelected,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: _dark,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Row(
                                key: ValueKey(action.cta),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    action.cta,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
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
        ],
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
                  color: const Color(0xFF60A5FA).withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
            ),
            Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF93C5FD).withValues(alpha: 0.55),
                  width: 1.4,
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
                  color: const Color(0xFFE8901E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE8901E).withValues(alpha: 0.45),
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

class _HeroBackgroundPainter extends CustomPainter {
  final double progress;
  final int variant;

  _HeroBackgroundPainter({
    required this.progress,
    required this.variant,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final field = Offset.zero & size;
    final sway = math.sin(progress * 2 * math.pi) * 6;
    final shift = variant == 0 ? 0.0 : 10.0;

    // Deep dark-blue sky gradient.
    canvas.drawRect(
      field,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF13213F),
            Color(0xFF0E1A33),
            Color(0xFF0B1220),
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(field),
    );

    // Soft glow that breathes behind the hero.
    final breath =
        0.10 + 0.06 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi));
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.38),
      size.width * 0.5,
      Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: breath)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );

    _drawSkyline(
      canvas,
      size,
      offsetX: -20 + sway * 0.4 + shift,
      topRatio: 0.42,
      fill: const Color(0xFF1E40AF).withValues(alpha: 0.28),
      window: Colors.white.withValues(alpha: 0.10),
      density: 0.9,
    );
    _drawSkyline(
      canvas,
      size,
      offsetX: -8 - sway * 0.25,
      topRatio: 0.5,
      fill: const Color(0xFF0F172A).withValues(alpha: 0.5),
      window: const Color(0xFFE8901E).withValues(alpha: 0.14),
      density: 1.05,
    );
    _drawSkyline(
      canvas,
      size,
      offsetX: sway * 0.15 - shift * 0.3,
      topRatio: 0.58,
      fill: const Color(0xFF020617).withValues(alpha: 0.72),
      window: const Color(0xFF93C5FD).withValues(alpha: 0.16),
      density: 1.18,
      strong: true,
    );
  }

  void _drawSkyline(
    Canvas canvas,
    Size size, {
    required double offsetX,
    required double topRatio,
    required Color fill,
    required Color window,
    required double density,
    bool strong = false,
  }) {
    final fillPaint = Paint()..color = fill;
    final windowPaint = Paint()..color = window;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: strong ? 0.12 : 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final heights = <double>[
      0.62, 0.88, 0.74, 0.98, 0.68, 0.92, 0.8, 1.0, 0.7, 0.9, 0.66, 0.95,
    ];
    final widths = <double>[
      48, 62, 44, 74, 52, 66, 46, 80, 50, 58, 42, 68,
    ];

    double x = offsetX - 10;
    int i = 0;
    final areaTop = size.height * topRatio;
    final areaHeight = size.height - areaTop;

    while (x < size.width + 40) {
      final idx = i % heights.length;
      final width = widths[idx] * density.clamp(0.85, 1.25);
      final height = areaHeight * heights[idx];
      final top = size.height - height;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, width, height + 20),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, fillPaint);
      canvas.drawRRect(rect, stroke);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, top - 6, width + 4, 10),
          const Radius.circular(3),
        ),
        fillPaint,
      );

      final cols = width > 55 ? 3 : 2;
      final rows = height > areaHeight * 0.75 ? 10 : 7;
      final padX = width * 0.16;
      final padY = height * 0.1;
      final gapX = (width - padX * 2) / cols;
      final gapY = (height - padY * 2) / rows;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                x + padX + c * gapX + 2,
                top + padY + r * gapY + 2,
                gapX * 0.48,
                gapY * 0.4,
              ),
              const Radius.circular(2),
            ),
            windowPaint,
          );
        }
      }

      x += width + 9;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _HeroBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.variant != variant;
  }
}
