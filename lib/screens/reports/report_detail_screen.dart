import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../../models/maintenance_report.dart';
import '../../services/maintenance_service.dart';
import '../../widgets/report_photo_attachment.dart';
import '../../widgets/sweet_alert.dart';

class ReportDetailScreen extends StatefulWidget {
  final int reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _bg = Color(0xFFF3F4F6);
  static const _statusAction = Color(0xFF0025CC);

  final MaintenanceService _service = MaintenanceService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _remarks = TextEditingController();
  final Set<int> _selectedItemIds = {};

  late Future<MaintenanceReport?> _future;
  bool _submitting = false;
  int? _personnelId;
  File? _image;
  String? _selectedStatus;
  String? _statusValidationError;
  String? _equipmentValidationError;

  @override
  void initState() {
    super.initState();
    _loadPersonnelId();
    _reload();
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _loadPersonnelId() async {
    final raw = await _storage.read(key: "user_id");
    if (!mounted) return;
    setState(() {
      _personnelId = int.tryParse(raw ?? "");
    });
  }

  void _reload() {
    setState(() {
      _future = _service.getReport(widget.reportId);
      _selectedItemIds.clear();
      _selectedStatus = null;
      _image = null;
      _statusValidationError = null;
      _equipmentValidationError = null;
    });
  }

  void _clearValidationErrors() {
    if (_statusValidationError == null && _equipmentValidationError == null) {
      return;
    }
    setState(() {
      _statusValidationError = null;
      _equipmentValidationError = null;
    });
  }

  Widget _inlineValidationText(String? message) {
    if (message == null || message.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _allowedStatuses(MaintenanceReport report) {
    switch (report.status) {
      case "Pending":
        return const ["Processing", "Rejected"];
      case "Processing":
        return const ["Resolved", "For Replacement"];
      default:
        return const [];
    }
  }

  bool _canUpdate(MaintenanceReport report) {
    if (_allowedStatuses(report).isEmpty) return false;
    if (report.status == "Processing") {
      return report.assignedPersonnelId != null &&
          report.assignedPersonnelId == _personnelId;
    }
    return true;
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Pending":
        return const Color(0xFFF59E0B);
      case "Processing":
        return const Color(0xFF7C3AED);
      case "Resolved":
        return const Color(0xFF16A34A);
      case "For Replacement":
        return const Color(0xFFEA580C);
      case "Rejected":
        return const Color(0xFFDC2626);
      default:
        return _muted;
    }
  }

  bool _mustSelectEquipment(MaintenanceReport report) {
    return report.status == "Processing" &&
        report.isMultiItem &&
        report.openItems.isNotEmpty;
  }

  bool _canSubmitProcessingUpdate(MaintenanceReport report) {
    if (report.openItems.isEmpty) return false;
    if (!_mustSelectEquipment(report)) return true;
    return _selectedItemIds.isNotEmpty;
  }

  String _selectedEquipmentSummary(MaintenanceReport report) {
    if (_mustSelectEquipment(report) && _selectedItemIds.isNotEmpty) {
      return report.items
          .where((item) => _selectedItemIds.contains(item.id))
          .map((item) => item.equipmentName)
          .join(", ");
    }

    return report.equipmentDisplay;
  }

  Future<bool> _confirmStatusUpdate({
    required MaintenanceReport report,
    required String status,
  }) async {
    final equipmentLine = _selectedEquipmentSummary(report);
    final remarks = _remarks.text.trim();

    String title;
    String message;
    IconData icon;
    Color iconBg;
    Color iconColor;
    String confirmLabel;

    switch (status) {
      case "Processing":
        title = "Start processing?";
        message = report.isMultiItem
            ? "You will be assigned to handle this report with ${report.items.length} equipment items. You can resolve or replace each item separately afterward."
            : "You will be assigned to handle this report. This action cannot be undone.";
        icon = Icons.play_arrow_rounded;
        iconBg = const Color(0xFFEFF6FF);
        iconColor = const Color(0xFF2563EB);
        confirmLabel = "Start";
        break;
      case "Rejected":
        title = "Reject report?";
        message =
            "This will reject the entire report for $equipmentLine. This action cannot be undone.";
        icon = Icons.block_rounded;
        iconBg = const Color(0xFFFEF2F2);
        iconColor = const Color(0xFFDC2626);
        confirmLabel = "Reject";
        break;
      case "Resolved":
        title = "Mark as resolved?";
        message = _mustSelectEquipment(report)
            ? "Mark the selected equipment as resolved:\n$equipmentLine"
            : "Mark this report as resolved for $equipmentLine.";
        icon = Icons.check_circle_outline_rounded;
        iconBg = const Color(0xFFECFDF5);
        iconColor = const Color(0xFF16A34A);
        confirmLabel = "Resolve";
        break;
      case "For Replacement":
        title = "Send for replacement?";
        message = _mustSelectEquipment(report)
            ? "Submit the selected equipment for replacement:\n$equipmentLine\n\nThis may create a procurement request."
            : "Submit this report for replacement. This may create a procurement request.";
        icon = Icons.sync_problem_rounded;
        iconBg = const Color(0xFFFFF7ED);
        iconColor = const Color(0xFFEA580C);
        confirmLabel = "Submit";
        break;
      default:
        title = "Update status?";
        message = "Change this report to $status?";
        icon = Icons.info_outline_rounded;
        iconBg = const Color(0xFFF1F5F9);
        iconColor = _ink;
        confirmLabel = "Confirm";
    }

    if (remarks.isNotEmpty &&
        (status == "Resolved" ||
            status == "For Replacement" ||
            status == "Rejected")) {
      message = "$message\n\nRemarks: $remarks";
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: status == "Rejected"
                              ? const Color(0xFFDC2626)
                              : _statusAction,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  Future<void> _submitStatus(
    MaintenanceReport report,
    String status,
  ) async {
    if (_submitting) return;

    if (status.isEmpty) {
      setState(() {
        _statusValidationError = "Select a status first.";
        _equipmentValidationError = null;
      });
      return;
    }

    if (_mustSelectEquipment(report) && _selectedItemIds.isEmpty) {
      setState(() {
        _equipmentValidationError =
            "Select at least one equipment item before updating status.";
        _statusValidationError = null;
      });
      return;
    }

    _clearValidationErrors();

    final confirmed = await _confirmStatusUpdate(
      report: report,
      status: status,
    );
    if (!confirmed || !mounted) return;

    final usePartial = report.status == "Processing" &&
        report.isMultiItem &&
        _selectedItemIds.isNotEmpty &&
        (status == "Resolved" || status == "For Replacement");

    setState(() => _submitting = true);

    try {
      final response = await _service.updateReportStatus(
        reportId: report.id,
        status: status,
        remarks: _remarks.text.trim(),
        reportItemIds: usePartial ? _selectedItemIds.toList() : null,
        proofImage: _image,
      );

      if (!mounted) return;

      final data = response.data;
      final ok = response.statusCode != null &&
          response.statusCode! < 400 &&
          data is Map &&
          data["success"] == true;

      if (!ok) {
        final message = data is Map
            ? (data["message"]?.toString() ?? "Unable to update report.")
            : "Unable to update report.";
        await showSweetAlertError(
          context: context,
          title: "Unable to update",
          message: message,
        );
        return;
      }

      final message = (data["message"]?.toString() ?? "Report updated.");
      final partial = data is Map && data["partial"] == true;

      await showSweetAlertSuccess(
        context: context,
        title: sweetAlertTitleForStatus(status, partial: partial),
        message: message,
      );

      if (!mounted) return;

      _remarks.clear();
      _image = null;

      if (data is Map && data["report"] is Map) {
        final updated = MaintenanceReport.fromJson(
          Map<String, dynamic>.from(data["report"] as Map),
        );
        if (updated.openItems.isEmpty &&
            !const {"Pending", "Processing"}.contains(updated.status)) {
          Navigator.pop(context, true);
          return;
        }
      }

      if (partial || report.isMultiItem || status == "Processing") {
        _reload();
        return;
      }

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      await showSweetAlertError(
        context: context,
        title: "Update failed",
        message: "Failed to update report. Please try again.",
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startProcessing(MaintenanceReport report) async {
    await _submitStatus(report, "Processing");
  }

  Future<void> _promptProcessingUpdate(MaintenanceReport report) async {
    final status = _selectedStatus;
    if (status == null || status.isEmpty) {
      setState(() {
        _statusValidationError = "Select a status first.";
        _equipmentValidationError = null;
      });
      return;
    }

    await _submitStatus(report, status);
  }

  String _updateSubtitle(MaintenanceReport report) {
    if (report.status == "Processing" && report.isMultiItem) {
      return "Resolve fixable items and send others for replacement — one decision at a time.";
    }
    return "Confirm before every status change. Updates cannot be undone on mobile.";
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("MMM d, yyyy · h:mm a");

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          "Report Details",
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ),
      body: FutureBuilder<MaintenanceReport?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final report = snapshot.data;
          if (report == null) {
            return const Center(child: Text("Report not found."));
          }

          final allowed = _allowedStatuses(report);
          final canUpdate = _canUpdate(report);
          final openItems = report.openItems;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _InfoCard(
                title: report.ticketCode,
                subtitle: report.equipmentDisplay,
                children: [
                  _RowLabel("Status", report.status),
                  _RowLabel("Urgency", report.urgency),
                  _RowLabel("Issue", report.issueDisplay),
                  if (report.room.isNotEmpty) _RowLabel("Room", report.room),
                  if (report.reporterName != null)
                    _RowLabel("Reporter", report.reporterName!),
                  _RowLabel("Assigned", report.assignedHandler),
                  if (report.submittedAt != null)
                    _RowLabel(
                      "Submitted",
                      dateFmt.format(report.submittedAt!),
                    ),
                  if (report.description != null &&
                      report.description!.trim().isNotEmpty)
                    _RowLabel("Notes", report.description!),
                  if (report.hasMixedItemStatuses)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Items on this ticket can have different outcomes (e.g. one resolved, another for replacement).",
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: "Equipment items · ${report.items.length}",
                subtitle: report.isMultiItem
                    ? "Each item can be handled separately once processing starts."
                    : "Single equipment report",
                children: report.items
                    .map((item) => _EquipmentItemCard(
                          item: item,
                          statusColor: _statusColor(item.status),
                        ))
                    .toList(),
              ),
              if (canUpdate) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  title: "Update status",
                  subtitle: _updateSubtitle(report),
                  children: [
                    if (report.status == "Processing" &&
                        report.isMultiItem &&
                        openItems.isNotEmpty) ...[
                      Text(
                        "Select at least one equipment item this status update applies to.",
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...openItems.map(
                        (item) => _SelectableEquipmentTile(
                          item: item,
                          selected: _selectedItemIds.contains(item.id),
                          statusColor: _statusColor(item.status),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedItemIds.add(item.id);
                              } else {
                                _selectedItemIds.remove(item.id);
                              }
                              _equipmentValidationError = null;
                            });
                          },
                        ),
                      ),
                      _inlineValidationText(_equipmentValidationError),
                      const SizedBox(height: 14),
                    ],
                    if (report.status == "Pending") ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting
                              ? null
                              : () => _startProcessing(report),
                          style: FilledButton.styleFrom(
                            backgroundColor: _statusAction,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Start Processing",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => _submitStatus(report, "Rejected"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Reject Report",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.isMultiItem
                            ? "After starting, you can resolve or send individual equipment for replacement."
                            : "Starting this report will make you responsible for handling it.",
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ] else if (report.status == "Processing") ...[
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: "Change status",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _statusValidationError != null
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        hint: const Text("Select status"),
                        items: allowed
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() {
                                  _selectedStatus = value;
                                  _statusValidationError = null;
                                }),
                      ),
                      _inlineValidationText(_statusValidationError),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _remarks,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Remarks (optional)",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ReportPhotoAttachment(
                        image: _image,
                        enabled: !_submitting,
                        onChanged: (file) => setState(() => _image = file),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting ||
                                  !_canSubmitProcessingUpdate(report)
                              ? null
                              : () => _promptProcessingUpdate(report),
                          style: FilledButton.styleFrom(
                            backgroundColor: _statusAction,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Update Status",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (!canUpdate && allowed.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    report.status == "Processing"
                        ? "Only the assigned personnel can update this report."
                        : "This report cannot be updated from its current status.",
                    style: const TextStyle(color: _muted),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EquipmentItemCard extends StatelessWidget {
  final MaintenanceReportItem item;
  final Color statusColor;

  const _EquipmentItemCard({
    required this.item,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.equipmentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                      ),
                    ),
                    if (item.issue != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Issue: ${item.issue}",
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusChip(label: item.status, color: statusColor),
            ],
          ),
          if (!item.isListed) ...[
            const SizedBox(height: 8),
            const Text(
              "Manual entry — no inventory record linked.",
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              "Full profile",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            _DetailGrid(rows: item.profileRows),
          ],
        ],
      ),
    );
  }
}

class _SelectableEquipmentTile extends StatelessWidget {
  final MaintenanceReportItem item;
  final bool selected;
  final Color statusColor;
  final ValueChanged<bool?> onChanged;

  const _SelectableEquipmentTile({
    required this.item,
    required this.selected,
    required this.statusColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: selected, onChanged: onChanged),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.equipmentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    _StatusChip(label: item.status, color: statusColor),
                  ],
                ),
                if (item.issue != null)
                  Text(
                    "Current: ${item.status} · ${item.issue}",
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                if (item.isListed) ...[
                  const SizedBox(height: 8),
                  _DetailGrid(
                    rows: item.profileRows.take(8).toList(),
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final List<MapEntry<String, String>> rows;
  final bool compact;

  const _DetailGrid({
    required this.rows,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: rows.map((row) {
            final wide = row.key == "Asset tag";
            final width = wide
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.key.toUpperCase(),
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.value,
                    maxLines: wide ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String label;
  final String value;

  const _RowLabel(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
