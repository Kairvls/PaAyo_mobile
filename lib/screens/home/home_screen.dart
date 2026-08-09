import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  /// 0 = Report an issue, 1 = Manage every asset.
  final int initialPage;

  const HomeScreen({super.key, this.initialPage = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeAction {
  final String title;
  final String eyebrow;
  final String subtitle;
  final String cta;
  final String route;
  final String image;
  final IconData icon;

  const _HomeAction({
    required this.title,
    required this.eyebrow,
    required this.subtitle,
    required this.cta,
    required this.route,
    required this.image,
    required this.icon,
  });
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _actions = [
    _HomeAction(
      title: "Report an issue,\nfast.",
      eyebrow: "REPORT",
      subtitle: "Take the first step to keep campus equipment working.",
      cta: "Swipe to open report",
      route: "/report",
      image: "assets/images/report_issue_full_bleed.png",
      icon: Icons.assignment_outlined,
    ),
    _HomeAction(
      title: "Manage every\nasset.",
      eyebrow: "MAINTENANCE",
      subtitle: "Scan QR codes to track status and log maintenance.",
      cta: "Swipe to sign in",
      route: "/login",
      image: "assets/images/manage_equipment_full_bleed.jpg",
      icon: Icons.qr_code_2_rounded,
    ),
  ];

  late final PageController _pageController;
  late final AnimationController _enterController;
  late final Animation<double> _fadeIn;

  int _index = 0;
  int _swipeEpoch = 0;
  bool _pendingSwipeReset = false;

  @override
  void initState() {
    super.initState();

    _index = widget.initialPage.clamp(0, _actions.length - 1);
    _pageController = PageController(initialPage: _index);

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOut,
    );
    _enterController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  Future<void> _openSelected() async {
    await Navigator.pushNamed(context, _actions[_index].route);
    if (!mounted) return;
    setState(() {
      _swipeEpoch++;
      _pendingSwipeReset = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _pendingSwipeReset = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final action = _actions[_index];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: FadeTransition(
          opacity: _fadeIn,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _actions.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  return Image.asset(
                    _actions[i].image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    gaplessPlayback: true,
                  );
                },
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x330F172A),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xB30F172A),
                        Color(0xF20F172A),
                      ],
                      stops: [0.0, 0.22, 0.42, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Image.asset(
                        "assets/images/paayo_logo_white.png",
                        height: 78,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          "assets/images/paayo_logo_second.png",
                          height: 78,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
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
                                    begin: const Offset(0, 0.08),
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
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 1,
                                      color: Colors.white.withValues(alpha: 0.55),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      action.eyebrow,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2.4,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 28,
                                      height: 1,
                                      color: Colors.white.withValues(alpha: 0.55),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  action.subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 14.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: List.generate(_actions.length, (i) {
                              final active = i == _index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin: const EdgeInsets.only(right: 7),
                                height: 6,
                                width: active ? 22 : 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          _SwipeToContinue(
                            key: ValueKey('$_index-$_swipeEpoch'),
                            label: action.cta,
                            icon: action.icon,
                            playReturnReset: _pendingSwipeReset,
                            onCompleted: _openSelected,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeToContinue extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onCompleted;
  final bool playReturnReset;

  const _SwipeToContinue({
    super.key,
    required this.label,
    required this.icon,
    required this.onCompleted,
    this.playReturnReset = false,
  });

  @override
  State<_SwipeToContinue> createState() => _SwipeToContinueState();
}

class _SwipeToContinueState extends State<_SwipeToContinue>
    with TickerProviderStateMixin {
  static const _blue = Color(0xFF2563EB);
  static const _height = 64.0;
  static const _thumb = 48.0;
  static const _pad = 8.0;

  double _drag = 0;
  double _maxDragValue = 0;
  bool _completed = false;
  bool _introQueued = false;

  late final AnimationController _slideController;
  late final AnimationController _thumbPulseController;

  double _maxDrag(double width) =>
      (width - (_pad * 2) - _thumb).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() => _drag = _slideController.value.clamp(0.0, _maxDragValue));
      });

    _thumbPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    if (widget.playReturnReset) {
      _introQueued = true;
    } else {
      _thumbPulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _thumbPulseController.dispose();
    super.dispose();
  }

  Future<void> _springTo(double target, {double velocity = 0}) async {
    await _slideController.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 220, damping: 17),
        _slideController.value,
        target,
        velocity,
      ),
    );
  }

  void _queueIntroIfNeeded(double maxDrag) {
    if (!_introQueued || maxDrag <= 0) return;
    _introQueued = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _maxDragValue = maxDrag;
      _completed = false;
      _slideController.value = maxDrag;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      await _springTo(0, velocity: -900);
      if (!mounted) return;
      _thumbPulseController.repeat(reverse: true);
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_completed) return;
    _thumbPulseController.stop();
    _thumbPulseController.value = 0;
    _slideController.stop();
    _maxDragValue = maxDrag;
    final next = (_drag + details.delta.dx).clamp(0.0, maxDrag);
    _slideController.value = next;
  }

  Future<void> _onDragEnd(double maxDrag) async {
    if (_completed) return;
    _maxDragValue = maxDrag;
    final progress = maxDrag <= 0 ? 0.0 : _drag / maxDrag;
    if (progress >= 0.85) {
      _completed = true;
      _thumbPulseController.stop();
      // Snap to the end instantly, then open the page with no spring delay.
      _slideController.value = maxDrag;
      setState(() => _drag = maxDrag);
      await widget.onCompleted();
    } else {
      await _springTo(0, velocity: -400);
      if (!mounted) return;
      _thumbPulseController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = _maxDrag(constraints.maxWidth);
        _maxDragValue = maxDrag;
        _queueIntroIfNeeded(maxDrag);

        final progress = maxDrag <= 0 ? 0.0 : (_drag / maxDrag).clamp(0.0, 1.0);
        final pulse = 1 + (_thumbPulseController.value * 0.045);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
          onHorizontalDragEnd: (_) => _onDragEnd(maxDrag),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: _height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: (_pad * 2 + _thumb) + _drag,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _blue.withValues(alpha: 0.08 + progress * 0.22),
                              _blue.withValues(alpha: 0.18 + progress * 0.28),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Opacity(
                        opacity: (1 - progress * 1.25).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(-8 * progress, 0),
                          child: Row(
                            children: [
                              const SizedBox(width: _thumb),
                              Expanded(
                                child: Text(
                                  widget.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_double_arrow_right_rounded,
                                color: Colors.white.withValues(alpha: 0.85),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _pad + _drag,
                      top: _pad,
                      child: Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: _thumb,
                          height: _thumb,
                          decoration: BoxDecoration(
                            color: _blue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _blue.withValues(
                                  alpha: 0.28 + progress * 0.25,
                                ),
                                blurRadius: 12 + progress * 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            progress > 0.82
                                ? Icons.check_rounded
                                : widget.icon,
                            color: Colors.white,
                            size: 22,
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
      },
    );
  }
}
