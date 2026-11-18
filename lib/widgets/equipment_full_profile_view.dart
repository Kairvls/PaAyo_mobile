import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/equipment_full_profile.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF9CA3AF);
const _label = Color(0xFF6B7280);
const _blue = Color(0xFF0025CC);
const _border = Color(0xFFE5E7EB);
const _divider = Color(0xFFF1F2F4);

final _dateFmt = DateFormat("MMM d, yyyy");
final _dateTimeFmt = DateFormat("MMM d, yyyy · h:mm a");
final _pesoFmt = NumberFormat.currency(locale: "en_PH", symbol: "₱");

String? _date(DateTime? d) => d == null ? null : _dateFmt.format(d);

/// Asset information, procurement and location blocks (web "Overview" tab).
class EquipmentOverviewSections extends StatelessWidget {
  final EquipmentFullProfile profile;

  const EquipmentOverviewSections({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final life = p.usefulLifeYears;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: "Asset information",
          maxVisible: 8,
          rows: [
            ("Brand", p.brand),
            ("Model", p.model),
            ("Serial", p.serialNumber),
            ("Asset tag", p.assetTag),
            ("Classification", p.category),
            ("Qty / Mode", "${p.quantity} · ${p.trackingMode ?? "Individual"}"),
            ("Condition", p.conditionStatus),
            ("Status", p.inventoryStatus),
            ("Purchased", _date(p.boughtOn)),
            (
              "Purchase cost",
              p.purchaseCost == null ? null : _pesoFmt.format(p.purchaseCost),
            ),
            (
              "Useful life",
              life == null ? null : "$life ${life == 1 ? "year" : "years"}",
            ),
            ("Warranty", _date(p.warrantyExpiration)),
            ("Stocked / received", _date(p.stockedOn)),
            ("Stocked by", p.stockedByName),
            ("Stock lot", p.stockLotCode),
          ],
        ),
        const SizedBox(height: 18),
        _Section(
          title: "Procurement",
          rows: [
            ("Supplier", p.supplierName),
            ("Supplier type", p.supplierStoreType),
            ("Purchase order", p.purchaseOrderNumber),
            ("PO date", _date(p.purchaseOrderDate)),
            ("Receiving report", p.receivingReportNumber),
            ("Delivered", _date(p.receivingReportDate)),
            ("Received by", p.receivedBy),
            ("Received condition", p.receivingCondition),
            ("ATP / RIS", p.atpRis),
          ],
        ),
        const SizedBox(height: 18),
        _Section(
          title: "Location",
          rows: [
            ("Room", p.roomName),
            ("Zone", p.placementZone ?? p.location),
            ("QR code", p.qrCode),
            ("QR issued", _date(p.qrIssuedAt)),
          ],
        ),
      ],
    );
  }
}

/// Key lifecycle dates plus the full event timeline (web "Lifecycle" and
/// "Activity" tabs).
class EquipmentLifecycleSections extends StatefulWidget {
  final EquipmentFullProfile profile;

  const EquipmentLifecycleSections({super.key, required this.profile});

  @override
  State<EquipmentLifecycleSections> createState() =>
      _EquipmentLifecycleSectionsState();
}

class _EquipmentLifecycleSectionsState
    extends State<EquipmentLifecycleSections> {
  static const _timelinePreview = 5;
  bool _timelineExpanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final events = p.events;
    final canCollapse = events.length > _timelinePreview;
    final visibleCount = !canCollapse || _timelineExpanded
        ? events.length
        : _timelinePreview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: "Lifecycle",
          rows: [
            ("Bought", _date(p.boughtOn)),
            ("Delivered", _date(p.receivingReportDate)),
            ("Stocked", _date(p.stockedOn)),
            ("Put in room", _date(p.deployedAt)),
            ("Last moved", _date(p.lastMovedAt)),
            ("Last maintenance", _date(p.lastMaintenanceAt)),
            if (p.disposedAt != null) ("Disposed", _date(p.disposedAt)),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          "Timeline",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: const Text(
              "No recorded activity yet.",
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          )
        else ...[
          for (int i = 0; i < visibleCount; i++)
            _TimelineTile(
              event: events[i],
              isLast: i == visibleCount - 1 &&
                  (!canCollapse || _timelineExpanded),
            ),
          if (canCollapse) ...[
            const SizedBox(height: 4),
            _ShowMoreButton(
              expanded: _timelineExpanded,
              hiddenCount: events.length - _timelinePreview,
              onTap: () =>
                  setState(() => _timelineExpanded = !_timelineExpanded),
            ),
          ],
        ],
      ],
    );
  }
}

class _Section extends StatefulWidget {
  final String title;
  final List<(String, String?)> rows;

  /// When set and [rows] is longer, only this many rows show until expanded.
  final int? maxVisible;

  const _Section({
    required this.title,
    required this.rows,
    this.maxVisible,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final max = widget.maxVisible;
    final canCollapse = max != null && rows.length > max;
    final visibleCount =
        !canCollapse || _expanded ? rows.length : max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < visibleCount; i++)
                _Row(
                  label: rows[i].$1,
                  value: rows[i].$2,
                  showDivider: i < visibleCount - 1 || canCollapse,
                ),
              if (canCollapse)
                _ShowMoreButton(
                  expanded: _expanded,
                  hiddenCount: rows.length - max,
                  onTap: () => setState(() => _expanded = !_expanded),
                  inset: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;
  final bool inset;

  const _ShowMoreButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
    this.inset = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = expanded
        ? "Show less"
        : "Show $hiddenCount more";

    return Material(
      color: inset ? Colors.white : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: inset
            ? const BorderRadius.vertical(bottom: Radius.circular(14))
            : BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, inset ? 10 : 8, 14, inset ? 12 : 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final bool showDivider;

  const _Row({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final text = (value ?? "").trim();
    final empty = text.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: _divider))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                color: _label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              empty ? "—" : text,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: empty ? const Color(0xFFBBBBBB) : _ink,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final EquipmentTimelineEvent event;
  final bool isLast;

  const _TimelineTile({required this.event, required this.isLast});

  IconData get _icon {
    switch (event.type) {
      case "acquisition":
        return Icons.shopping_bag_outlined;
      case "transfer":
        return Icons.swap_horiz_rounded;
      case "maintenance":
        return Icons.build_outlined;
      case "report":
        return Icons.report_outlined;
      case "disposal":
        return Icons.delete_outline_rounded;
      case "qr":
        return Icons.qr_code_2_rounded;
      case "borrow":
        return Icons.handshake_outlined;
      case "condition":
        return Icons.health_and_safety_outlined;
      case "assignment":
        return Icons.badge_outlined;
      default:
        return Icons.add_box_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final when = event.occurredAt;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 16, color: _blue),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: _border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _label,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (when != null) _dateTimeFmt.format(when),
                      if (event.typeLabel.isNotEmpty) event.typeLabel,
                    ].join(" · "),
                    style: const TextStyle(fontSize: 11.5, color: _muted),
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
