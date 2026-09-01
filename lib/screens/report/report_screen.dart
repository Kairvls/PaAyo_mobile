import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class PriorityOption {
  final String label;
  final String value;
  final String description;

  const PriorityOption({
    required this.label,
    required this.value,
    required this.description,
  });
}

enum _EquipmentItemType { listed, manual }

class _ReportEquipmentItem {
  final _EquipmentItemType type;
  final int? id;
  final String displayLabel;
  final String issue;
  final String? manualName;
  final String? openReportTicket;
  /// Raw equipment fields for uniqueness details (long-press).
  final Map<String, dynamic>? details;

  const _ReportEquipmentItem({
    required this.type,
    required this.displayLabel,
    required this.issue,
    this.id,
    this.manualName,
    this.openReportTicket,
    this.details,
  });
}

class _ReportScreenState extends State<ReportScreen> {
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF8A8A8A);
  static const _soft = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF111111);
  static const _chip = Color(0xFFF3F4F6);
  static const _page = Color(0xFFFFFFFF);
  static const _amber = Color(0xFFFBBF24);
  static const _panel = Color(0xFF0F172A);
  static const _border = Color(0xFFE5E7EB);
  static const _radius = 8.0;

  static const int _preferredDateMinDaysAhead = 2;
  static const int _nonUrgentReminderGraceDays = 3;

  Timer? _issueSearchTimer;
  Timer? _locationSearchTimer;
  Timer? _equipmentSearchTimer;
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController equipmentController = TextEditingController();

  bool reporterVerified = false;
  String reporterName = "";
  final ApiService api = ApiService();
  Timer? _verifyTimer;
  bool isCheckingReporter = false;
  String? reporterError;
  bool equipmentNotListed = false;
  String priority = "Non-Urgent";
  DateTime? preferredActionDate;

  List<dynamic> suggestedIssues = [];
  int? selectedSuggestedIssueId;
  String? selectedSuggestedIssueName;
  bool showAllGlobalIssues = false;

  List<dynamic> rooms = [];
  int? selectedRoomId;
  String? selectedLocation;

  List<dynamic> equipment = [];
  String? selectedEquipmentLabel;
  int? selectedEquipmentId;
  Map<String, dynamic>? selectedEquipmentDetails;

  final List<_ReportEquipmentItem> selectedItems = [];

  final List<PriorityOption> priorities = const [
    PriorityOption(
      label: "Non Urgent",
      value: "Non-Urgent",
      description: "Minor issue or repair concern",
    ),
    PriorityOption(
      label: "Urgent",
      value: "Urgent",
      description: "Immediate maintenance required",
    ),
  ];

  File? selectedImage;

  String? employeeIdError;
  String? locationError;
  String? equipmentError;
  String? issueError;
  String? descriptionError;
  String? preferredDateError;
  String? itemsError;

  final employeeKey = GlobalKey();
  final locationKey = GlobalKey();
  final equipmentKey = GlobalKey();
  final issueKey = GlobalKey();
  final descriptionKey = GlobalKey();
  final itemsKey = GlobalKey();
  final preferredDateKey = GlobalKey();

  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  DateTime get _earliestPreferredDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(const Duration(days: _preferredDateMinDaysAhead));
  }

  List<dynamic> get visibleSuggestedIssues {
    if (!equipmentNotListed) return suggestedIssues;
    if (showAllGlobalIssues) return suggestedIssues;
    return suggestedIssues.take(5).toList();
  }

  String formatEquipmentLabel(dynamic item) {
    final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final name = (map["equipment_name"]?.toString() ?? "Equipment").trim();
    final parts = <String>[];

    final assetTag = (map["equipment_asset_tag"]?.toString() ?? "").trim();
    final serial = (map["equipment_serial_number"]?.toString() ?? "").trim();
    final brandModel = [
      map["equipment_brand_name"]?.toString() ?? "",
      map["equipment_model"]?.toString() ?? "",
    ].map((p) => p.trim()).where((p) => p.isNotEmpty).join(" ");
    final zone = (map["equipment_placement_zone"]?.toString() ?? "").trim();

    if (assetTag.isNotEmpty) {
      parts.add("Tag: $assetTag");
    } else if (serial.isNotEmpty) {
      parts.add("SN: $serial");
    }

    if (brandModel.isNotEmpty) parts.add(brandModel);
    if (zone.isNotEmpty) parts.add(zone);

    final id = map["equipment_id"];
    if (parts.isEmpty && id != null) {
      parts.add("#$id");
    }

    final openReportTicket = _openReportTicketOf(map);
    if (openReportTicket != null) {
      parts.add("Open report: $openReportTicket");
    }

    return parts.isEmpty ? name : "$name · ${parts.join(" · ")}";
  }

  int? _equipmentIdOf(dynamic item) {
    if (item is! Map) return null;
    return int.tryParse(item["equipment_id"]?.toString() ?? "");
  }

  String? _openReportTicketOf(dynamic item) {
    if (item is! Map) return null;
    final ticket = item["open_report_ticket_code"]?.toString().trim() ?? "";
    return ticket.isEmpty ? null : ticket;
  }

  Set<int> get _addedEquipmentIds => selectedItems
      .where((e) => e.type == _EquipmentItemType.listed && e.id != null)
      .map((e) => e.id!)
      .toSet();

  List<dynamic> get _availableEquipment => equipment.where((item) {
        final id = _equipmentIdOf(item);
        if (id == null) return true;
        return !_addedEquipmentIds.contains(id);
      }).toList();

  Map<String, dynamic>? _detailsFromEquipment(dynamic item) {
    if (item is! Map) return null;
    return Map<String, dynamic>.from(item);
  }

  List<(String, String)> _uniquenessRows({
    Map<String, dynamic>? details,
    String? displayLabel,
    String? issue,
    String? manualName,
    bool isManual = false,
  }) {
    final rows = <(String, String)>[];
    final map = details ?? <String, dynamic>{};

    void add(String label, dynamic value) {
      final text = value?.toString().trim() ?? "";
      if (text.isEmpty || text == "null" || text == "—") return;
      rows.add((label, text));
    }

    if (isManual) {
      add("Equipment name", manualName ?? displayLabel);
      add("Entry type", "Manual entry");
    } else {
      add("Name", map["equipment_name"] ?? displayLabel);
      add("Asset tag", map["equipment_asset_tag"]);
      add("Serial number", map["equipment_serial_number"]);
      add("Brand", map["equipment_brand_name"]);
      add("Model", map["equipment_model"]);
      add("Placement zone", map["equipment_placement_zone"]);
      add("Equipment ID", map["equipment_id"]);
      add("Open report", map["open_report_ticket_code"]);
      add("Report status", map["open_report_status"]);
    }

    if (issue != null && issue.trim().isNotEmpty) {
      add("Issue", issue);
    }

    if (rows.isEmpty && (displayLabel ?? "").trim().isNotEmpty) {
      add("Label", displayLabel);
    }

    return rows;
  }

  Future<void> showEquipmentDetailsDialog({
    required String title,
    Map<String, dynamic>? details,
    String? displayLabel,
    String? issue,
    String? manualName,
    bool isManual = false,
  }) async {
    final rows = _uniquenessRows(
      details: details,
      displayLabel: displayLabel,
      issue: issue,
      manualName: manualName,
      isManual: isManual,
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x660F172A),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: const BorderSide(color: _border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: _ink,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Hold to verify uniqueness",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  const Text(
                    "No additional details available.",
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: rows.map((row) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    row.$1,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    row.$2,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_radius),
                      ),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? get _draftIssueText {
    final suggested = selectedSuggestedIssueName?.trim() ?? "";
    if (suggested.isNotEmpty) return suggested;
    final details = descriptionController.text.trim();
    if (details.isNotEmpty) return details;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isNonUrgent = priority == "Non-Urgent";

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _page,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(
            color: _border,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Material(
              color: _page,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius),
                side: const BorderSide(color: _border),
              ),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(_radius),
                onTap: () => Navigator.maybePop(context),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_rounded, size: 20, color: _ink),
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 8,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Report an issue",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.6,
                color: _ink,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Broken or faulty campus equipment",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                "CAMPUS REPORT",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Maintenance Report",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Report room, facility, or equipment concerns.",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
            const SizedBox(height: 22),

            // Employee ID
            _buildSectionTitle("Employee ID"),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: employeeKey,
              child: _softCard(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: TextField(
                  controller: employeeIdController,
                  decoration: _minimalInputDecoration(
                    hintText: "Enter employee ID",
                    errorText: employeeIdError,
                    prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                    contentPadding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
                  ),
                  onChanged: (_) {
                    setState(() {
                      employeeIdError = null;
                      reporterError = null;
                    });
                    _verifyTimer?.cancel();
                    _verifyTimer = Timer(
                      const Duration(milliseconds: 600),
                      verifyReporter,
                    );
                    if (employeeIdController.text.trim().isEmpty) {
                      setState(() {
                        reporterVerified = false;
                        reporterName = "";
                        reporterError = null;
                        isCheckingReporter = false;
                      });
                    } else {
                      setState(() => isCheckingReporter = true);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statusDot(),
                const SizedBox(width: 8),
                Expanded(child: _reporterStatusText()),
              ],
            ),

            const SizedBox(height: 22),

            // Location & equipment draft
            _buildSectionTitle("Location & equipment"),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: locationKey,
              child: _softCard(
                child: Column(
                  children: [
                    _selectRow(
                      icon: Icons.location_on_rounded,
                      iconColor: _blue,
                      value: selectedLocation,
                      placeholder: "Select location",
                      errorText: locationError,
                      onTap: () {
                        showSelectionBottomSheet(
                          title: "Select Location",
                          items: rooms,
                          selectedItem: selectedRoomId,
                          icon: Icons.location_on_outlined,
                          label: (room) => room["location"]?.toString() ?? "",
                          idOf: (room) =>
                              int.tryParse(room["room_id"]?.toString() ?? ""),
                          onSelected: (room) {
                            locationError = null;
                            setState(() {
                              selectedLocation = room["location"]?.toString();
                              selectedRoomId = int.tryParse(
                                room["room_id"]?.toString() ?? "",
                              );
                              selectedEquipmentLabel = null;
                              selectedEquipmentId = null;
                              selectedEquipmentDetails = null;
                              selectedSuggestedIssueId = null;
                              selectedSuggestedIssueName = null;
                              suggestedIssues.clear();
                              equipmentController.clear();
                              selectedItems.clear();
                              itemsError = null;
                            });
                            if (selectedRoomId != null) {
                              loadEquipment(selectedRoomId!);
                            }
                          },
                        );
                      },
                    ),
                    _rowDivider(),
                    KeyedSubtree(
                      key: equipmentKey,
                      child: equipmentNotListed
                          ? _textInputRow(
                              icon: Icons.devices_other_rounded,
                              iconColor: _blue,
                              controller: equipmentController,
                              hint: "Enter equipment name",
                              errorText: equipmentError,
                              onChanged: (_) {
                                setState(() => equipmentError = null);
                              },
                            )
                          : _selectRow(
                              icon: Icons.devices_other_rounded,
                              iconColor: _blue,
                              value: selectedEquipmentLabel,
                              placeholder: "Select equipment",
                              errorText: equipmentError,
                              onTap: () {
                                if (selectedRoomId == null) {
                                  setState(() {
                                    locationError =
                                        "Please select a location first.";
                                  });
                                  scrollToField(locationKey);
                                  return;
                                }
                                showSelectionBottomSheet(
                                  title: "Select Equipment",
                                  items: _availableEquipment,
                                  selectedItem: selectedEquipmentId,
                                  icon: Icons.computer_rounded,
                                  label: formatEquipmentLabel,
                                  idOf: _equipmentIdOf,
                                  enableLongPressDetails: true,
                                  onSelected: (item) {
                                    equipmentError = null;
                                    final id = _equipmentIdOf(item);
                                    setState(() {
                                      selectedEquipmentLabel =
                                          formatEquipmentLabel(item);
                                      selectedEquipmentId = id;
                                      selectedEquipmentDetails =
                                          _detailsFromEquipment(item);
                                      selectedSuggestedIssueId = null;
                                      selectedSuggestedIssueName = null;
                                    });
                                    if (id != null) loadSuggestedIssues(id);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _softCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SwitchListTile(
                      value: equipmentNotListed,
                      onChanged: (value) async {
                        setState(() {
                          equipmentNotListed = value;
                          selectedEquipmentLabel = null;
                          selectedEquipmentId = null;
                          selectedEquipmentDetails = null;
                          equipmentController.clear();
                          selectedSuggestedIssueId = null;
                          selectedSuggestedIssueName = null;
                          equipmentError = null;
                          issueError = null;
                        });
                        if (value) {
                          await loadGlobalSuggestedIssues();
                        } else {
                          setState(() => suggestedIssues.clear());
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: _ink,
                      title: const Text(
                        "Equipment not listed",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _ink,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_radius),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: addEquipmentItem,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      "Add",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            KeyedSubtree(
              key: itemsKey,
              child: selectedItems.isEmpty
                  ? _softCard(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        itemsError ??
                            "Select equipment, then choose a suggested issue or fill Additional Details, then tap Add.",
                        style: TextStyle(
                          color: itemsError != null
                              ? const Color(0xFFEF4444)
                              : _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        ...selectedItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(_radius),
                                onLongPress: () {
                                  showEquipmentDetailsDialog(
                                    title: "Equipment details",
                                    details: item.details,
                                    displayLabel: item.displayLabel,
                                    issue: item.issue,
                                    manualName: item.manualName,
                                    isManual:
                                        item.type == _EquipmentItemType.manual,
                                  );
                                },
                                child: _softCard(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    10,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.displayLabel,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: _ink,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Issue: ${item.issue}",
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                color: _muted,
                                              ),
                                            ),
                                            if ((item.openReportTicket ?? "")
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                "Open report ${item.openReportTicket} — submit will add your update there.",
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFFB45309),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              item.type ==
                                                      _EquipmentItemType.manual
                                                  ? "MANUAL ENTRY · HOLD FOR DETAILS"
                                                  : "LISTED EQUIPMENT · HOLD FOR DETAILS",
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.4,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            selectedItems.removeAt(index);
                                            itemsError = null;
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFFDC2626),
                                          backgroundColor:
                                              const Color(0xFFFEF2F2),
                                          elevation: 0,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            side: const BorderSide(
                                              color: Color(0xFFFECACA),
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          "Remove",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        if (itemsError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              itemsError!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 22),

            // Suggested issues (chips)
            Row(
              children: [
                Expanded(
                  child: _buildSectionTitle(
                    "Suggested issues (${suggestedIssues.length})",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: issueKey,
              child: suggestedIssues.isEmpty
                  ? _softCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.grey.shade400,
                            size: 28,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            equipmentNotListed
                                ? "Enable Equipment not listed to load global suggested issues."
                                : "Select equipment first to see suggested issues.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (issueError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              issueError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visibleSuggestedIssues.map((issue) {
                            final id = int.tryParse(
                              issue["issue_template_id"]?.toString() ?? "",
                            );
                            final name =
                                issue["issue_template_name"]?.toString() ?? "";
                            final selected = selectedSuggestedIssueId == id;
                            return ChoiceChip(
                              label: Text(name),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  if (selected) {
                                    selectedSuggestedIssueId = null;
                                    selectedSuggestedIssueName = null;
                                  } else {
                                    selectedSuggestedIssueId = id;
                                    selectedSuggestedIssueName = name;
                                    issueError = null;
                                    descriptionError = null;
                                  }
                                });
                              },
                              selectedColor: _amber,
                              backgroundColor: Colors.white,
                              elevation: 0,
                              pressElevation: 0,
                              shadowColor: Colors.transparent,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: selected ? _ink : const Color(0xFF334155),
                              ),
                              side: BorderSide(
                                color: selected
                                    ? _amber
                                    : _border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              showCheckmark: false,
                            );
                          }).toList(),
                        ),
                        if (equipmentNotListed &&
                            !showAllGlobalIssues &&
                            suggestedIssues.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextButton(
                              onPressed: () {
                                showSelectionBottomSheet(
                                  title: "Select Suggested Issue",
                                  items: suggestedIssues,
                                  selectedItem: selectedSuggestedIssueId,
                                  icon: Icons.report_problem_outlined,
                                  label: (issue) =>
                                      issue["issue_template_name"]?.toString() ??
                                      "",
                                  idOf: (issue) => int.tryParse(
                                    issue["issue_template_id"]?.toString() ??
                                        "",
                                  ),
                                  onSelected: (issue) {
                                    setState(() {
                                      selectedSuggestedIssueId = int.tryParse(
                                        issue["issue_template_id"]?.toString() ??
                                            "",
                                      );
                                      selectedSuggestedIssueName =
                                          issue["issue_template_name"]
                                              ?.toString();
                                      issueError = null;
                                      descriptionError = null;
                                    });
                                  },
                                );
                              },
                              child: Text(
                                "+${suggestedIssues.length - 5} more issues",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (issueError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              issueError!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 22),

            // Additional details (used at Add time)
            _buildSectionTitle("Additional details"),
            const SizedBox(height: 6),
            const Text(
              "Optional if a suggested issue is selected",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: descriptionKey,
              child: _softCard(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                  decoration: _minimalInputDecoration(
                    hintText: "Describe the problem...",
                    errorText: descriptionError,
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  ),
                  onChanged: (_) {
                    if (descriptionController.text.trim().isNotEmpty) {
                      setState(() {
                        descriptionError = null;
                        issueError = null;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Priority panel (web-style dark block)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Priority level",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...priorities.map((item) {
                    final selected = priority == item.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(_radius),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(_radius),
                          onTap: () {
                            setState(() {
                              priority = item.value;
                              if (item.value == "Urgent") {
                                preferredActionDate = null;
                                preferredDateError = null;
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected ? _amber : Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: selected
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(
                                            alpha: 0.55,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (isNonUrgent) ...[
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: preferredDateKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Preferred date",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "Optional",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(_radius),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(_radius),
                              onTap: pickPreferredDate,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 18,
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        preferredActionDate == null
                                            ? "dd/mm/yyyy"
                                            : DateFormat("dd/MM/yyyy")
                                                .format(preferredActionDate!),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: preferredActionDate == null
                                              ? Colors.white.withValues(
                                                  alpha: 0.45,
                                                )
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (preferredActionDate != null)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setState(() {
                                            preferredActionDate = null;
                                            preferredDateError = null;
                                          });
                                        },
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Optional. Earliest date is $_preferredDateMinDaysAhead days from today. If you skip this, maintenance will be reminded after $_nonUrgentReminderGraceDays days.",
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          if (preferredDateError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              preferredDateError!,
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    "Upload proof image",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  selectedImage == null
                      ? GestureDetector(
                          onTap: pickImage,
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(_radius),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Tap to upload photo (Optional)",
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "PNG · JPG · JPEG · WEBP",
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(_radius),
                                    onTap: () => showProofImageFullscreen(
                                      selectedImage!,
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(_radius),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(_radius),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.file(
                                              selectedImage!,
                                              fit: BoxFit.cover,
                                            ),
                                            Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 6,
                                                ),
                                                color: Colors.black
                                                    .withValues(alpha: 0.45),
                                                child: const Text(
                                                  "Tap to view full screen",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
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
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: pickImage,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.edit_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
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

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                ),
                onPressed: () async {
                  if (validateForm()) {
                    await confirmSubmitReport();
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  "Submit Report",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    employeeIdController.dispose();
    descriptionController.dispose();
    equipmentController.dispose();
    scrollController.dispose();
    _issueSearchTimer?.cancel();
    _locationSearchTimer?.cancel();
    _equipmentSearchTimer?.cancel();
    super.dispose();
  }

  void addEquipmentItem() {
    setState(() {
      equipmentError = null;
      issueError = null;
      descriptionError = null;
      itemsError = null;
    });

    if (selectedRoomId == null) {
      setState(() => locationError = "Please select a location.");
      scrollToField(locationKey);
      return;
    }

    // Validate equipment first so issue errors don't show before a selection.
    if (equipmentNotListed) {
      final name = equipmentController.text.trim();
      if (name.isEmpty) {
        setState(() => equipmentError = "Please enter the equipment name.");
        scrollToField(equipmentKey);
        return;
      }
      final exists = selectedItems.any(
        (item) =>
            item.type == _EquipmentItemType.manual &&
            (item.manualName ?? "").toLowerCase() == name.toLowerCase(),
      );
      if (exists) {
        setState(() => equipmentError = "That equipment name is already added.");
        scrollToField(equipmentKey);
        return;
      }

      final issue = _draftIssueText;
      if (issue == null) {
        setState(() {
          issueError =
              "Select a suggested issue or provide additional details before adding.";
          descriptionError =
              "Select a suggested issue or provide additional details before adding.";
        });
        scrollToField(issueKey);
        return;
      }

      setState(() {
        selectedItems.add(
          _ReportEquipmentItem(
            type: _EquipmentItemType.manual,
            displayLabel: name,
            manualName: name,
            issue: issue,
          ),
        );
        equipmentController.clear();
        selectedSuggestedIssueId = null;
        selectedSuggestedIssueName = null;
        descriptionController.clear();
      });
      return;
    }

    if (selectedEquipmentId == null ||
        (selectedEquipmentLabel ?? "").trim().isEmpty) {
      setState(() {
        equipmentError = "Please select equipment.";
        issueError = null;
        descriptionError = null;
      });
      scrollToField(equipmentKey);
      return;
    }

    final exists = selectedItems.any(
      (item) =>
          item.type == _EquipmentItemType.listed &&
          item.id == selectedEquipmentId,
    );
    if (exists) {
      setState(() => equipmentError = "That equipment is already added.");
      scrollToField(equipmentKey);
      return;
    }

    final issue = _draftIssueText;
    if (issue == null) {
      setState(() {
        issueError =
            "Select a suggested issue or provide additional details before adding.";
        descriptionError =
            "Select a suggested issue or provide additional details before adding.";
      });
      scrollToField(issueKey);
      return;
    }

    setState(() {
      selectedItems.add(
        _ReportEquipmentItem(
          type: _EquipmentItemType.listed,
          id: selectedEquipmentId,
          displayLabel: selectedEquipmentLabel!,
          issue: issue,
          openReportTicket:
              _openReportTicketOf(selectedEquipmentDetails ?? {}),
          details: selectedEquipmentDetails,
        ),
      );
      selectedEquipmentId = null;
      selectedEquipmentLabel = null;
      selectedEquipmentDetails = null;
      selectedSuggestedIssueId = null;
      selectedSuggestedIssueName = null;
      suggestedIssues.clear();
      descriptionController.clear();
    });
  }

  Future<void> pickPreferredDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: preferredActionDate ?? _earliestPreferredDate,
      firstDate: _earliestPreferredDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      preferredActionDate = picked;
      preferredDateError = null;
    });
  }

  Future<void> verifyReporter() async {
    final employeeId = employeeIdController.text.trim();
    if (employeeId.isEmpty) {
      setState(() {
        isCheckingReporter = false;
        reporterVerified = false;
        reporterName = "";
        reporterError = null;
      });
      return;
    }

    setState(() => isCheckingReporter = true);

    final reporter = await api.verifyReporter(employeeId);
    if (!mounted) return;

    if (reporter != null &&
        reporter["reporter_full_name"] != null &&
        reporter["reporter_full_name"].toString().trim().isNotEmpty) {
      setState(() {
        isCheckingReporter = false;
        reporterVerified = true;
        reporterName = reporter["reporter_full_name"].toString();
        reporterError = null;
        employeeIdError = null;
      });
    } else {
      setState(() {
        isCheckingReporter = false;
        reporterVerified = false;
        reporterName = "";
        // Keep errors silent until Submit Report validation.
        reporterError = null;
      });
    }
  }

  Future<void> loadRooms() async {
    final data = await api.getRooms();
    if (!mounted) return;
    setState(() => rooms = data);
  }

  Future<void> loadEquipment(int roomId) async {
    final data = await api.getEquipment(roomId);
    if (!mounted) return;
    setState(() {
      equipment = data;
      selectedEquipmentLabel = null;
      selectedEquipmentId = null;
      selectedEquipmentDetails = null;
    });
  }

  Future<void> loadSuggestedIssues(int equipmentId) async {
    final data = await api.getSuggestedIssues(equipmentId);
    if (!mounted) return;
    setState(() {
      suggestedIssues = data;
      selectedSuggestedIssueId = null;
      selectedSuggestedIssueName = null;
      showAllGlobalIssues = false;
    });
  }

  Future<void> loadGlobalSuggestedIssues() async {
    final data = await api.getGlobalSuggestedIssues();
    if (!mounted) return;
    setState(() {
      suggestedIssues = data;
      selectedSuggestedIssueId = null;
      selectedSuggestedIssueName = null;
      showAllGlobalIssues = false;
    });
  }

  Future<void> pickImage() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                _sheetActionTile(
                  icon: Icons.photo_camera_rounded,
                  title: "Take photo",
                  subtitle: "Use your camera",
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 10),
                _sheetActionTile(
                  icon: Icons.photo_library_rounded,
                  title: "Choose from gallery",
                  subtitle: "Pick an existing image",
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final image = await picker.pickImage(
      source: source,
      imageQuality: 55,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (!mounted || image == null) return;
    setState(() => selectedImage = File(image.path));
  }

  Future<void> showProofImageFullscreen(File image) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Center(
                          child: Image.file(
                            image,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: Ink(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.55),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 22,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Text(
                        "Pinch to zoom",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _submitConfirmMessage() {
    final openReportItems = selectedItems
        .where((item) => (item.openReportTicket ?? "").isNotEmpty)
        .length;
    if (selectedItems.length > 1) {
      if (openReportItems > 0) {
        return "Submit ${selectedItems.length} equipment items? "
            "$openReportItems already have open reports and your updates will be merged there.";
      }
      return "Submit ${selectedItems.length} equipment items in one maintenance report?";
    }
    final ticket = selectedItems
        .map((item) => item.openReportTicket)
        .firstWhere((ticket) => (ticket ?? "").isNotEmpty, orElse: () => null);
    if (ticket != null) {
      return "This equipment already has open report $ticket. "
          "Your update will be added to that ticket.";
    }
    return "Send this maintenance report now?";
  }

  Future<void> confirmSubmitReport() async {
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x660F172A),
      builder: (dialogContext) {
        var phase = "confirm";
        String errorMessage = "Failed to submit report.";
        String successMessage = "Your maintenance report was sent successfully.";
        var isSending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendReport() async {
              if (isSending) return;
              isSending = true;
              setDialogState(() => phase = "submitting");

              try {
                final listed = selectedItems
                    .where((e) => e.type == _EquipmentItemType.listed)
                    .toList();
                final manuals = selectedItems
                    .where((e) => e.type == _EquipmentItemType.manual)
                    .toList();

                String? preferred;
                if (priority == "Non-Urgent" && preferredActionDate != null) {
                  preferred = DateFormat("yyyy-MM-dd")
                      .format(preferredActionDate!);
                }

                final response = await api.submitReport(
                  employeeId: employeeIdController.text.trim(),
                  roomId: selectedRoomId!,
                  equipmentIds: listed.map((e) => e.id!).toList(),
                  equipmentIssues: listed.map((e) => e.issue).toList(),
                  manualEquipmentNames:
                      manuals.map((e) => e.manualName!).toList(),
                  manualEquipmentIssues: manuals.map((e) => e.issue).toList(),
                  priority: priority,
                  preferredActionDate: preferred,
                  photo: selectedImage,
                );

                if (!dialogContext.mounted) return;

                final data = response.data;
                if (response.statusCode != null &&
                    response.statusCode! >= 400) {
                  errorMessage = data is Map
                      ? (data["message"]?.toString() ?? errorMessage)
                      : errorMessage;
                  isSending = false;
                  setDialogState(() => phase = "error");
                  return;
                }

                if (data is Map) {
                  if (data["merged"] == true) {
                    successMessage = data["message"]?.toString() ??
                        "Your update was added to the existing open report.";
                  } else if (selectedItems.length > 1) {
                    successMessage = data["message"]?.toString() ??
                        "Your report with ${selectedItems.length} equipment items was sent successfully.";
                  } else {
                    successMessage = data["message"]?.toString() ??
                        successMessage;
                  }
                } else if (selectedItems.length > 1) {
                  successMessage =
                      "Your report with ${selectedItems.length} equipment items was sent successfully.";
                }

                setDialogState(() => phase = "success");
              } catch (e) {
                errorMessage = "Failed to submit report.";
                if (e is DioException) {
                  final data = e.response?.data;
                  if (data is Map) {
                    errorMessage =
                        data["message"]?.toString() ?? errorMessage;
                  } else if (data is String) {
                    final trimmed = data.trim();
                    if (trimmed.startsWith("<!DOCTYPE") ||
                        trimmed.startsWith("<html")) {
                      final status = e.response?.statusCode;
                      errorMessage = status == null
                          ? "Server error while submitting the report. Please try again."
                          : "Server error ($status) while submitting the report. Please try again.";
                    } else {
                      errorMessage =
                          trimmed.isEmpty ? errorMessage : trimmed;
                    }
                  } else {
                    errorMessage = e.message ?? errorMessage;
                  }

                  if (errorMessage.toLowerCase().contains("employee id") &&
                      mounted) {
                    setState(() {
                      reporterVerified = false;
                      reporterName = "";
                      reporterError = "Employee ID not found.";
                      employeeIdError = "Please enter a valid Employee ID.";
                    });
                  }
                }

                if (!dialogContext.mounted) return;
                isSending = false;
                setDialogState(() => phase = "error");
              }
            }

            if (phase == "submitting") {
              return Dialog(
                backgroundColor: Colors.white,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(22, 30, 22, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        "Submitting report...",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (phase == "success") {
              return Dialog(
                backgroundColor: Colors.white,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF059669),
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Report submitted",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        successMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_radius),
                            ),
                          ),
                          child: const Text(
                            "Done",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (phase == "error") {
              return Dialog(
                backgroundColor: Colors.white,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Submission failed",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_radius),
                            ),
                          ),
                          child: const Text(
                            "OK",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.white,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Submit report?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _submitConfirmMessage(),
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
                                borderRadius: BorderRadius.circular(_radius),
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
                            onPressed: sendReport,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(_radius),
                              ),
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text(
                              "Submit",
                              style: TextStyle(fontWeight: FontWeight.w700),
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
      },
    );

    if (submitted == true && mounted) {
      resetForm();
    }
  }

  bool validateForm() {
    GlobalKey? firstErrorKey;
    var hasError = false;

    setState(() {
      employeeIdError = null;
      reporterError = null;
      locationError = null;
      equipmentError = null;
      issueError = null;
      descriptionError = null;
      preferredDateError = null;
      itemsError = null;
    });

    if (!reporterVerified) {
      final id = employeeIdController.text.trim();
      if (id.isEmpty) {
        employeeIdError = "Please enter a valid Employee ID.";
        reporterError = null;
      } else {
        employeeIdError = "Please enter a valid Employee ID.";
        reporterError = "Employee ID not found.";
      }
      firstErrorKey ??= employeeKey;
      hasError = true;
    }

    if (selectedRoomId == null) {
      locationError = "Please select a location.";
      firstErrorKey ??= locationKey;
      hasError = true;
    }

    if (selectedItems.isEmpty) {
      itemsError =
          "Add at least one equipment with a suggested issue or additional details.";
      firstErrorKey ??= itemsKey;
      hasError = true;
    }

    if (priority == "Non-Urgent" && preferredActionDate != null) {
      final min = _earliestPreferredDate;
      final picked = DateTime(
        preferredActionDate!.year,
        preferredActionDate!.month,
        preferredActionDate!.day,
      );
      if (picked.isBefore(min)) {
        preferredDateError =
            "Preferred date must be at least $_preferredDateMinDaysAhead days from today.";
        firstErrorKey ??= preferredDateKey;
        hasError = true;
      }
    }

    setState(() {});

    if (hasError) {
      final key = firstErrorKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (key != null) scrollToField(key);
      });
      return false;
    }

    return true;
  }

  void scrollToField(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
  }

  void resetForm() {
    employeeIdController.clear();
    descriptionController.clear();
    equipmentController.clear();

    setState(() {
      reporterVerified = false;
      reporterName = "";
      reporterError = null;
      selectedRoomId = null;
      selectedLocation = null;
      selectedEquipmentLabel = null;
      selectedEquipmentId = null;
      selectedEquipmentDetails = null;
      selectedSuggestedIssueId = null;
      selectedSuggestedIssueName = null;
      suggestedIssues.clear();
      equipment.clear();
      selectedItems.clear();
      equipmentNotListed = false;
      selectedImage = null;
      priority = "Non-Urgent";
      preferredActionDate = null;
      employeeIdError = null;
      locationError = null;
      equipmentError = null;
      issueError = null;
      descriptionError = null;
      preferredDateError = null;
      itemsError = null;
    });
  }

  Future<void> showSelectionBottomSheet({
    required String title,
    required List<dynamic> items,
    required String Function(dynamic) label,
    required Function(dynamic) onSelected,
    required IconData icon,
    required dynamic selectedItem,
    int? Function(dynamic)? idOf,
    bool enableLongPressDetails = false,
  }) async {
    String search = "";
    final searchController = TextEditingController();
    final searchFocus = FocusNode();

    void dismissKeyboard() {
      searchFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = items.where((item) {
              if (search.trim().isEmpty) return true;
              return label(item)
                  .toLowerCase()
                  .contains(search.trim().toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.72,
                minChildSize: 0.45,
                maxChildSize: 0.92,
                builder: (context, sheetController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                    if (enableLongPressDetails) ...[
                                      const SizedBox(height: 2),
                                      const Text(
                                        "Hold an item to see full details",
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: _muted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  dismissKeyboard();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: TextField(
                            controller: searchController,
                            focusNode: searchFocus,
                            onChanged: (value) {
                              setModalState(() => search = value);
                            },
                            decoration: InputDecoration(
                              hintText: "Search...",
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: _soft,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radius),
                                borderSide: const BorderSide(color: _border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radius),
                                borderSide: const BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radius),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    items.isEmpty && enableLongPressDetails
                                        ? "All equipment for this location is already added."
                                        : "No results found",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _muted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: sheetController,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    24,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, index) {
                                    final item = filtered[index];
                                    final itemId = idOf?.call(item) ??
                                        (item is Map
                                            ? item.values.first
                                            : null);
                                    final selected = selectedItem != null &&
                                        selectedItem == itemId;
                                    final openReportTicket =
                                        _openReportTicketOf(item);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Material(
                                        color: selected
                                            ? const Color(0xFFEFF6FF)
                                            : openReportTicket != null
                                                ? const Color(0xFFFFFBEB)
                                                : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(_radius),
                                          side: BorderSide(
                                            color: selected
                                                ? const Color(0xFF2563EB)
                                                : openReportTicket != null
                                                    ? const Color(0xFFFCD34D)
                                                    : _border,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(_radius),
                                          onTap: () {
                                            dismissKeyboard();
                                            onSelected(item);
                                            Navigator.pop(context);
                                          },
                                          onLongPress: enableLongPressDetails
                                              ? () {
                                                  dismissKeyboard();
                                                  showEquipmentDetailsDialog(
                                                    title: "Equipment details",
                                                    details:
                                                        _detailsFromEquipment(
                                                      item,
                                                    ),
                                                    displayLabel: label(item),
                                                  );
                                                }
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: _soft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                    border: Border.all(
                                                      color: _border,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    icon,
                                                    color: selected
                                                        ? const Color(
                                                            0xFF2563EB,
                                                          )
                                                        : _ink,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    label(item),
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14.5,
                                                      color: _ink,
                                                    ),
                                                  ),
                                                ),
                                                Icon(
                                                  selected
                                                      ? Icons
                                                          .check_circle_rounded
                                                      : Icons
                                                          .chevron_right_rounded,
                                                  color: selected
                                                      ? _blue
                                                      : const Color(0xFFCBD5E1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
    searchFocus.dispose();
  }

  Widget _sheetActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _soft,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border),
                ),
                child: Icon(icon, color: _blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: _ink,
      ),
    );
  }

  Widget _softCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _rowDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _selectRow({
    required IconData icon,
    required Color iconColor,
    required String placeholder,
    String? value,
    String? errorText,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null && value.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          onTap();
        },
        borderRadius: BorderRadius.circular(_radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _border),
                    ),
                    child: Icon(icon, color: _ink, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasValue ? "Selected" : "Tap to choose",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasValue ? value : placeholder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasValue ? FontWeight.w700 : FontWeight.w500,
                            color: hasValue ? _ink : const Color(0xFFB0B0B0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _muted,
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _textInputRow({
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required String hint,
    String? errorText,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, color: _ink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
              decoration: InputDecoration(
                hintText: hint,
                errorText: errorText,
                hintStyle: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
                errorStyle: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot() {
    Color color = const Color(0xFFCBD5E1);
    if (isCheckingReporter) {
      color = const Color(0xFFF59E0B);
    } else if (reporterVerified) {
      color = const Color(0xFF22C55E);
    } else if (employeeIdError != null || reporterError != null) {
      color = const Color(0xFFEF4444);
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _reporterStatusText() {
    if (isCheckingReporter) {
      return const Text(
        "Verifying employee...",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _muted,
        ),
      );
    }
    if (reporterVerified && reporterName.isNotEmpty) {
      return Text(
        reporterName,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      );
    }
    // Only show failure copy after Submit Report validation.
    if (reporterError != null && employeeIdError != null) {
      return Text(
        reporterError!,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFFEF4444),
        ),
      );
    }
    return const Text(
      "Waiting for valid Employee ID...",
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Color(0xFF94A3B8),
      ),
    );
  }

  InputDecoration _minimalInputDecoration({
    String? labelText,
    String? hintText,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.transparent,
      isDense: true,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFEF4444),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: _muted,
      suffixIconColor: _muted,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );
  }
}
