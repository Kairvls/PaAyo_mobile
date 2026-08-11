import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  final int initialPage;
  const HomeScreen({super.key, this.initialPage = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// ─────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────
class _HomeAction {
  final String eyebrow;
  final String headline;
  final String subtitle;
  final String cta;
  final String route;
  final String image;
  final IconData icon;

  const _HomeAction({
    required this.eyebrow,
    required this.headline,
    required this.subtitle,
    required this.cta,
    required this.route,
    required this.image,
    required this.icon,
  });
}

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────
class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _orange = Color(0xFFFBBF24);

  static const _actions = [
    _HomeAction(
      eyebrow:  "REPORT",
      headline: "Report Equipment\nBreakdowns",
      subtitle: "Let us know about broken furniture,\nfaulty lights, or malfunctioning tech.",
      cta:      "Report an Issue",
      route:    "/report",
      image:    "assets/images/report_issue_full_bleed.png",
      icon:     Icons.assignment_outlined,
    ),
    _HomeAction(
      eyebrow:  "MAINTENANCE",
      headline: "Monitor Maintenance\nEquipment",
      subtitle: "Scan QR codes to track status and\nlog maintenance history.",
      cta:      "Sign In",
      route:    "/login",
      image:    "assets/images/equipment_full_bleed.png",
      icon:     Icons.qr_code_2_rounded,
    ),
  ];

  late final AnimationController _enterCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  int  _index = 0;
  int  _epoch = 0;
  bool _pendingReset = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialPage.clamp(0, _actions.length - 1);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.9, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterCtrl,
      curve:  const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    ));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await Navigator.pushNamed(context, _actions[_index].route);
    if (!mounted) return;
    setState(() { _epoch++; _pendingReset = true; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _pendingReset = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a    = _actions[_index];
    final size = MediaQuery.sizeOf(context);
    final top  = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final dx = details.primaryVelocity ?? 0;
                if (dx < -200 && _index < _actions.length - 1) {
                  setState(() => _index++);
                } else if (dx > 200 && _index > 0) {
                  setState(() => _index--);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── PHOTO BLOCK ──────────────────────────────
                SizedBox(
                  height: size.height * 0.56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Full-bleed photo with animated crossfade
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim, child: child,
                        ),
                        child: Image.asset(
                          a.image,
                          key:             ValueKey(_index),
                          fit:             BoxFit.cover,
                          alignment:       _index == 1
                              ? Alignment.center
                              : Alignment.topCenter,
                          filterQuality:   FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                      // Top fade for status bar legibility
                      Positioned(
                        top: 0, left: 0, right: 0,
                        height: top + 72,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end:   Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF111111).withValues(alpha: 0.72),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Bottom fade into dark body
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        height: 120,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end:   Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                const Color(0xFF111111),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Logo + eyebrow chip — same vertical center
                      Positioned(
                        top: top + 8,
                        left: 16,
                        right: 20,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/paayo_logo_big_original.png',
                              height: 52,
                              fit: BoxFit.contain,
                            ),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              child: Container(
                                key: ValueKey(_index),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  a.eyebrow,
                                  style: const TextStyle(
                                    color:       Colors.white,
                                    fontSize:    10.5,
                                    fontWeight:  FontWeight.w700,
                                    letterSpacing: 1.6,
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

                // ── CONTENT BLOCK ─────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Headline
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child:   SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end:   Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Column(
                            key: ValueKey(_index),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.headline,
                                style: const TextStyle(
                                  color:       Colors.white,
                                  fontSize:    34,
                                  fontWeight:  FontWeight.w800,
                                  letterSpacing: -0.8,
                                  height:      1.12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                a.subtitle,
                                style: TextStyle(
                                  color:      Colors.white.withValues(alpha: 0.55),
                                  fontSize:   14.5,
                                  height:     1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Dot indicators
                        Row(
                          children: List.generate(_actions.length, (i) {
                            final active = i == _index;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _index = i),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin:   const EdgeInsets.only(right: 7),
                                height:   6,
                                width:    active ? 24 : 6,
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 20),

                        // CTA row
                        _CtaRow(
                          key:             ValueKey('$_index-$_epoch'),
                          label:           a.cta,
                          icon:            a.icon,
                          playReturnReset: _pendingReset,
                          onCompleted:     _open,
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CTA Row  (yellow arrow pill  +  text + chevrons)
// ─────────────────────────────────────────────
class _CtaRow extends StatefulWidget {
  final String                   label;
  final IconData                 icon;
  final Future<void> Function()  onCompleted;
  final bool                     playReturnReset;

  const _CtaRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onCompleted,
    this.playReturnReset = false,
  });

  @override
  State<_CtaRow> createState() => _CtaRowState();
}

class _CtaRowState extends State<_CtaRow> with TickerProviderStateMixin {
  static const _orange = Color(0xFFFBBF24);
  static const _pill   = 56.0;

  bool   _done         = false;
  bool   _introQueued  = false;
  double _dragProgress = 0.0; // 0..1, used to track swipe distance

  late final AnimationController _pulseCtrl;
  late final AnimationController _snapCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1300),
    )..addListener(() { if (mounted) setState(() {}); });

    _snapCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 280),
    );

    if (widget.playReturnReset) {
      _introQueued = true;
    } else {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  void _queueIntroIfNeeded() {
    if (!_introQueued) return;
    _introQueued = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _done = false;
      _dragProgress = 0.0;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      _pulseCtrl.repeat(reverse: true);
    });
  }

  Future<void> _trigger() async {
    if (_done) return;
    _done = true;
    _pulseCtrl.stop();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    await widget.onCompleted();
  }

  void _onDragUpdate(DragUpdateDetails d, double rowWidth) {
    if (_done) return;
    final travel = rowWidth - _pill;
    setState(() {
      _dragProgress = (_dragProgress + d.delta.dx / travel).clamp(0.0, 1.0);
    });
  }

  Future<void> _onDragEnd(double rowWidth) async {
    if (_done) return;
    if (_dragProgress >= 0.6) {
      await _trigger();
    } else {
      // snap back
      final start = _dragProgress;
      _snapCtrl.value = 0;
      _snapCtrl.addListener(() {
        if (mounted) setState(() => _dragProgress = start * (1 - _snapCtrl.value));
      });
      await _snapCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    _queueIntroIfNeeded();
    final pulse = 1.0 + _pulseCtrl.value * 0.05;

    return LayoutBuilder(builder: (ctx, box) {
      final rowWidth = box.maxWidth;
      final travel   = rowWidth - _pill;
      final thumbDx  = _dragProgress * travel;

      return GestureDetector(
        behavior:               HitTestBehavior.opaque,
        onTap:                  () => _trigger(),
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, rowWidth),
        onHorizontalDragEnd:    (_) => _onDragEnd(rowWidth),
        child: SizedBox(
          height: _pill,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Static layout: pill | label | chevrons (bottom layer)
              Row(
                children: [
                  const SizedBox(width: _pill),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:  MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color:         Colors.white,
                            fontSize:      16,
                            fontWeight:    FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Swipe or tap to continue",
                          style: TextStyle(
                            color:      Colors.white.withValues(alpha: 0.4),
                            fontSize:   11.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(3, (i) => Opacity(
                      opacity: 0.3 + i * 0.25,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size:  20,
                      ),
                    )),
                  ),
                ],
              ),

              // Trail painted OVER text so it covers label & chevrons
              if (_dragProgress > 0)
                Positioned(
                  left: 0,
                  child: Container(
                    width:  thumbDx + _pill,
                    height: _pill,
                    decoration: BoxDecoration(
                      // dimmer amber — distinct from the bright yellow thumb
                      color:        const Color(0xFF111111).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(_pill / 2),
                    ),
                  ),
                ),

              // Draggable yellow circle on top
              Positioned(
                left: thumbDx,
                child: Transform.scale(
                  scale: pulse,
                  child: Container(
                    width:      _pill,
                    height:     _pill,
                    decoration: BoxDecoration(
                      color:  _orange,
                      shape:  BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:      _orange.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset:     const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size:  22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
