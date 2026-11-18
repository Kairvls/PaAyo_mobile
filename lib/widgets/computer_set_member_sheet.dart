import 'package:flutter/material.dart';

import '../models/computer_set_scan.dart';
import '../models/equipment.dart';

/// Bottom sheet: pick one member from a scanned computer set.
Future<Equipment?> showComputerSetMemberPicker({
  required BuildContext context,
  required ComputerSetScan computerSet,
}) {
  return showModalBottomSheet<Equipment>(
    context: context,
    // Must sit above QRScannerScreen when opened from the report flow.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      final members = computerSet.members;
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.72;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Computer set",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  computerSet.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
                if (computerSet.room != "—") ...[
                  const SizedBox(height: 4),
                  Text(
                    computerSet.room,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  "Select the equipment inside this set to continue.",
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: members.isEmpty
                      ? const Center(
                          child: Text(
                            "No equipment in this set.",
                            style: TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: members.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final e = members[i];
                            final map = i < computerSet.memberMaps.length
                                ? computerSet.memberMaps[i]
                                : const <String, dynamic>{};
                            final role = (map["computer_set_member_role"] ??
                                    map["member_role"] ??
                                    "")
                                .toString();
                            final canReport = map.containsKey("can_report")
                                ? (map["can_report"] == true ||
                                    map["can_report"] == 1)
                                : true;
                            final block =
                                map["report_block_reason"]?.toString().trim() ??
                                    "";
                            final subtitle = [
                              if (role.trim().isNotEmpty) role.trim(),
                              if (e.qrId != "—") e.qrId,
                              if (e.room != "—") e.room,
                              if (!canReport && block.isNotEmpty) block,
                            ].join(" · ");

                            return Material(
                              color: canReport
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: canReport
                                    ? () => Navigator.pop(ctx, e)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    12,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: canReport
                                              ? const Color(0xFFEAF1FF)
                                              : const Color(0xFFE5E7EB),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.devices_other_rounded,
                                          color: canReport
                                              ? const Color(0xFF002784)
                                              : const Color(0xFF9CA3AF),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.name,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: canReport
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFF9CA3AF),
                                              ),
                                            ),
                                            if (subtitle.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: canReport
                                                      ? const Color(0xFF64748B)
                                                      : const Color(0xFFEF4444),
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (canReport)
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFF94A3B8),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Report-flow picker — returns the raw member map for prefilling.
Future<Map<String, dynamic>?> showComputerSetReportMemberPicker({
  required BuildContext context,
  required ComputerSetScan computerSet,
}) async {
  final picked = await showComputerSetMemberPicker(
    context: context,
    computerSet: computerSet,
  );
  if (picked == null) return null;

  for (final m in computerSet.memberMaps) {
    final id = int.tryParse(
      (m["equipment_id"] ?? m["id"])?.toString() ?? "",
    );
    if (id == picked.id) return m;
  }
  return null;
}
