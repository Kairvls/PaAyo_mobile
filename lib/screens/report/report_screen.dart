import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../qr/qr_scanner_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/coach_tour.dart';
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

enum _GateTone { error, warn, info }

/// Uppercases as the user types, keeping the cursor where it was.
class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(text: upper);
  }
}

class _ReportEquipmentItem {
  final int id;
  final int roomId;
  final String locationLabel;
  final String displayLabel;
  /// Picked suggested issue; empty means the problem is only in [problemDetails] ("Other").
  final String issue;
  final String problemDetails;
  final String? openReportTicket;
  /// Raw equipment fields for uniqueness details (long-press).
  final Map<String, dynamic>? details;

  /// Quick-check answers (`{id, answer}`) given before this item was added.
  final List<Map<String, dynamic>> checks;

  /// Optional proof photo for this item (one per item, like the web).
  File? photo;

  _ReportEquipmentItem({
    required this.id,
    required this.roomId,
    required this.locationLabel,
    required this.displayLabel,
    required this.issue,
    this.problemDetails = "",
    this.openReportTicket,
    this.details,
    this.checks = const [],
  });

  int get triedChecks =>
      checks.where((check) => check["answer"] == "not_fixed").length;
}

enum _QuickCheckStatus { done, fixed, cancelled }

class _QuickCheckOutcome {
  final _QuickCheckStatus status;
  final List<Map<String, dynamic>> answers;

  const _QuickCheckOutcome(this.status, [this.answers = const []]);
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  /// Matches STI-PRISM mobile Maintenance Report modal tokens.
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF6B7280);
  static const _soft = Color(0xFFF3F4F6);
  static const _blue = Color(0xFF0025CC);
  static const _blueSoft = Color(0xFFF3F6FF);
  static const _page = Color(0xFFFFFFFF);
  static const _amber = Color(0xFFFFF200);
  static const _border = Color(0xFFE5E7EB);
  static const _borderSoft = Color(0xFFECEFF4);
  static const _placeholder = Color(0xFF9CA3AF);
  static const _radius = 16.0;
  static const _radiusSm = 12.0;

  Timer? _issueSearchTimer;
  Timer? _locationSearchTimer;
  Timer? _equipmentSearchTimer;
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  /// Step 1 (employee ID + PIN) passed; the report form (step 2) is shown.
  bool reporterVerified = false;
  String reporterName = "";
  final ApiService api = ApiService();

  final TextEditingController pinController = TextEditingController();
  final TextEditingController forgotIdController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  bool showPin = false;
  late final AnimationController _pinShake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool showForgotPin = false;
  bool isVerifyingPin = false;
  bool isSendingForgot = false;
  String? gateMessage;
  _GateTone gateMessageTone = _GateTone.error;
  String? forgotMessage;
  _GateTone forgotMessageTone = _GateTone.info;
  bool _tourChecked = false;
  bool _addingItem = false;
  bool showAssigned = false;
  bool showItems = false;

  List<dynamic> suggestedIssues = [];
  int? selectedSuggestedIssueId;
  String? selectedSuggestedIssueName;

  List<dynamic> rooms = [];
  int? selectedRoomId;
  String? selectedLocation;

  List<dynamic> equipment = [];
  String? selectedEquipmentLabel;
  int? selectedEquipmentId;
  Map<String, dynamic>? selectedEquipmentDetails;

  final List<_ReportEquipmentItem> selectedItems = [];

  /// Equipment issued to the verified reporter (property assignment).
  List<Map<String, dynamic>> assignedEquipment = [];

  String? locationError;
  String? equipmentError;
  String? issueError;
  String? descriptionError;
  String? itemsError;

  final employeeKey = GlobalKey();
  final locationKey = GlobalKey();
  final equipmentKey = GlobalKey();
  final issueKey = GlobalKey();
  final descriptionKey = GlobalKey();
  final itemsKey = GlobalKey();
  final assignedKey = GlobalKey();
  final scanKey = GlobalKey();
  final addKey = GlobalKey();
  final submitKey = GlobalKey();

  static const _tourSeenPref = "report_tour_seen";
  static const _tourBannerHiddenPref = "report_tour_banner_hidden";

  /// Top "how to report" banner; stays until the tour is finished or dismissed.
  bool showTourBanner = false;

  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadRooms();
    _pinFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initTour() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      showTourBanner = !(prefs.getBool(_tourBannerHiddenPref) ?? false);
    });
    if (prefs.getBool(_tourSeenPref) ?? false) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await startTour();
  }

  Future<void> _hideTourBanner() async {
    setState(() => showTourBanner = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourBannerHiddenPref, true);
  }

  Future<void> startTour() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final finished = await CoachTour.show(context, _tourSteps());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourSeenPref, true);
    if (finished && mounted) await _hideTourBanner();
    if (mounted && scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  List<CoachStep> _tourSteps() => [
        CoachStep(
          targetKey: employeeKey,
          title: "You're verified",
          body:
              "Your employee ID was confirmed with your PIN. Not you? Tap Switch.",
        ),
        CoachStep(
          targetKey: assignedKey,
          title: "Your assigned equipment",
          body:
              "Equipment issued to you. Open the list and tap one to fill in its location and equipment.",
        ),
        CoachStep(
          targetKey: scanKey,
          title: "Scan the equipment's QR",
          body:
              "The fastest way. Scan the QR sticker and the location and equipment fill in for you.",
        ),
        CoachStep(
          targetKey: locationKey,
          title: "Or choose manually",
          body:
              "Pick the room, then the equipment. You can switch rooms anytime — your list is kept.",
        ),
        CoachStep(
          targetKey: issueKey,
          title: "Pick the problem",
          body:
              "Choose the issue that matches. These appear after you select equipment.",
        ),
        CoachStep(
          targetKey: descriptionKey,
          title: "Describe it",
          body:
              "Opens once equipment is selected. Write what's wrong with that one item — details alone are fine if no issue fits.",
        ),
        CoachStep(
          targetKey: addKey,
          title: "Add it to your report",
          body:
              "Saves the equipment with its issue and details. Repeat for every item, even from other rooms.",
        ),
        CoachStep(
          targetKey: itemsKey,
          title: "Your list",
          body:
              "Shows how many items you've added. Tap to open it — each item can have one photo. Long-press one for full details.",
        ),
        CoachStep(
          targetKey: submitKey,
          title: "Send your report",
          body:
              "Everything goes out as one report. Priority is set automatically.",
        ),
      ];

  String formatRoomLocationLabel(dynamic room) {
    final map = room is Map ? Map<String, dynamic>.from(room) : <String, dynamic>{};
    final location = (map["location"]?.toString() ?? "").trim();
    final count = int.tryParse(map["equipment_count"]?.toString() ?? "") ?? 0;
    if (location.isEmpty) return "Eq. $count";
    // Avoid duplicating if API already appended a count.
    if (RegExp(r'(Eq\.\s*\d+|\s-\s\d+\s*$)').hasMatch(location)) {
      return location;
    }
    return "$location - Eq. $count";
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

    final code = _equipmentCode(map["equipment_id"]);
    if (parts.isEmpty && code != null) {
      parts.add(code);
    }

    final openReportTicket = _openReportTicketOf(map);
    if (openReportTicket != null) {
      parts.add("Open report: $openReportTicket");
    }

    return parts.isEmpty ? name : "$name · ${parts.join(" · ")}";
  }

  String? _equipmentCode(dynamic rawId) {
    final id = int.tryParse(rawId?.toString() ?? "");
    if (id == null) return null;
    return "EQ-${id.toString().padLeft(6, "0")}";
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

  Set<int> get _addedEquipmentIds => selectedItems.map((e) => e.id).toSet();

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
    String? problemDetails,
  }) {
    final rows = <(String, String)>[];
    final map = details ?? <String, dynamic>{};

    void add(String label, dynamic value) {
      final text = value?.toString().trim() ?? "";
      if (text.isEmpty || text == "null" || text == "—") return;
      rows.add((label, text));
    }

    add("Name", map["equipment_name"] ?? displayLabel);
    add("Category", map["equipment_category_name"] ?? map["category"]);
    add("Asset tag", map["equipment_asset_tag"]);
    add("Serial number", map["equipment_serial_number"]);
    add("Brand", map["equipment_brand_name"]);
    add("Model", map["equipment_model"]);
    add("Placement zone", map["equipment_placement_zone"]);
    add("Equipment ID", _equipmentCode(map["equipment_id"]));
    add("Open report", map["open_report_ticket_code"]);
    add("Report status", map["open_report_status"]);

    if (issue != null && issue.trim().isNotEmpty) {
      add("Issue", issue);
    }
    add("Details", problemDetails);

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
    String? problemDetails,
  }) async {
    final rows = _uniquenessRows(
      details: details,
      displayLabel: displayLabel,
      issue: issue,
      problemDetails: problemDetails,
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
                      backgroundColor: _blue,
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

  String get _draftIssue => selectedSuggestedIssueName?.trim() ?? "";

  String get _draftDetails => descriptionController.text.trim();

  /// Details describe one item, so the box only opens once equipment is chosen.
  bool get _canWriteDetails => selectedEquipmentId != null;

  bool get _draftPicked => selectedEquipmentId != null;

  /// Ready once the item has equipment plus an issue or details.
  bool get _draftReady =>
      _draftPicked && (_draftIssue.isNotEmpty || _draftDetails.isNotEmpty);

  /// Faded until ready but still tappable, so the reporter is told what's missing.
  Widget _addToReportButton() {
    final ready = _draftReady;
    return Column(
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: ready ? 1 : 0.45,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: addEquipmentItem,
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFEEF2FF),
                foregroundColor: _blue,
                side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                "Add to report",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        if (!ready) ...[
          const SizedBox(height: 8),
          Text(
            _draftPicked
                ? "Pick a suggested issue or describe the problem."
                : "Pick the equipment first.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ],
    );
  }

  String _issueLabel(_ReportEquipmentItem item) =>
      item.issue.isEmpty ? "Other" : item.issue;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android: dark icons on white
        statusBarBrightness: Brightness.light, // iOS: dark icons on white
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: _page,
      body: !reporterVerified
          ? _buildGate(topInset)
          : SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header (web modal mobile) ──
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _amber,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _amber.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  "CAMPUS REPORT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: _ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Maintenance Report",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.15,
                      color: _ink,
                    ),
                  ),
                ),
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE8ECF4)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: startTour,
                    child: const Tooltip(
                      message: "How to report",
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 18,
                          color: _blue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE8ECF4)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.maybePop(context),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (showTourBanner) ...[
              const SizedBox(height: 16),
              _tourBanner(),
            ],
            const SizedBox(height: 22),

            // ── Reporter ──
            KeyedSubtree(key: employeeKey, child: _reporterCard()),
            if (assignedEquipment.isNotEmpty) ...[
              const SizedBox(height: 8),
              KeyedSubtree(key: assignedKey, child: _assignedEquipmentBox()),
            ],

            const SizedBox(height: 20),

            // ── Location & equipment ──
            _buildSectionTitle("Location & equipment"),
            const SizedBox(height: 8),
            KeyedSubtree(key: scanKey, child: _scanQrButton()),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: Divider(color: _border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    "or choose manually",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _muted.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: _border)),
              ],
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: locationKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    _selectRow(
                      icon: Icons.location_on_outlined,
                      value: selectedLocation,
                      placeholder: "Select Location",
                      errorText: locationError,
                      onTap: () {
                        showSelectionPicker(
                          title: "Select location",
                          searchHint: "Search rooms",
                          items: rooms,
                          selectedItem: selectedRoomId,
                          label: formatRoomLocationLabel,
                          idOf: (room) =>
                              int.tryParse(room["room_id"]?.toString() ?? ""),
                          onSelected: (room) {
                            locationError = null;
                            setState(() {
                              selectedLocation = formatRoomLocationLabel(room);
                              selectedRoomId = int.tryParse(
                                room["room_id"]?.toString() ?? "",
                              );
                              selectedEquipmentLabel = null;
                              selectedEquipmentId = null;
                              selectedEquipmentDetails = null;
                              selectedSuggestedIssueId = null;
                              selectedSuggestedIssueName = null;
                              suggestedIssues.clear();
                              descriptionController.clear();
                              itemsError = null;
                            });
                            if (selectedRoomId != null) {
                              loadEquipment(selectedRoomId!);
                            }
                          },
                        );
                      },
                    ),
                    const Divider(height: 1, thickness: 1, color: _border),
                    KeyedSubtree(
                      key: equipmentKey,
                      child: _selectRow(
                        icon: Icons.monitor_outlined,
                        value: selectedEquipmentLabel,
                        placeholder: "Select Equipment",
                        errorText: equipmentError,
                        onTap: () {
                          if (selectedRoomId == null) {
                            setState(() {
                              locationError = "Please select a location first.";
                            });
                            scrollToField(locationKey);
                            return;
                          }
                          showSelectionPicker(
                            title: "Select equipment",
                            searchHint: "Search equipment",
                            items: _availableEquipment,
                            selectedItem: selectedEquipmentId,
                            label: formatEquipmentLabel,
                            idOf: _equipmentIdOf,
                            enableLongPressDetails: true,
                            enableCategoryFilter: true,
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

            if (itemsError != null && selectedItems.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                itemsError!,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
            KeyedSubtree(
              key: itemsKey,
              child: selectedItems.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _reportItemsBox(),
                    ),
            ),

            const SizedBox(height: 18),

            // ── Suggested issues ──
            _buildSectionTitle(
              "Suggested issues (${suggestedIssues.length})",
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: issueKey,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: suggestedIssues.isEmpty ? 112 : 0,
                ),
                padding: suggestedIssues.isEmpty
                    ? const EdgeInsets.all(14)
                    : const EdgeInsets.fromLTRB(10, 10, 0, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_radiusSm),
                  border: Border.all(color: _border),
                ),
                child: suggestedIssues.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: _placeholder,
                            size: 20,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Select equipment first to see suggested issues.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _placeholder,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
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
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: suggestedIssues.map((issue) {
                                final id = int.tryParse(
                                  issue["issue_template_id"]?.toString() ??
                                      "",
                                );
                                final name = issue["issue_template_name"]
                                        ?.toString() ??
                                    "";
                                final selected =
                                    selectedSuggestedIssueId == id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Material(
                                    color: selected
                                        ? _amber
                                        : _blueSoft,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                      side: BorderSide(
                                        color: selected
                                            ? Colors.transparent
                                            : const Color(0xFFE0E7FF),
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () {
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
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: selected
                                                ? _ink
                                                : _blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
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
            ),

            const SizedBox(height: 20),

            // ── Additional details ──
            _buildSectionTitle("Additional details"),
            /* const SizedBox(height: 4),
            const Text(
              "For the selected equipment · optional if an issue is picked",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _placeholder,
              ),
            ), */
            const SizedBox(height: 8),
            KeyedSubtree(
              key: descriptionKey,
              child: TextField(
                controller: descriptionController,
                enabled: _canWriteDetails,
                maxLines: 5,
                maxLength: 2000,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
                decoration: _fieldDecoration(
                  hintText: _canWriteDetails
                      ? "Describe this equipment's problem..."
                      : "Select equipment first, then describe its problem",
                  errorText: descriptionError,
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 40, 14),
                ).copyWith(
                  fillColor: _canWriteDetails ? Colors.white : _soft,
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_radius),
                    borderSide: const BorderSide(color: _borderSoft),
                  ),
                ),
                onChanged: (_) {
                  setState(() {
                    if (descriptionController.text.trim().isNotEmpty) {
                      descriptionError = null;
                      issueError = null;
                    }
                  });
                },
              ),
            ),

            // ── Add to report: last step for each item ──
            const SizedBox(height: 16),
            KeyedSubtree(key: addKey, child: _addToReportButton()),

            const SizedBox(height: 28),

            SizedBox(
              key: submitKey,
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: _blue.withValues(alpha: 0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () async {
                  if (validateForm()) {
                    await confirmSubmitReport();
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  selectedItems.isEmpty
                      ? "Submit Report"
                      : "Submit Report (${selectedItems.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
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
                    color: Color(0xFF6B7280),
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

  @override
  void dispose() {
    unawaited(api.logoutReporter());
    employeeIdController.dispose();
    pinController.dispose();
    forgotIdController.dispose();
    _pinFocus.dispose();
    _pinShake.dispose();
    descriptionController.dispose();
    scrollController.dispose();
    _issueSearchTimer?.cancel();
    _locationSearchTimer?.cancel();
    _equipmentSearchTimer?.cancel();
    super.dispose();
  }

  Future<void> addEquipmentItem() async {
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

    final exists = selectedItems.any((item) => item.id == selectedEquipmentId);
    if (exists) {
      setState(() => equipmentError = "That equipment is already added.");
      scrollToField(equipmentKey);
      return;
    }

    if (_draftIssue.isEmpty && _draftDetails.isEmpty) {
      _showMissingIssueError();
      return;
    }

    final equipmentId = selectedEquipmentId!;
    final issue = _draftIssue;
    var checkAnswers = <Map<String, dynamic>>[];

    if (issue.isNotEmpty) {
      if (_addingItem) return;
      _addingItem = true;
      try {
        FocusManager.instance.primaryFocus?.unfocus();
        final checks = await api.getIssueChecks(equipmentId, issue);
        if (!mounted) return;
        if (checks.isNotEmpty) {
          final outcome = await _showQuickChecks(
            equipmentId: equipmentId,
            name: _equipmentNameOf(selectedEquipmentDetails) ??
                selectedEquipmentLabel!,
            issue: issue,
            checks: checks,
          );
          if (!mounted) return;
          if (outcome.status == _QuickCheckStatus.cancelled) return;
          if (outcome.status == _QuickCheckStatus.fixed) {
            _clearListedDraft();
            return;
          }
          checkAnswers = outcome.answers;
        }
      } finally {
        _addingItem = false;
      }
      // The picker may have changed while the checks were open.
      if (selectedEquipmentId != equipmentId) return;
    }

    final item = _ReportEquipmentItem(
      roomId: selectedRoomId!,
      locationLabel: selectedLocation ?? "",
      id: equipmentId,
      displayLabel: selectedEquipmentLabel!,
      issue: issue,
      problemDetails: _draftDetails,
      openReportTicket: _openReportTicketOf(selectedEquipmentDetails ?? {}),
      details: selectedEquipmentDetails,
      checks: checkAnswers,
    );
    setState(() {
      if (selectedItems.isEmpty) showItems = true;
      selectedItems.add(item);
    });
    _clearListedDraft();

    if (!showItems) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              "Added ${_itemShortName(item)} · ${selectedItems.length} in your report.",
            ),
          ),
        );
    }
  }

  void _clearListedDraft() {
    setState(() {
      selectedEquipmentId = null;
      selectedEquipmentLabel = null;
      selectedEquipmentDetails = null;
      selectedSuggestedIssueId = null;
      selectedSuggestedIssueName = null;
      suggestedIssues.clear();
      descriptionController.clear();
    });
  }

  String? _equipmentNameOf(Map<String, dynamic>? details) {
    final name = details?["equipment_name"]?.toString().trim() ?? "";
    return name.isEmpty ? null : name;
  }

  /// Walks the reporter through the issue's quick checks, like the web.
  Future<_QuickCheckOutcome> _showQuickChecks({
    required int equipmentId,
    required String name,
    required String issue,
    required List<Map<String, dynamic>> checks,
  }) async {
    final outcome = await showDialog<_QuickCheckOutcome>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x660F172A),
      builder: (_) => _QuickChecksDialog(
        name: name,
        issue: issue,
        checks: checks,
        onFixed: (checkId) => api.reportSelfFixed(
          equipmentId: equipmentId,
          checkId: checkId,
        ),
      ),
    );
    return outcome ?? const _QuickCheckOutcome(_QuickCheckStatus.cancelled);
  }

  void _showMissingIssueError() {
    const message =
        "Select a suggested issue or describe the problem before adding.";
    setState(() {
      issueError = message;
      descriptionError = message;
    });
    scrollToField(issueKey);
  }

  void _setGateMessage(String? message, [_GateTone tone = _GateTone.error]) {
    setState(() {
      gateMessage = message;
      gateMessageTone = tone;
    });
  }

  /// Step 1 → step 2: the server checks the employee ID and PIN.
  Future<void> _submitPin() async {
    if (isVerifyingPin) return;
    final employeeId = employeeIdController.text.trim();
    final pin = pinController.text.trim();

    if (employeeId.isEmpty) {
      _setGateMessage("Enter your employee ID.");
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _setGateMessage("Enter your 6-digit PIN.");
      _pinShake.forward(from: 0);
      _pinFocus.requestFocus();
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      isVerifyingPin = true;
      gateMessage = null;
    });

    final result = await api.verifyReporterPin(employeeId, pin);
    if (!mounted) return;

    final reporter = result["reporter"];
    if (result["success"] == true && reporter is Map) {
      final verifiedId =
          (reporter["reporter_employee_id"]?.toString() ?? employeeId).trim();
      employeeIdController.text = verifiedId;
      pinController.clear();
      setState(() {
        isVerifyingPin = false;
        showPin = false;
        reporterVerified = true;
        reporterName = reporter["reporter_full_name"]?.toString().trim() ?? "";
        assignedEquipment = [];
      });
      _loadAssignedEquipment(verifiedId);
      if (!_tourChecked) {
        _tourChecked = true;
        _initTour();
      }
      return;
    }

    pinController.clear();
    setState(() {
      isVerifyingPin = false;
      gateMessage = result["message"]?.toString() ??
          "Could not verify. Please try again.";
      gateMessageTone =
          result["code"] == "pending" ? _GateTone.warn : _GateTone.error;
    });
    if (result["code"] == "incorrect" || result["code"] == "locked") {
      HapticFeedback.mediumImpact();
      _pinShake.forward(from: 0);
    }
    _pinFocus.requestFocus();
  }

  void _openForgotPin() {
    forgotIdController.text = employeeIdController.text.trim();
    setState(() {
      showForgotPin = true;
      forgotMessage = null;
      gateMessage = null;
    });
  }

  void _backToVerify() {
    if (employeeIdController.text.trim().isEmpty) {
      employeeIdController.text = forgotIdController.text.trim();
    }
    setState(() => showForgotPin = false);
  }

  Future<void> _sendForgotPin() async {
    if (isSendingForgot) return;
    final employeeId = forgotIdController.text.trim();
    if (employeeId.isEmpty) {
      setState(() {
        forgotMessage = "Enter your employee ID.";
        forgotMessageTone = _GateTone.error;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      isSendingForgot = true;
      forgotMessage = null;
    });

    final result = await api.forgotReporterPin(employeeId);
    if (!mounted) return;

    final ok = result["success"] == true;
    setState(() {
      isSendingForgot = false;
      forgotMessage = result["message"]?.toString() ??
          (ok
              ? "If this employee ID has an email on file, we sent a link to set a new PIN."
              : "Could not send the link. Please try again.");
      forgotMessageTone = ok ? _GateTone.info : _GateTone.error;
    });
  }

  void _switchReporter() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(api.logoutReporter());
    _returnToGate(clearId: true);
  }

  /// Back to step 1. The draft list is kept so a re-verified reporter can still send it.
  void _returnToGate({bool clearId = false, String? message}) {
    api.clearReporterToken();
    if (clearId) employeeIdController.clear();
    pinController.clear();
    setState(() {
      reporterVerified = false;
      reporterName = "";
      assignedEquipment = [];
      showForgotPin = false;
      showPin = false;
      gateMessage = message;
      gateMessageTone = _GateTone.error;
    });
  }

  Future<void> _loadAssignedEquipment(String employeeId) async {
    final items = await api.getAssignedEquipment(employeeId);
    if (!mounted ||
        !reporterVerified ||
        employeeIdController.text.trim() != employeeId) {
      return;
    }
    setState(() => assignedEquipment = items);
  }

  Future<void> pickAssignedEquipment(Map<String, dynamic> item) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final id = _equipmentIdOf(item);
    if (id != null && _addedEquipmentIds.contains(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("That equipment is already in your list."),
        ),
      );
      return;
    }
    final error = await _selectEquipmentItem(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          error ??
              "${item["equipment_name"] ?? "Equipment"} selected. "
                  "Choose an issue or describe the problem, then tap Add.",
        ),
      ),
    );
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

  Widget _tourBanner() {
    return Material(
      color: _blueSoft,
      borderRadius: BorderRadius.circular(_radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radiusSm),
        onTap: startTour,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
          child: Row(
            children: [
              const Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: _blue,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "New here? See how to report",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ),
              IconButton(
                onPressed: _hideTourBanner,
                tooltip: "Dismiss",
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Verified reporter in one row: name, employee ID, and a way to switch.
  Widget _reporterCard() {
    final employeeId = employeeIdController.text.trim();
    final title = reporterName.isNotEmpty ? reporterName : employeeId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: _blueSoft,
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 20,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reporterName.isNotEmpty
                      ? "$employeeId · Verified with PIN"
                      : "Verified with PIN",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          _gateLink("Switch", _switchReporter),
        ],
      ),
    );
  }

  /// Collapsed to one row so it doesn't push the form down.
  Widget _assignedEquipmentBox() {
    final added = _addedEquipmentIds;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(_radiusSm),
            onTap: () => setState(() => showAssigned = !showAssigned),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: _blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your assigned equipment (${assignedEquipment.length})",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: showAssigned ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: !showAssigned
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Tap one to report it.",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: _placeholder,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _assignedEquipmentChips(added),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _itemShortName(_ReportEquipmentItem item) =>
      _equipmentNameOf(item.details) ?? item.displayLabel.split(" · ").first;

  /// Items already added, folded into one row so the form stays short.
  Widget _reportItemsBox() {
    final count = selectedItems.length;
    final names = selectedItems.map(_itemShortName).toList();
    final summary = names.length <= 2
        ? names.join(", ")
        : "${names.take(2).join(", ")} +${names.length - 2} more";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(_radiusSm),
            onTap: () => setState(() => showItems = !showItems),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    size: 18,
                    color: _blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "In your report",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: _blue,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                "$count",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!showItems) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: _placeholder,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: showItems ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: !showItems
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      for (var i = 0; i < count; i++) ...[
                        const Divider(height: 1, thickness: 1, color: _border),
                        _reportItemRow(i, selectedItems[i]),
                      ],
                    ],
                  ),
          ),
          if (itemsError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
    );
  }

  Widget _reportItemRow(int index, _ReportEquipmentItem item) {
    final ticket = item.openReportTicket ?? "";
    final tried = item.triedChecks;
    final meta = [
      "Issue: ${_issueLabel(item)}",
      if (tried > 0) "Tried $tried check${tried == 1 ? "" : "s"}",
    ].join(" · ");

    return InkWell(
      onLongPress: () {
        showEquipmentDetailsDialog(
          title: "Equipment details",
          details: item.details,
          displayLabel: item.displayLabel,
          issue: _issueLabel(item),
          problemDetails: item.problemDetails,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 2, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: _ink,
                    ),
                  ),
                  if (item.locationLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: _blue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                  if (item.problemDetails.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "\u201C${item.problemDetails}\u201D",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                  ],
                  if (ticket.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _alreadyReportedBadge(ticket),
                  ],
                  const SizedBox(height: 8),
                  _itemPhotoControl(item),
                ],
              ),
            ),
            IconButton(
              tooltip: "Remove",
              onPressed: () => _removeItem(index),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alreadyReportedBadge(String ticket) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 13,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              "Already reported · $ticket",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    final item = selectedItems[index];
    setState(() {
      selectedItems.removeAt(index);
      itemsError = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Removed ${_itemShortName(item)}."),
          action: SnackBarAction(
            label: "Undo",
            onPressed: () {
              if (!mounted || selectedItems.any((e) => e.id == item.id)) {
                return;
              }
              setState(() {
                selectedItems.insert(
                  math.min(index, selectedItems.length),
                  item,
                );
              });
            },
          ),
        ),
      );
  }

  Widget _assignedEquipmentChips(Set<int> added) {
    return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: assignedEquipment.map((item) {
              final id = _equipmentIdOf(item);
              final isAdded = id != null && added.contains(id);
              final isSelected = id != null && id == selectedEquipmentId;
              final name =
                  (item["equipment_name"]?.toString() ?? "Equipment").trim();
              final room = (item["room_name"]?.toString() ?? "").trim();
              return Material(
                color: isSelected ? _amber : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : _border,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: isAdded ? null : () => pickAssignedEquipment(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAdded) ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF22C55E),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isAdded ? _placeholder : _ink,
                            ),
                          ),
                        ),
                        if (room.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              room,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _placeholder,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
  }

  Widget _scanQrButton() {
    final enabled = reporterVerified;
    return Material(
      color: enabled ? _blue : _soft,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: scanEquipmentQr,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(_radiusSm),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 20,
                  color: enabled ? _amber : _placeholder,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Scan equipment QR",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: enabled ? Colors.white : _muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? "Fills in the location and equipment for you"
                          : "Enter your Employee ID first",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: enabled
                            ? Colors.white.withValues(alpha: 0.75)
                            : _placeholder,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? Colors.white : _placeholder,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> scanEquipmentQr() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!reporterVerified) return;

    String? scannedName;
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          hint: "Scan the QR label on the equipment to report",
          onCodeScanned: (code) async {
            final result = await _applyScannedEquipment(code);
            if (result.error == null) scannedName = result.name;
            return result.error;
          },
        ),
      ),
    );

    if (!mounted || accepted != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          "${scannedName ?? "Equipment"} selected from QR. "
          "Choose an issue, then tap Add.",
        ),
      ),
    );
  }

  /// Validates a scanned QR and fills location + equipment on success.
  Future<({String? error, String? name})> _applyScannedEquipment(
    String code,
  ) async {
    final res = await api.getReportEquipmentByQr(code);
    if (res["success"] != true || res["equipment"] is! Map) {
      final msg = res["message"]?.toString().trim();
      return (
        error: (msg == null || msg.isEmpty)
            ? "No equipment matches this QR code."
            : msg,
        name: null,
      );
    }

    final item = Map<String, dynamic>.from(res["equipment"] as Map);
    final id = _equipmentIdOf(item);
    if (id != null && _addedEquipmentIds.contains(id)) {
      return (error: "That equipment is already in your list.", name: null);
    }

    final error = await _selectEquipmentItem(item);
    return (
      error: error,
      name: error == null
          ? item["equipment_name"]?.toString() ?? "Equipment"
          : null,
    );
  }

  /// Fills location + equipment from an equipment row that carries `room_id`.
  Future<String?> _selectEquipmentItem(Map<String, dynamic> item) async {
    final id = _equipmentIdOf(item);
    final roomId = int.tryParse(item["room_id"]?.toString() ?? "");
    if (id == null || roomId == null) {
      return "This equipment has no location yet.";
    }

    final roomChanged = roomId != selectedRoomId;
    final room = rooms.cast<dynamic>().firstWhere(
          (r) => r is Map && r["room_id"]?.toString() == roomId.toString(),
          orElse: () => null,
        );
    final roomEquipment = await api.getEquipment(roomId);
    if (!mounted) return null;

    setState(() {
      if (roomChanged) descriptionController.clear();
      selectedRoomId = roomId;
      selectedLocation = room != null
          ? formatRoomLocationLabel(room)
          : (item["location"]?.toString() ?? "");
      equipment = roomEquipment.isNotEmpty ? roomEquipment : [item];
      selectedEquipmentId = id;
      selectedEquipmentLabel = formatEquipmentLabel(item);
      selectedEquipmentDetails = _detailsFromEquipment(item);
      selectedSuggestedIssueId = null;
      selectedSuggestedIssueName = null;
      suggestedIssues.clear();
      locationError = null;
      equipmentError = null;
      itemsError = null;
    });
    loadSuggestedIssues(id);
    return null;
  }

  Future<void> loadSuggestedIssues(int equipmentId) async {
    final data = await api.getSuggestedIssues(equipmentId);
    if (!mounted) return;
    setState(() {
      suggestedIssues = data;
      selectedSuggestedIssueId = null;
      selectedSuggestedIssueName = null;
    });
  }

  Widget _itemPhotoControl(_ReportEquipmentItem item) {
    final photo = item.photo;
    if (photo == null) {
      return Material(
        color: _blueSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFFE0E7FF)),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          onTap: () => pickItemPhoto(item),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_camera_outlined, size: 14, color: _blue),
                SizedBox(width: 6),
                Text(
                  "Add photo",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        GestureDetector(
          onTap: () => showProofImageFullscreen(photo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              photo,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: () => pickItemPhoto(item),
          style: TextButton.styleFrom(
            foregroundColor: _blue,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            "Change",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => item.photo = null),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            "Remove photo",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Future<void> pickItemPhoto(_ReportEquipmentItem item) async {
    final file = await _pickPhoto();
    if (!mounted || file == null) return;
    setState(() => item.photo = file);
  }

  Future<File?> _pickPhoto() async {
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

    if (source == null) return null;

    final image = await picker.pickImage(
      source: source,
      imageQuality: 55,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    return image == null ? null : File(image.path);
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
    final locationCount = selectedItems.map((item) => item.roomId).toSet().length;
    if (selectedItems.length > 1) {
      final scope = locationCount > 1
          ? "from $locationCount locations in one maintenance report"
          : "in one maintenance report";
      if (openReportItems == selectedItems.length) {
        return "Submit ${selectedItems.length} equipment items $scope? "
            "All of them were already reported, so maintenance will see them flagged as priority.";
      }
      if (openReportItems > 0) {
        return "Submit ${selectedItems.length} equipment items $scope? "
            "$openReportItems ${openReportItems == 1 ? "was" : "were"} already reported "
            "and will be flagged as priority.";
      }
      return "Submit ${selectedItems.length} equipment items $scope?";
    }
    final ticket = selectedItems
        .map((item) => item.openReportTicket)
        .firstWhere((ticket) => (ticket ?? "").isNotEmpty, orElse: () => null);
    if (ticket != null) {
      return "This equipment was already reported in $ticket. "
          "Maintenance will see it flagged as priority.";
    }
    return "Send this maintenance report now?";
  }

  Future<void> confirmSubmitReport() async {
    var needsReverify = false;
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x660F172A),
      builder: (dialogContext) {
        var phase = "confirm";
        String errorTitle = "Submission failed";
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
                final items = selectedItems;
                final totalItems = items.length;

                final response = await api.submitReport(
                  employeeId: employeeIdController.text.trim(),
                  roomId: items.first.roomId,
                  equipmentIds: items.map((e) => e.id).toList(),
                  equipmentIssues: items.map((e) => e.issue).toList(),
                  equipmentDetails:
                      items.map((e) => e.problemDetails).toList(),
                  equipmentChecks: items
                      .map((e) => e.checks.isEmpty ? "" : jsonEncode(e.checks))
                      .toList(),
                  equipmentPhotos: {
                    for (final e in items)
                      if (e.photo != null) e.id: e.photo!,
                  },
                );

                if (!dialogContext.mounted) return;

                final data = response.data;
                if (data is Map && data["pin_required"] == true) {
                  needsReverify = true;
                  errorTitle = "Verify again";
                  errorMessage = _reverifyMessage;
                  isSending = false;
                  setDialogState(() => phase = "error");
                  return;
                }
                if (response.statusCode != null &&
                    response.statusCode! >= 400) {
                  errorMessage = data is Map
                      ? (data["message"]?.toString() ?? errorMessage)
                      : errorMessage;
                  isSending = false;
                  setDialogState(() => phase = "error");
                  return;
                }

                final serverMessage =
                    data is Map ? data["message"]?.toString() : null;
                if (serverMessage != null && serverMessage.isNotEmpty) {
                  successMessage = serverMessage;
                } else if (totalItems > 1) {
                  successMessage =
                      "Your report with $totalItems equipment items was sent successfully.";
                }

                final level =
                    data is Map ? data["severity"]?.toString().trim() ?? "" : "";
                final reason = data is Map
                    ? data["severity_reason"]?.toString().trim() ?? ""
                    : "";
                if (level.isNotEmpty) {
                  successMessage += "\n\nPriority: $level."
                      "${reason.isEmpty ? "" : " $reason"}";
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

                  if (data is Map && data["pin_required"] == true) {
                    needsReverify = true;
                    errorTitle = "Verify again";
                    errorMessage = _reverifyMessage;
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
                          color: _blue,
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
                            backgroundColor: _blue,
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
                      Text(
                        errorTitle,
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
                            backgroundColor: _blue,
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
                        color: _blue,
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
                              backgroundColor: _blue,
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

    if (!mounted) return;
    if (submitted == true) {
      // Like the web, verification ends after each submitted report.
      unawaited(api.logoutReporter());
      resetForm();
    } else if (needsReverify) {
      _returnToGate(message: _reverifyMessage);
    }
  }

  static const _reverifyMessage =
      "Your verification expired. Enter your employee ID and PIN again. "
      "Your equipment list is kept.";

  bool validateForm() {
    GlobalKey? firstErrorKey;
    var hasError = false;

    setState(() {
      locationError = null;
      equipmentError = null;
      issueError = null;
      descriptionError = null;
      itemsError = null;
    });

    if (selectedItems.isEmpty && selectedRoomId == null) {
      locationError = "Please select a location.";
      firstErrorKey ??= locationKey;
      hasError = true;
    }

    if (selectedItems.isEmpty) {
      itemsError =
          "Add at least one equipment with a suggested issue or additional details.";
      firstErrorKey ??= itemsKey;
      hasError = true;
    } else if (_draftDetails.isNotEmpty) {
      descriptionError =
          "You wrote details but didn't add that equipment yet. Tap Add to include it, or clear the details.";
      firstErrorKey ??= descriptionKey;
      hasError = true;
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
    pinController.clear();
    descriptionController.clear();
    api.clearReporterToken();

    setState(() {
      reporterVerified = false;
      reporterName = "";
      showForgotPin = false;
      showPin = false;
      gateMessage = null;
      assignedEquipment = [];
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
      showItems = false;
      locationError = null;
      equipmentError = null;
      issueError = null;
      descriptionError = null;
      itemsError = null;
    });
  }

  String _equipmentCategoryNameOf(dynamic item) {
    if (item is! Map) return "";
    return (item["equipment_category_name"] ?? item["category"] ?? "")
        .toString()
        .trim();
  }

  String _equipmentCategoryIdOf(dynamic item) {
    if (item is! Map) return "";
    return (item["equipment_category_id"] ?? "").toString().trim();
  }

  /// Matches web short labels: AVE / CE / Furniture / full name.
  String _equipmentCategoryShortLabel(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return "Other";
    if (n.contains("audio") || n == "ave") return "AVE";
    if (n.contains("computer") || n == "ce") return "CE";
    if (n.contains("furniture")) return "Furniture";
    return name.trim();
  }

  /// Full category name for a chip's long-press tooltip.
  String _equipmentCategoryFullName(String name) {
    final trimmed = name.trim();
    switch (trimmed.toLowerCase()) {
      case "":
        return "Other / uncategorized";
      case "ave":
        return "Audio-Visual Equipment";
      case "ce":
        return "Computer Equipment";
    }
    return trimmed;
  }

  List<({String key, String label, String fullName})>
      _collectEquipmentCategories(List<dynamic> items) {
    final map = <String, ({String label, String fullName})>{};
    for (final item in items) {
      final id = _equipmentCategoryIdOf(item);
      final name = _equipmentCategoryNameOf(item);
      if (id.isEmpty && name.isEmpty) continue;
      final key = id.isNotEmpty ? id : name;
      map.putIfAbsent(
        key,
        () => (
          label: _equipmentCategoryShortLabel(name),
          fullName: _equipmentCategoryFullName(name),
        ),
      );
    }
    final list = map.entries
        .map((e) =>
            (key: e.key, label: e.value.label, fullName: e.value.fullName))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return list;
  }

  Future<void> showSelectionPicker({
    required String title,
    required List<dynamic> items,
    required String Function(dynamic) label,
    required Function(dynamic) onSelected,
    required dynamic selectedItem,
    String searchHint = "Search",
    int? Function(dynamic)? idOf,
    bool enableLongPressDetails = false,
    bool enableCategoryFilter = false,
  }) async {
    String search = "";
    String categoryFilter = "";
    final searchController = TextEditingController();
    final searchFocus = FocusNode();
    final categories =
        enableCategoryFilter ? _collectEquipmentCategories(items) : const [];
    final showCategoryChips = categories.length >= 2;

    void dismissKeyboard() {
      searchFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }

    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xB30B1220),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = items.where((item) {
              if (categoryFilter.isNotEmpty) {
                final catId = _equipmentCategoryIdOf(item);
                final catName = _equipmentCategoryNameOf(item);
                if (catId != categoryFilter && catName != categoryFilter) {
                  return false;
                }
              }
              if (search.trim().isEmpty) return true;
              final haystack = [
                label(item),
                _equipmentCategoryNameOf(item),
                if (item is Map) ...[
                  item["equipment_asset_tag"]?.toString() ?? "",
                  item["equipment_serial_number"]?.toString() ?? "",
                  item["equipment_brand_name"]?.toString() ?? "",
                  item["equipment_model"]?.toString() ?? "",
                ],
              ].join(" ").toLowerCase();
              return haystack.contains(search.trim().toLowerCase());
            }).toList();

            final media = MediaQuery.of(context);
            final maxHeight = media.size.height * 0.78;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  maxHeight: maxHeight.clamp(320.0, 640.0),
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "CHOOSE AN OPTION",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                      color: _blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  if (enableLongPressDetails) ...[
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Hold an item to see full details",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFE8ECF4),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  dismissKeyboard();
                                  Navigator.pop(dialogContext);
                                },
                                child: const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE8ECF4)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.only(left: 16, right: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: _ink,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  focusNode: searchFocus,
                                  textInputAction: TextInputAction.search,
                                  onChanged: (value) {
                                    setModalState(() => search = value);
                                  },
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    hintText: searchHint,
                                    hintStyle: const TextStyle(
                                      color: _placeholder,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 22,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                color: const Color(0xFFEEF0F4),
                              ),
                              IconButton(
                                tooltip: "Search",
                                onPressed: () => setModalState(() {}),
                                icon: const Icon(
                                  Icons.tune_rounded,
                                  color: _ink,
                                  size: 22,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showCategoryChips)
                        SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            children: [
                              _categoryChip(
                                label: "All",
                                tooltip: "All categories",
                                selected: categoryFilter.isEmpty,
                                onTap: () => setModalState(
                                  () => categoryFilter = "",
                                ),
                              ),
                              ...categories.map(
                                (cat) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _categoryChip(
                                    label: cat.label,
                                    tooltip: cat.fullName,
                                    selected: categoryFilter == cat.key,
                                    onTap: () => setModalState(
                                      () => categoryFilter = cat.key,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Text(
                                    items.isEmpty && enableLongPressDetails
                                        ? "All equipment for this location is already added."
                                        : categoryFilter.isNotEmpty
                                            ? "No equipment in this category."
                                            : "No matches. Try another search.",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  8,
                                  10,
                                  8,
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
                                  final text = label(item);

                                  return Material(
                                    color: selected
                                        ? _blueSoft
                                        : openReportTicket != null
                                            ? const Color(0xFFFFFBEB)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        dismissKeyboard();
                                        onSelected(item);
                                        Navigator.pop(dialogContext);
                                      },
                                      onLongPress: enableLongPressDetails
                                          ? () {
                                              dismissKeyboard();
                                              showEquipmentDetailsDialog(
                                                title: "Equipment details",
                                                details:
                                                    _detailsFromEquipment(item),
                                                displayLabel: text,
                                              );
                                            }
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              text,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: selected ? _blue : _ink,
                                                height: 1.35,
                                              ),
                                            ),
                                            if (openReportTicket != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                "Open report: $openReportTicket",
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFFB45309),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: () {
                              dismissKeyboard();
                              Navigator.pop(dialogContext);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text(
                              "Done",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
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
          },
        );
      },
    );

    searchController.dispose();
    searchFocus.dispose();
  }

  Widget _categoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final chip = Material(
      color: selected ? const Color(0xFFEEF2FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? _blue : const Color(0xFFE5E7EB),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? _blue : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip.trim().isEmpty) return chip;

    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.longPress,
      preferBelow: true,
      verticalOffset: 22,
      showDuration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: chip,
    );
  }

  Widget _sheetActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _soft,
      borderRadius: BorderRadius.circular(_radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
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
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Color(0xFF0F172A),
        height: 1.25,
      ),
    );
  }

  Widget _selectRow({
    required IconData icon,
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: const Color(0xFF64748B), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasValue ? "Selected" : "Tap to choose",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasValue ? value : placeholder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: hasValue
                                ? const Color(0xFF0F172A)
                                : _placeholder,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
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

  static final _employeeIdFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(20),
    const _UpperCaseTextFormatter(),
  ];

  /// Step 1 of 2: employee ID + PIN (or the forgot-PIN form).
  Widget _buildGate(double topInset) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _amber,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  "CAMPUS REPORT",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: _ink,
                  ),
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE8ECF4)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.maybePop(context),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            showForgotPin ? "Forgot your PIN?" : "Verify it's you",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: _ink,
            ),
          ),
          if (showForgotPin) ...[
            const SizedBox(height: 6),
            const Text(
              "We'll email you a link to set a new PIN.",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _muted,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (showForgotPin) ..._forgotPinFields() else ..._verifyFields(),
          const SizedBox(height: 24),
          Text(
            showForgotPin
                ? "No email on file? Ask the maintenance office to reset your PIN."
                : "No PIN yet? Check your email or ask the maintenance office.",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _placeholder,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _verifyFields() => [
        _buildSectionTitle("Employee ID"),
        const SizedBox(height: 8),
        TextField(
          controller: employeeIdController,
          readOnly: isVerifyingPin,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          inputFormatters: _employeeIdFormatters,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          decoration: _fieldDecoration(
            hintText: "EMPLOYEE ID",
            prefixIcon: const Icon(
              Icons.face_retouching_natural_rounded,
              color: _blue,
              size: 22,
            ),
          ),
          onChanged: (_) {
            if (gateMessage != null) _setGateMessage(null);
          },
          onSubmitted: (_) {
            if (pinController.text.length == 6) {
              _submitPin();
            } else {
              _pinFocus.requestFocus();
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSectionTitle("PIN")),
            _gateLink("Forgot PIN?", _openForgotPin),
          ],
        ),
        const SizedBox(height: 4),
        _pinField(),
        if (isVerifyingPin) ...[
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
              ),
              SizedBox(width: 10),
              Text(
                "Checking…",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
        ] else if (gateMessage != null) ...[
          const SizedBox(height: 12),
          _gateMessageBox(gateMessage!, gateMessageTone),
        ],
      ];

  /// Six dot slots drawn over an invisible field, so the system number
  /// keyboard, paste and autofill keep working.
  Widget _pinField() {
    final pin = pinController.text;
    final hasError = gateMessage != null && gateMessageTone == _GateTone.error;
    final focused = _pinFocus.hasFocus;

    return AnimatedBuilder(
      animation: _pinShake,
      builder: (context, child) {
        final t = _pinShake.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: hasError
                ? const Color(0xFFEF4444)
                : focused
                    ? _blue
                    : _borderSoft,
            width: hasError || focused ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 48),
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 6; i++)
                          _pinSlot(i < pin.length ? pin[i] : null),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      alwaysIncludeSemantics: true,
                      child: TextField(
                        controller: pinController,
                        focusNode: _pinFocus,
                        readOnly: isVerifyingPin,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: "",
                        ),
                        onTap: () => pinController.selection =
                            TextSelection.collapsed(
                          offset: pinController.text.length,
                        ),
                        onChanged: (value) {
                          setState(() => gateMessage = null);
                          if (value.length == 6) _submitPin();
                        },
                        onSubmitted: (_) => _submitPin(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: showPin ? "Hide PIN" : "Show PIN",
                onPressed: () => setState(() => showPin = !showPin),
                icon: Icon(
                  showPin
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grey dot while empty; dark dot (or the digit when shown) once typed.
  Widget _pinSlot(String? digit) {
    return SizedBox(
      width: 26,
      height: 28,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: digit != null && showPin
              ? Text(
                  digit,
                  key: ValueKey("d$digit"),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                )
              : Container(
                  key: ValueKey(digit == null ? "empty" : "dot"),
                  width: digit == null ? 8 : 10,
                  height: digit == null ? 8 : 10,
                  decoration: BoxDecoration(
                    color: digit == null ? const Color(0xFFCBD5E1) : _ink,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _forgotPinFields() => [
        _buildSectionTitle("Employee ID"),
        const SizedBox(height: 8),
        TextField(
          controller: forgotIdController,
          readOnly: isSendingForgot,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.send,
          inputFormatters: _employeeIdFormatters,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          decoration: _fieldDecoration(
            hintText: "EMPLOYEE ID",
            prefixIcon: const Icon(
              Icons.face_retouching_natural_rounded,
              color: _blue,
              size: 22,
            ),
          ),
          onSubmitted: (_) => _sendForgotPin(),
        ),
        if (forgotMessage != null) ...[
          const SizedBox(height: 12),
          _gateMessageBox(forgotMessage!, forgotMessageTone),
        ],
        const SizedBox(height: 22),
        _gatePrimaryButton(
          label: isSendingForgot ? "Sending…" : "Send reset link",
          busy: isSendingForgot,
          icon: Icons.mail_outline_rounded,
          onPressed: _sendForgotPin,
        ),
        const SizedBox(height: 8),
        Center(child: _gateLink("Back to verify", _backToVerify)),
      ];

  Widget _gateLink(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _blue,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _gatePrimaryButton({
    required String label,
    required bool busy,
    required VoidCallback onPressed,
    IconData icon = Icons.arrow_forward_rounded,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _blue.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
            ),
            const SizedBox(width: 8),
            busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _gateMessageBox(String text, _GateTone tone) {
    final (fg, bg, icon) = switch (tone) {
      _GateTone.error => (
          const Color(0xFFB91C1C),
          const Color(0xFFFEF2F2),
          Icons.error_outline_rounded,
        ),
      _GateTone.warn => (
          const Color(0xFF92400E),
          const Color(0xFFFFFBEB),
          Icons.hourglass_top_rounded,
        ),
      _GateTone.info => (
          _blue,
          _blueSoft,
          Icons.mark_email_read_outlined,
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    String? hintText,
    String? errorText,
    Widget? prefixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: _borderSoft),
    );
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(
        color: Color(0xFF9AA1B5),
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.4,
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFEF4444),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: _blue),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}

/// Quick checks shown after picking a suggested issue, before the item is added.
/// "That fixed it" ends with no report; a safety "Yes" goes straight to the report.
class _QuickChecksDialog extends StatefulWidget {
  final String name;
  final String issue;
  final List<Map<String, dynamic>> checks;
  final void Function(int checkId) onFixed;

  const _QuickChecksDialog({
    required this.name,
    required this.issue,
    required this.checks,
    required this.onFixed,
  });

  @override
  State<_QuickChecksDialog> createState() => _QuickChecksDialogState();
}

enum _QuickCheckPanel { step, fixed, danger }

class _QuickChecksDialogState extends State<_QuickChecksDialog> {
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF6B7280);
  static const _blue = Color(0xFF0025CC);
  static const _border = Color(0xFFE5E7EB);
  static const _green = Color(0xFF059669);
  static const _red = Color(0xFFDC2626);

  int index = 0;
  late final List<Map<String, dynamic>?> answers =
      List.filled(widget.checks.length, null);
  _QuickCheckPanel panel = _QuickCheckPanel.step;
  String dangerText = "";

  Map<String, dynamic> get check => widget.checks[index];

  bool get isQuestion => check["kind"] == "question";

  int? _idOf(Map<String, dynamic> check) =>
      int.tryParse(check["id"]?.toString() ?? "");

  List<Map<String, dynamic>> get _givenAnswers => answers
      .take(index + 1)
      .whereType<Map<String, dynamic>>()
      .toList();

  void _answer(String answer) {
    final id = _idOf(check);
    answers[index] = {"id": id, "answer": answer};

    if (answer == "fixed") {
      if (id != null) widget.onFixed(id);
      setState(() => panel = _QuickCheckPanel.fixed);
      return;
    }

    if (check["safety"] == true && answer == "yes") {
      final hint = check["hint"]?.toString().trim() ?? "";
      setState(() {
        dangerText = "${hint.isEmpty ? "" : "$hint "}"
            "Maintenance will get this report as Critical.";
        panel = _QuickCheckPanel.danger;
      });
      return;
    }

    if (index + 1 < widget.checks.length) {
      setState(() => index += 1);
      return;
    }

    _finish(_QuickCheckStatus.done);
  }

  void _finish(_QuickCheckStatus status) {
    Navigator.of(context).pop(
      _QuickCheckOutcome(
        status,
        status == _QuickCheckStatus.cancelled ? const [] : _givenAnswers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 14),
              switch (panel) {
                _QuickCheckPanel.step => _stepPanel(),
                _QuickCheckPanel.fixed => _resultPanel(
                    icon: Icons.check_rounded,
                    color: _green,
                    background: const Color(0xFFECFDF5),
                    title: "Great, it works now",
                    text:
                        "No report needed for this equipment. Thanks for checking first.",
                    buttonLabel: "Done",
                    buttonColor: _blue,
                    onPressed: () => _finish(_QuickCheckStatus.fixed),
                  ),
                _QuickCheckPanel.danger => _resultPanel(
                    icon: Icons.warning_amber_rounded,
                    color: _red,
                    background: const Color(0xFFFEF2F2),
                    title: "Report this right away",
                    text: dangerText,
                    buttonLabel: "Add to report",
                    buttonColor: _red,
                    onPressed: () => _finish(_QuickCheckStatus.done),
                  ),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "QUICK CHECKS",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                "Let's try a few things first",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "${widget.name} · ${widget.issue}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: _border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _finish(_QuickCheckStatus.cancelled),
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.close_rounded, size: 18, color: _muted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepPanel() {
    final hint = check["hint"]?.toString().trim() ?? "";
    final buttons = isQuestion
        ? [
            _answerButton("Yes", "yes"),
            _answerButton("No", "no"),
          ]
        : [
            _answerButton(
              "That fixed it",
              "fixed",
              background: const Color(0xFFECFDF5),
              foreground: _green,
              borderColor: const Color(0xFFA7F3D0),
            ),
            _answerButton(
              "Still not working",
              "not_fixed",
              background: _blue,
              foreground: Colors.white,
              borderColor: _blue,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.checks.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < index
                        ? _blue
                        : i == index
                            ? const Color(0xFFA5B4FC)
                            : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Step ${index + 1} of ${widget.checks.length}",
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          check["question"]?.toString() ?? "",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink,
            height: 1.3,
          ),
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEEF2F7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: buttons[0]),
            const SizedBox(width: 10),
            Expanded(child: buttons[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Visibility(
              visible: index > 0,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: TextButton(
                onPressed: () => setState(() => index -= 1),
                style: TextButton.styleFrom(
                  foregroundColor: _blue,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  "Back",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "If one fixes it, you won't need to report.",
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _answerButton(
    String label,
    String answer, {
    Color background = Colors.white,
    Color foreground = _ink,
    Color borderColor = _border,
  }) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: () => _answer(answer),
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _resultPanel({
    required IconData icon,
    required Color color,
    required Color background,
    required String title,
    required String text,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
