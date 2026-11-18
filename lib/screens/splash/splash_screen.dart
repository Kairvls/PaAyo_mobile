import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../home/home_screen.dart';

/// Same layout as the native white splash (logo + PAAYO + tagline),
/// with only a thin loading line added — then auto home (no Go).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Same asset as `flutter_native_splash` so the handoff is seamless.
  static const String brandLogo =
      "assets/images/native_splash_paayo_logo_splash.png";

  static const Color _blue = Color(0xFF0025CC);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _navigating = false;

  late final AnimationController _loadController;
  late final AnimationController _exitController;

  late final Animation<double> _loadFade;
  late final Animation<double> _loadProgress;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _loadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadFade = CurvedAnimation(
      parent: _loadController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _loadProgress = CurvedAnimation(
      parent: _loadController,
      curve: const Interval(0.08, 1.0, curve: Curves.easeInOutCubic),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSplashSequence();
    });
  }

  Future<void> _runSplashSequence() async {
    try {
      await precacheImage(const AssetImage(SplashScreen.brandLogo), context);
    } catch (_) {}
    if (!mounted) return;

    // Brand is already on screen (matches native) — remove OS splash.
    FlutterNativeSplash.remove();

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    await _loadController.forward();
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;

    await _goHome();
  }

  Future<void> _goHome() async {
    if (_navigating || !mounted) return;
    _navigating = true;

    _exitController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 560),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _loadController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FadeTransition(
          opacity: _exitFade,
          child: SafeArea(
            // Slightly above true center — previous layout sat too low.
            child: Align(
              alignment: const Alignment(0, -0.22),
              child: SizedBox(
                width: 220,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      SplashScreen.brandLogo,
                      width: 220,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      // Sit inside the asset’s empty bottom padding, just
                      // under “Ready to repair”.
                      bottom: 22,
                      child: FadeTransition(
                        opacity: _loadFade,
                        child: Center(
                          child: _SplashLoadLine(progress: _loadProgress),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLoadLine extends StatelessWidget {
  final Animation<double> progress;

  const _SplashLoadLine({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Same width as the logo lockup above.
    return SizedBox(
      width: 140,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.value.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFFE8ECF4),
              color: SplashScreen._blue,
            ),
          );
        },
      ),
    );
  }
}
