import 'package:flutter/material.dart';

/// One stop of a [CoachTour]: the widget under [targetKey] gets highlighted
/// and a speech bubble explains it.
class CoachStep {
  final GlobalKey targetKey;
  final String title;
  final String body;

  const CoachStep({
    required this.targetKey,
    required this.title,
    required this.body,
  });
}

/// Game-style guided tour: dims the screen, spotlights one field at a time and
/// advances when the user taps anywhere. Steps whose target isn't on screen
/// (not built, or zero height) are skipped.
class CoachTour {
  CoachTour._();

  /// Resolves `true` when the user reached the end, `false` when skipped.
  static Future<bool> show(BuildContext context, List<CoachStep> steps) async {
    final finished = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => _CoachOverlay(steps: steps),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    return finished ?? false;
  }
}

class _CoachOverlay extends StatefulWidget {
  final List<CoachStep> steps;

  const _CoachOverlay({required this.steps});

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  static const _blue = Color(0xFF0025CC);
  static const _blueSoft = Color(0xFFF3F6FF);
  static const _yellow = Color(0xFFFFF200);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF6B7280);

  int _index = 0;
  Rect? _rect;
  bool _moving = true;
  late final List<CoachStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = widget.steps.where((step) => _isVisible(step)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrent());
  }

  bool _isVisible(CoachStep step) {
    final box = step.targetKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize && box.size.height > 4;
  }

  Future<void> _focusCurrent() async {
    if (_index >= _steps.length) {
      _finish(true);
      return;
    }

    final targetContext = _steps[_index].targetKey.currentContext;
    if (targetContext == null) {
      _index++;
      return _focusCurrent();
    }

    setState(() => _moving = true);
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
    if (!mounted) return;

    final box = _steps[_index].targetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      _index++;
      return _focusCurrent();
    }

    setState(() {
      _rect = (box.localToGlobal(Offset.zero) & box.size).inflate(6);
      _moving = false;
    });
  }

  void _next() {
    if (_moving) return;
    _index++;
    _focusCurrent();
  }

  void _finish(bool finished) {
    if (!mounted) return;
    Navigator.of(context).pop(finished);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final rect = _rect;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: rect),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) => CustomPaint(
                    painter: _SpotlightPainter(hole: value),
                  ),
                ),
              ),
              if (rect != null && !_moving)
                _buildBubble(rect, size, padding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(Rect rect, Size size, EdgeInsets padding) {
    final step = _steps[_index];
    final isLast = _index == _steps.length - 1;
    final below = rect.center.dy < size.height * 0.55;
    const gap = 14.0;
    const arrowSize = 10.0;
    final arrowLeft = (rect.center.dx - arrowSize).clamp(32.0, size.width - 52);

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _blueSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: _yellow, width: 2),
                ),
                child: Image.asset(
                  "assets/images/paayo_logo_original.png",
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: _blue,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "STEP ${_index + 1} OF ${_steps.length}",
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.body,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (!isLast)
                TextButton(
                  onPressed: () => _finish(false),
                  style: TextButton.styleFrom(
                    foregroundColor: _muted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text(
                    "Skip tour",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const Spacer(),
              Text(
                isLast ? "Tap anywhere to finish" : "Tap anywhere to continue",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isLast ? Icons.check_circle_rounded : Icons.touch_app_rounded,
                size: 16,
                color: _blue,
              ),
            ],
          ),
        ],
      ),
    );

    return Positioned(
      left: 16,
      right: 16,
      top: below ? rect.bottom + gap : null,
      bottom: below ? null : size.height - rect.top + gap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (below) _arrow(arrowLeft - 16, up: true),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (below
                      ? size.height - rect.bottom - padding.bottom
                      : rect.top - padding.top) -
                  gap -
                  arrowSize -
                  8,
            ),
            child: SingleChildScrollView(child: bubble),
          ),
          if (!below) _arrow(arrowLeft - 16, up: false),
        ],
      ),
    );
  }

  Widget _arrow(double left, {required bool up}) {
    return Padding(
      padding: EdgeInsets.only(left: left < 0 ? 0 : left),
      child: CustomPaint(
        size: const Size(20, 10),
        painter: _ArrowPainter(up: up),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;

  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final target = hole;
    if (target != null) {
      final rrect = RRect.fromRectAndRadius(target, const Radius.circular(18));
      overlay
        ..addRRect(rrect)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(
        overlay,
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.68),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFFFFF200)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else {
      canvas.drawPath(
        overlay,
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.68),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.hole != hole;
}

class _ArrowPainter extends CustomPainter {
  final bool up;

  _ArrowPainter({required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (up) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.up != up;
}
