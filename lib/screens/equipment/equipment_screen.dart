import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../utils/equipment_icon.dart';
import '../../widgets/chart_tooltip.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';

class EquipmentScreen extends StatefulWidget {
  final String? initialSearch;
  final bool attentionOnly;

  /// When embedded as a bottom-nav tab there is nothing to pop back to, so the
  /// AppBar should not render a back arrow.
  final bool embedded;

  const EquipmentScreen({
    super.key,
    this.initialSearch,
    this.attentionOnly = false,
    this.embedded = false,
  });

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF9CA3AF);
  static const _pageBg = Colors.white;

  final MaintenanceService _service = MaintenanceService();
  late final TextEditingController _search;

  late Future<List<Equipment>> _future;

  bool get _attentionOnly => widget.attentionOnly;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSearch?.trim() ?? "";
    _search = TextEditingController(text: initial);
    _reload(initial.isEmpty ? null : initial);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _needsAttention(Equipment e) {
    final s = e.status.toLowerCase();
    return s.contains("maintenance") || s.contains("replace");
  }

  bool _isActive(Equipment e) {
    final s = e.status.toLowerCase();
    return s == "active" || s.contains("good") || s == "available";
  }

  /// Mobile only manages QR-tagged equipment; drop anything without a QR code.
  bool _hasQr(Equipment e) {
    final q = e.qrId.trim();
    return q.isNotEmpty && q != "—";
  }

  void _reload([String? search]) {
    setState(() {
      _future = _service.listEquipment(search: search).then((items) {
        final qrOnly = items.where(_hasQr).toList();
        if (!_attentionOnly) return qrOnly;
        return qrOnly.where(_needsAttention).toList();
      });
    });
  }

  Future<void> _open(Equipment equipment) async {
    await promptScanToManage(
      context,
      equipmentName: equipment.name,
      destination: ScanDestination.profile,
    );
  }

  Future<void> _openScanner() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const QRScannerScreen(destination: ScanDestination.profile),
      ),
    ).then((_) {
      if (mounted) _reload(_search.text);
    });
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k >= 10 ? "${k.round()}K" : "${k.toStringAsFixed(1)}K";
    }
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  /// Buckets inventory status into chart segments.
  List<_ChartSlice> _statusSlices(List<Equipment> all) {
    var active = 0;
    var maintenance = 0;
    var replacement = 0;
    var borrowed = 0;
    var disposed = 0;
    var other = 0;

    for (final e in all) {
      final s = e.status.toLowerCase();
      if (s.contains("replace")) {
        replacement++;
      } else if (s.contains("maintenance")) {
        maintenance++;
      } else if (s.contains("borrow")) {
        borrowed++;
      } else if (s.contains("dispos")) {
        disposed++;
      } else if (s == "active" || s.contains("good") || s == "available") {
        active++;
      } else {
        other++;
      }
    }

    final slices = <_ChartSlice>[
      if (maintenance > 0)
        _ChartSlice(
          maintenance.toDouble(),
          const Color(0xFF1A1A1A),
          label: "Maintenance",
        ),
      if (active > 0)
        _ChartSlice(
          active.toDouble(),
          const Color(0xFF0025CC),
          label: "Active",
        ),
      if (replacement > 0)
        _ChartSlice(
          replacement.toDouble(),
          const Color(0xFF67E8F9),
          label: "Replacement",
        ),
      if (borrowed > 0)
        _ChartSlice(
          borrowed.toDouble(),
          const Color(0xFFD4D4D8),
          label: "Borrowed",
        ),
      if (disposed > 0)
        _ChartSlice(
          disposed.toDouble(),
          const Color(0xFFE8E8EA),
          label: "Disposed",
        ),
      if (other > 0)
        _ChartSlice(
          other.toDouble(),
          const Color(0xFFF1F1F3),
          label: "Other",
        ),
    ];

    if (slices.isEmpty) {
      return [_ChartSlice(1, const Color(0xFFE8E8EA), label: "Empty")];
    }

    // Emphasize (protrude) the largest segment — like the thick black arc.
    var maxI = 0;
    for (var i = 1; i < slices.length; i++) {
      if (slices[i].value > slices[maxI].value) maxI = i;
    }
    return [
      for (var i = 0; i < slices.length; i++)
        _ChartSlice(
          slices[i].value,
          slices[i].color,
          label: slices[i].label,
          emphasized: i == maxI,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<List<Equipment>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: "Couldn't load equipment",
                  subtitle: "Check your connection and try again.",
                  actionLabel: "Retry",
                  onAction: () => _reload(_search.text),
                );
              }

              final items = snap.data ?? [];
              final total = items.length;
              final active = items.where(_isActive).length;
              final attention = items.where(_needsAttention).length;
              final activePct =
                  total == 0 ? 0.0 : (active / total) * 100;
              final slices = _statusSlices(items);

              return RefreshIndicator(
                onRefresh: () async => _reload(_search.text),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                        child: Row(
                          children: [
                            if (!widget.embedded)
                              IconButton(
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: _ink,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                _attentionOnly
                                    ? "Needs Attention"
                                    : "Equipment",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: "Scan for equipment",
                              onPressed: _openScanner,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: _buildPillSearch(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          children: [
                            _InteractiveDonut(
                              slices: slices,
                              center: Container(
                                width: 124,
                                height: 124,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.10),
                                      blurRadius: 22,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "${activePct.round()}%",
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                        height: 1.05,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "Active units",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w400,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricItem(
                                    icon: Icons.inventory_2_outlined,
                                    value: _formatCount(total),
                                    label: "Total",
                                  ),
                                ),
                                Expanded(
                                  child: _MetricItem(
                                    icon: Icons.check_circle_outline_rounded,
                                    value: _formatCount(active),
                                    label: "Active",
                                  ),
                                ),
                                Expanded(
                                  child: _MetricItem(
                                    icon: Icons.build_circle_outlined,
                                    value: _formatCount(attention),
                                    label: "Attention",
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmpty(),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          22,
                          16,
                          widget.embedded ? 100 : 28,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final e = items[i];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: i < items.length - 1 ? 12 : 0,
                                ),
                                child: _EquipmentCard(
                                  equipment: e,
                                  onTap: () => _open(e),
                                ),
                              );
                            },
                            childCount: items.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPillSearch() {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _ink, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _reload,
              style: const TextStyle(
                color: _ink,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: "Search equipment...",
                hintStyle: TextStyle(
                  color: _muted,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: const Color(0xFFEEF0F4),
          ),
          IconButton(
            tooltip: "Search",
            onPressed: () => _reload(_search.text),
            icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final searching = _search.text.trim().isNotEmpty;
    if (_attentionOnly) {
      return _EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: "No equipment needs attention",
        subtitle:
            "Nothing is under maintenance or for replacement right now.",
        actionLabel: "Scan QR",
        onAction: () => Navigator.pushNamed(context, "/scanner"),
      );
    }
    if (searching) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: "No matches found",
        subtitle:
            "No QR-tagged equipment matches your search. Try another keyword or scan a QR code.",
        actionLabel: "Scan QR",
        onAction: () => Navigator.pushNamed(context, "/scanner"),
      );
    }
    return _EmptyState(
      icon: Icons.qr_code_2_rounded,
      title: "No QR-tagged equipment yet",
      subtitle:
          "Generate QR codes on the web to enroll equipment for maintenance monitoring. Only QR-tagged items appear here.",
      actionLabel: "Scan QR",
      onAction: () => Navigator.pushNamed(context, "/scanner"),
    );
  }
}

class _ChartSlice {
  final double value;
  final Color color;
  final String label;
  final bool emphasized;

  const _ChartSlice(
    this.value,
    this.color, {
    this.label = "",
    this.emphasized = false,
  });
}

class _InteractiveDonut extends StatefulWidget {
  final List<_ChartSlice> slices;
  final Widget center;

  const _InteractiveDonut({
    required this.slices,
    required this.center,
  });

  @override
  State<_InteractiveDonut> createState() => _InteractiveDonutState();
}

class _InteractiveDonutState extends State<_InteractiveDonut> {
  int? _focus;

  void _onTap(Offset local, Size size) {
    final total = widget.slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final delta = local - center;
    final r = delta.distance;
    final outer = math.min(size.width, size.height) / 2;
    if (r < outer * 0.35 || r > outer) {
      setState(() => _focus = null);
      return;
    }
    var angle = math.atan2(delta.dy, delta.dx);
    // Convert from atan2 (0 at +x) to our start (-pi/2 = top).
    angle = (angle + math.pi / 2);
    if (angle < 0) angle += math.pi * 2;
    var start = 0.0;
    for (var i = 0; i < widget.slices.length; i++) {
      final sweep = (widget.slices[i].value / total) * (math.pi * 2);
      if (angle >= start && angle < start + sweep) {
        setState(() => _focus = i);
        return;
      }
      start += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 228,
      width: 228,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return TapRegion(
            onTapOutside: (_) {
              if (_focus != null) setState(() => _focus = null);
            },
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _onTap(d.localPosition, size),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: size,
                  painter: _DonutChartPainter(
                    slices: widget.slices,
                    strokeWidth: 26,
                    emphasizeExtra: 10,
                    focusIndex: _focus,
                  ),
                ),
                widget.center,
                if (_focus != null && _focus! < widget.slices.length)
                  Positioned(
                    top: 8,
                    child: ChartTooltipBubble(
                      title: widget.slices[_focus!].label,
                      rows: [
                        ChartTooltipRow(
                          color: widget.slices[_focus!].color,
                          label: "Count",
                          value: chartFmtValue(widget.slices[_focus!].value),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MetricItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF2FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0025CC), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final Equipment equipment;
  final VoidCallback onTap;

  const _EquipmentCard({
    required this.equipment,
    required this.onTap,
  });

  String get _subtitle {
    final parts = <String>[];
    if (equipment.category.trim().isNotEmpty &&
        equipment.category != "—") {
      parts.add(equipment.category);
    } else if (equipment.brand.trim().isNotEmpty &&
        equipment.brand != "—") {
      parts.add(equipment.brand);
    }
    if (equipment.model.trim().isNotEmpty && equipment.model != "—") {
      parts.add(equipment.model);
    }
    return parts.isEmpty ? "Equipment" : parts.join(" · ");
  }

  String get _rightValue {
    if (equipment.room.trim().isNotEmpty && equipment.room != "—") {
      return equipment.room;
    }
    if (equipment.assetTag.trim().isNotEmpty &&
        equipment.assetTag != "—") {
      return equipment.assetTag;
    }
    return "—";
  }

  String get _conditionLabel {
    final c = equipment.condition.trim();
    if (c.isEmpty || c == "—") return "Unknown";
    return c;
  }

  String get _metaHint {
    if (equipment.assetTag.trim().isNotEmpty &&
        equipment.assetTag != "—") {
      return "(${equipment.assetTag})";
    }
    if (equipment.qrId.trim().isNotEmpty && equipment.qrId != "—") {
      return "(${equipment.qrId})";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F1F3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: thumbnail | title + subtitle | right value
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFFF3F4F6),
                      alignment: Alignment.center,
                      child: EquipmentGraphic(
                        name: equipment.name,
                        category: equipment.category,
                        size: 34,
                        fallbackColor: const Color(0xFF0025CC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1C1E),
                            height: 1.2,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF9CA3AF),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Text(
                      _rightValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1C1E),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Bottom: Overall Ratings + star row | status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Overall Ratings",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFB0B5BD),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _conditionLabel,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1C1E),
                                      ),
                                    ),
                                    if (_metaHint.isNotEmpty)
                                      TextSpan(
                                        text: " $_metaHint",
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      equipment.status,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0025CC),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<_ChartSlice> slices;
  final double strokeWidth;
  final double emphasizeExtra;
  final int? focusIndex;

  _DonutChartPainter({
    required this.slices,
    this.strokeWidth = 26,
    this.emphasizeExtra = 10,
    this.focusIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerPad = emphasizeExtra + 2;
    final baseOuter = math.min(size.width, size.height) / 2 - outerPad;
    final baseInner = baseOuter - strokeWidth;

    var start = -math.pi / 2;

    void drawSlice(_ChartSlice slice, double startAngle, double sweep,
        {required bool focused}) {
      if (sweep <= 0) return;
      final thick =
          slice.emphasized ? strokeWidth + emphasizeExtra : strokeWidth;
      final outer =
          slice.emphasized ? baseOuter + emphasizeExtra : baseOuter;
      final mid = outer - thick / 2;
      final rect = Rect.fromCircle(center: center, radius: mid);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick
        ..strokeCap = StrokeCap.butt
        ..color = focused || focusIndex == null
            ? slice.color
            : slice.color.withValues(alpha: 0.35)
        ..isAntiAlias = true;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
    }

    var angle = start;
    for (var i = 0; i < slices.length; i++) {
      final sweep = (slices[i].value / total) * (math.pi * 2);
      if (!slices[i].emphasized) {
        drawSlice(slices[i], angle, sweep, focused: focusIndex == i);
      }
      angle += sweep;
    }

    angle = start;
    for (var i = 0; i < slices.length; i++) {
      final sweep = (slices[i].value / total) * (math.pi * 2);
      if (slices[i].emphasized) {
        drawSlice(slices[i], angle, sweep, focused: focusIndex == i);
      }
      angle += sweep;
    }

    final holeRadius = baseInner - 1;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, holeRadius + 2, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.emphasizeExtra != emphasizeExtra ||
        oldDelegate.focusIndex != focusIndex;
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
