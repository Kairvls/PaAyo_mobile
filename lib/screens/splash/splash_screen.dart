import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String fullBleedImage = "assets/images/splash_screen_bg.png";
  static const String bridgeLogo =
      "assets/images/native_splash_paayo_logo_splash.png";

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _navigating = false;
  bool _bridgeVisible = true;

  late final AnimationController _bridgeController;
  late final AnimationController _enterController;
  late final AnimationController _exitController;
  late final AnimationController _pulseController;

  late final Animation<double> _bridgeFade;
  late final Animation<double> _bridgeScale;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;

  @override
  void initState() {
    super.initState();

    // White logo overlay that matches the native splash, then fades away.
    _bridgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bridgeFade = CurvedAnimation(
      parent: _bridgeController,
      curve: Curves.easeInOutCubic,
    );
    _bridgeScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _bridgeController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

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

    // Exit: zoom burst — splash photo punches forward and fades out.
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeIn),
      ),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handoffFromNative();
    });
  }

  Future<void> _handoffFromNative() async {
    // Warm images so the reveal doesn't hitch.
    try {
      await Future.wait([
        precacheImage(const AssetImage(SplashScreen.fullBleedImage), context),
        precacheImage(const AssetImage(SplashScreen.bridgeLogo), context),
      ]);
    } catch (_) {
      // Continue even if an asset fails — bridge still covers the handoff.
    }
    if (!mounted) return;

    // Drop native splash; Flutter white+logo overlay is already showing.
    FlutterNativeSplash.remove();

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    await _bridgeController.forward();
    if (!mounted) return;

    setState(() => _bridgeVisible = false);
    await _enterController.forward();
  }

  Future<void> _goHome() async {
    if (_navigating || !mounted) return;
    _navigating = true;

    // Play exit burst, then navigate while the route transition takes over.
    _exitController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Home slides up from slightly below while fading in.
          final fadeCurve = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
          );
          final slideCurve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: fadeCurve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(slideCurve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _bridgeController.dispose();
    _enterController.dispose();
    _exitController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayStyle = _bridgeVisible && _bridgeController.value < 0.55
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: FadeTransition(
          opacity: _exitFade,
          child: ScaleTransition(
            scale: _exitScale,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Full-bleed photo (edge to edge)
                Image.asset(
                  SplashScreen.fullBleedImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: const Alignment(0, -0.2),
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) {
                    return Image.asset(
                      "assets/images/sti_sample_image.png",
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: const Alignment(0, -0.2),
                      filterQuality: FilterQuality.high,
                    );
                  },
                ),

                // Soft vignette so white text stays readable
                FadeTransition(
                  opacity: _fadeIn,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22000000),
                          Color(0x00000000),
                          Color(0x55000000),
                          Color(0xAA000000),
                        ],
                        stops: [0.0, 0.4, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),

                // Text sits on building landmarks
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final h = constraints.maxHeight;
                      final textTop = h * 0.44;

                      return Stack(
                        children: [
                          Positioned(
                            top: textTop,
                            left: 28,
                            right: 28,
                            child: FadeTransition(
                              opacity: _fadeIn,
                              child: SlideTransition(
                                position: _slideUp,
                                child: const Column(
                                  children: [
                                    Text(
                                      "Report & Manage\nCampus Equipment",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 34,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Report equipment breakdowns and manage\nequipment maintenance with a smoother workflow.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        height: 1.45,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xD9FFFFFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FadeTransition(
                                  opacity: _fadeIn,
                                  child: _GoPill(
                                    pulse: _pulseController,
                                    onSwipeUp: _goHome,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FadeTransition(
                                  opacity: _fadeIn,
                                  child: Text(
                                    "STI College Ormoc",
                                    style: TextStyle(
                                      fontSize: 12,
                                      letterSpacing: 1.4,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Native → Flutter bridge (white + PaAyo logo)
                if (_bridgeVisible)
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _bridgeController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 1.0 - _bridgeFade.value,
                          child: Transform.scale(
                            scale: _bridgeScale.value,
                            child: child,
                          ),
                        );
                      },
                      child: ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: Image.asset(
                            SplashScreen.bridgeLogo,
                            width: 220,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) {
                              return Image.asset(
                                "assets/images/native_splash_paayo_logo_original.png",
                                width: 220,
                                fit: BoxFit.contain,
                              );
                            },
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
  static const double _knob = 56;
  static const double _maxDrag = 72;
  // Arrow + gap — full swipe parks Go over the arrows at the top.
  static const double _travel = 50;

  double _drag = 0;
  Duration _dur = Duration.zero;
  bool _committed = false;

  double get _progress => (_drag / _maxDrag).clamp(0.0, 1.0);

  void _onDragUpdate(DragUpdateDetails d) {
    if (_committed) return;
    setState(() {
      _dur = Duration.zero;
      _drag = (_drag - d.delta.dy).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_committed) return;
    final v = d.primaryVelocity ?? 0;
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
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 78,
          height: 11 + _knob + _travel + 22,
          padding: const EdgeInsets.fromLTRB(11, 14, 11, 11),
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 4,
                child: AnimatedBuilder(
                  animation: widget.pulse,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -3.0 * widget.pulse.value),
                      child: Opacity(
                        opacity: (1 - _progress).clamp(0.0, 1.0),
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
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  child: AnimatedSlide(
                    duration: _dur,
                    curve: Curves.easeOut,
                    offset: Offset(0, -(_travel / _knob) * _progress),
                    child: Center(
                      child: Container(
                        width: _knob,
                        height: _knob,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Go",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
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
    );
  }
}
