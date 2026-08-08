import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _navigating = false;

  late final AnimationController _enterController;
  late final AnimationController _pulseController;
  late final AnimationController _skylineController;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _skylineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _fadeIn = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _enterController.forward();
  }

  Future<void> _goHome() async {
    if (_navigating || !mounted) return;
    _navigating = true;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    _skylineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed building scene
          AnimatedBuilder(
            animation: _skylineController,
            builder: (context, _) {
              return CustomPaint(
                painter: _SplashBuildingPainter(
                  progress: _skylineController.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),

          // Soft vignette for text readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.15),
                  Colors.transparent,
                  const Color(0xFF0F172A).withValues(alpha: 0.55),
                  const Color(0xFF0F172A).withValues(alpha: 0.78),
                ],
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                children: [
                  const Spacer(),

                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        children: [
                          const Text(
                            "Care For Your\nCampus Journey",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            "Report issues and maintain equipment\nwith a smoother workflow.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 42),

                  FadeTransition(
                    opacity: _fadeIn,
                    child: _GoPill(
                      pulse: _pulseController,
                      onSwipeUp: _goHome,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "STI College Ormoc",
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
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

class _GoPill extends StatefulWidget {
  final Animation<double> pulse;
  final VoidCallback onSwipeUp;

  const _GoPill({
    required this.pulse,
    required this.onSwipeUp,
  });

  @override
  State<_GoPill> createState() => _GoPillState();
}

class _GoPillState extends State<_GoPill> {
  static const double _knob = 52;
  // Finger travel (px) needed to commit and navigate.
  static const double _maxDrag = 64;

  double _drag = 0; // 0.._maxDrag, accumulated upward drag
  Duration _dur = Duration.zero;
  bool _committed = false;

  double get _progress => (_drag / _maxDrag).clamp(0.0, 1.0);

  void _onDragUpdate(DragUpdateDetails d) {
    if (_committed) return;
    setState(() {
      _dur = Duration.zero;
      // Dragging up gives negative dy, which increases the accumulated drag.
      _drag = (_drag - d.delta.dy).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_committed) return;
    final v = d.primaryVelocity ?? 0; // negative = flick up
    final commit = _progress >= 0.7 || v < -600;
    if (commit) {
      setState(() {
        _committed = true;
        _dur = const Duration(milliseconds: 150);
        _drag = _maxDrag;
      });
      widget.onSwipeUp();
    } else {
      setState(() {
        _dur = const Duration(milliseconds: 220);
        _drag = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 74,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hint arrows pulse and fade as you drag the button up.
              AnimatedBuilder(
                animation: widget.pulse,
                builder: (context, child) {
                  final lift = -3.0 * widget.pulse.value;
                  return Transform.translate(
                    offset: Offset(0, lift),
                    child: Opacity(
                      opacity: (1 - _progress) * 0.85 + 0.15,
                      child: child,
                    ),
                  );
                },
                child: const Icon(
                  Icons.keyboard_double_arrow_up_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),

              // The Go button itself is swipable upward.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: AnimatedSlide(
                  duration: _dur,
                  curve: Curves.easeOut,
                  // Lift the knob up to half its height as you drag.
                  offset: Offset(0, -_progress * 0.5),
                  child: Container(
                    width: _knob,
                    height: _knob,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF0F172A),
                        AppTheme.accentYellow,
                        _progress * 0.9,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Go",
                      style: TextStyle(
                        color: Color.lerp(
                          Colors.white,
                          const Color(0xFF0F172A),
                          _progress,
                        ),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBuildingPainter extends CustomPainter {
  final double progress;

  _SplashBuildingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final sway = math.sin(progress * 2 * math.pi) * 6;

    // Deep blue sky gradient
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1E3A8A),
          Color(0xFF2563EB),
          Color(0xFF60A5FA),
          Color(0xFFDBEAFE),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    // Soft sun glow
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.22),
      54,
      Paint()
        ..color = AppTheme.accentYellow.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );

    _drawSkyline(
      canvas,
      size,
      offsetX: -20 + sway * 0.4,
      topRatio: 0.28,
      fill: const Color(0xFF1E40AF).withValues(alpha: 0.45),
      window: Colors.white.withValues(alpha: 0.12),
      density: 0.9,
    );

    _drawSkyline(
      canvas,
      size,
      offsetX: -8 - sway * 0.25,
      topRatio: 0.34,
      fill: const Color(0xFF0F172A).withValues(alpha: 0.55),
      window: AppTheme.accentYellow.withValues(alpha: 0.14),
      density: 1.05,
    );

    _drawSkyline(
      canvas,
      size,
      offsetX: sway * 0.15,
      topRatio: 0.42,
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

      // Roof
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
  bool shouldRepaint(covariant _SplashBuildingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
