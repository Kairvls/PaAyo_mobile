import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';


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

class _ReportScreenState extends State<ReportScreen> {
    static const _ink = Color(0xFF0F172A);
    static const _muted = Color(0xFF64748B);
    static const _soft = Color(0xFFF3F4F6);
    static const _blue = Color(0xFF2563EB);
    static const _chip = Color(0xFFEAF1FF);

    String issueSearch = "";
    Timer? _issueSearchTimer;
    Timer? _locationSearchTimer;
    Timer? _equipmentSearchTimer;
    final TextEditingController employeeIdController =
        TextEditingController();

    final TextEditingController descriptionController =
        TextEditingController();

    bool reporterVerified = false;

    String reporterName = "";

    final ApiService api = ApiService();

    Timer? _verifyTimer;

    bool isCheckingReporter = false;

    String? reporterError;

    bool equipmentNotListed = false;

    String priority = "Non-Urgent";

    // ==========================================
    // SUGGESTED ISSUES
    // ==========================================

    List<dynamic> suggestedIssues = [];

    int? selectedSuggestedIssueId;

    // ==========================================
    // LOCATION
    // ==========================================

    List<dynamic> rooms = [];

    int? selectedRoomId;

    String? selectedLocation;

    bool showAllGlobalIssues = false;

    // ==========================================
    // EQUIPMENT
    // ==========================================

    List<dynamic> equipment = [];

    String? selectedEquipment;

    int? selectedEquipmentId;

    final TextEditingController equipmentController =
        TextEditingController();

    final List<PriorityOption> priorities = [

    const PriorityOption(

        label: "Non Urgent",
        value: "Non-Urgent",
        description: "Minor maintenance concern",

    ),

    const PriorityOption(

        label: "Urgent",
        value: "Urgent",
        description: "Needs immediate action",

    ),

    ];

    File? selectedImage;

    String? employeeIdError;
    String? locationError;
    String? equipmentError;
    String? issueError;
    String? descriptionError;

    final employeeKey = GlobalKey();
    final locationKey = GlobalKey();
    final equipmentKey = GlobalKey();
    final issueKey = GlobalKey();
    final descriptionKey = GlobalKey();

    final ScrollController scrollController =
    ScrollController();
        

    @override
    void initState() {
        super.initState();

        loadRooms();
        }

    List<dynamic> get visibleSuggestedIssues {

        if (!equipmentNotListed) {
            return suggestedIssues;
        }

        if (showAllGlobalIssues) {
            return suggestedIssues;
        }

        return suggestedIssues.take(5).toList();
        }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Report an issue",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  // ===========================
                  // REPORTER CARD
                  // ===========================
                  _buildSectionTitle("Reporter"),
                  const SizedBox(height: 10),
                  _softCard(
                    child: Column(
                      children: [
                        KeyedSubtree(
                          key: employeeKey,
                          child: _textInputRow(
                            icon: Icons.badge_outlined,
                            iconColor: _blue,
                            controller: employeeIdController,
                            hint: "Enter Employee ID",
                            errorText: employeeIdError,
                            onChanged: (_) {
                              _verifyTimer?.cancel();
                              setState(() {
                                employeeIdError = null;
                                reporterVerified = false;
                                reporterName = "";
                                reporterError = null;
                                isCheckingReporter = false;
                              });
                              if (employeeIdController.text.trim().isEmpty) {
                                return;
                              }
                              _verifyTimer = Timer(
                                const Duration(milliseconds: 600),
                                verifyReporter,
                              );
                            },
                          ),
                        ),
                        _rowDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                          child: Row(
                            children: [
                              _statusDot(),
                              const SizedBox(width: 12),
                              Expanded(child: _reporterStatusText()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ===========================
                  // LOCATION + EQUIPMENT CARD
                  // ===========================
                  _buildSectionTitle("Where & what"),
                  const SizedBox(height: 10),
                  _softCard(
                    child: Column(
                      children: [
                        KeyedSubtree(
                          key: locationKey,
                          child: _selectRow(
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
                                label: (room) => room["location"],
                                onSelected: (room) {
                                  locationError = null;
                                  setState(() {
                                    selectedLocation = room["location"];
                                    selectedRoomId = room["room_id"];
                                  });
                                  loadEquipment(room["room_id"]);
                                },
                              );
                            },
                          ),
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
                                    setState(() {
                                      equipmentError = null;
                                    });
                                  },
                                )
                              : _selectRow(
                                  icon: Icons.devices_other_rounded,
                                  iconColor: _blue,
                                  value: selectedEquipment,
                                  placeholder: "Select equipment",
                                  errorText: equipmentError,
                                  onTap: () {
                                    showSelectionBottomSheet(
                                      title: "Select Equipment",
                                      items: equipment,
                                      selectedItem: selectedEquipmentId,
                                      icon: Icons.computer_rounded,
                                      label: (item) => item["equipment_name"],
                                      onSelected: (item) {
                                        equipmentError = null;
                                        setState(() {
                                          selectedEquipment =
                                              item["equipment_name"];
                                          selectedEquipmentId =
                                              item["equipment_id"];
                                        });
                                        loadSuggestedIssues(
                                          item["equipment_id"],
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  _softCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SwitchListTile(
                      value: equipmentNotListed,
                      onChanged: (value) async {
                        setState(() {
                          equipmentNotListed = value;
                          if (value) {
                            selectedEquipment = null;
                            selectedEquipmentId = null;
                          } else {
                            equipmentController.clear();
                          }
                          selectedSuggestedIssueId = null;
                        });
                        if (value) {
                          await loadGlobalSuggestedIssues();
                        } else {
                          suggestedIssues.clear();
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: _blue,
                      title: const Text(
                        "Equipment not listed",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _ink,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ===========================
                  // SUGGESTED ISSUE
                  // ===========================
                  _buildSectionTitle("Suggested issue"),
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
                                      ? "Enable Equipment Not Listed to load global suggested issues."
                                      : "Select equipment first to see suggested issues.",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              ...visibleSuggestedIssues.map((issue) {
                                final selected =
                                    selectedSuggestedIssueId ==
                                    issue["issue_template_id"];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _optionCard(
                                    title: issue["issue_template_name"]
                                        .toString(),
                                    subtitle: "Suggested template",
                                    selected: selected,
                                    onTap: () {
                                      setState(() {
                                        selectedSuggestedIssueId =
                                            issue["issue_template_id"];
                                        issueError = null;
                                        descriptionError = null;
                                      });
                                    },
                                  ),
                                );
                              }),
                              if (equipmentNotListed &&
                                  !showAllGlobalIssues &&
                                  suggestedIssues.length > 5)
                                _optionCard(
                                  title:
                                      "+${suggestedIssues.length - 5} more issues",
                                  subtitle: "Browse all templates",
                                  selected: false,
                                  leading: const Icon(
                                    Icons.search_rounded,
                                    size: 22,
                                    color: _blue,
                                  ),
                                  onTap: () {
                                    showSelectionBottomSheet(
                                      title: "Select Suggested Issue",
                                      items: suggestedIssues,
                                      selectedItem: selectedSuggestedIssueId,
                                      icon: Icons.build_circle_outlined,
                                      label: (item) =>
                                          item["issue_template_name"],
                                      onSelected: (item) {
                                        issueError = null;
                                        descriptionError = null;
                                        setState(() {
                                          selectedSuggestedIssueId =
                                              item["issue_template_id"];
                                        });
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                  ),
                  if (issueError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        issueError!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 22),

                  // ===========================
                  // DESCRIPTION
                  // ===========================
                  _buildSectionTitle("Description"),
                  const SizedBox(height: 10),
                  KeyedSubtree(
                    key: descriptionKey,
                    child: _softCard(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: TextField(
                        controller: descriptionController,
                        maxLines: 5,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          color: _ink,
                        ),
                        decoration: _minimalInputDecoration(
                          hintText: "Describe the problem...",
                          errorText: descriptionError,
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            14,
                            16,
                            14,
                          ),
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

                  // ===========================
                  // PRIORITY
                  // ===========================
                  _buildSectionTitle("Priority"),
                  const SizedBox(height: 10),
                  Row(
                    children: priorities.map((item) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: item == priorities.first ? 6 : 0,
                            left: item == priorities.last ? 6 : 0,
                          ),
                          child: _buildPriorityCard(
                            option: item,
                            selected: priority == item.value,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),

                  // ===========================
                  // PHOTO
                  // ===========================
                  _buildSectionTitle("Photo (optional)"),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      height: 148,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8EEF5)),
                      ),
                      child: selectedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 32,
                                  color: _blue,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Add a photo",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _ink,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "PNG · JPG · JPEG",
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: Image.file(
                                selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===========================
                  // SUBMIT
                  // ===========================
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        if (validateForm()) {
                          await confirmSubmitReport();
                        }
                      },
                      child: const Text(
                        "Submit report",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
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

    super.dispose();

    _issueSearchTimer?.cancel();
    _locationSearchTimer?.cancel();
    _equipmentSearchTimer?.cancel();

    }

    Future<void> verifyReporter() async {

        final employeeId = employeeIdController.text.trim();

        if (employeeId.isEmpty) {

        return;

        }

        setState(() {

            isCheckingReporter = true;

            reporterVerified = false;

            reporterError = null;

        });

        

        final reporter = await api.verifyReporter(employeeId);

        if (!mounted) return;

        

        if (reporter != null) {

            setState(() {

                reporterVerified = true;
                reporterName = reporter["reporter_full_name"] ?? "";
                reporterError = null;

                employeeIdError = null;

                isCheckingReporter = false;

            });

        } else {

            setState(() {

                reporterVerified = false;
                reporterName = "";
                reporterError = "Employee ID not found.";

                employeeIdError =
                    "Please enter a valid Employee ID.";

                isCheckingReporter = false;

            });

        }

        }

    Future<void> loadRooms() async {

    final data = await api.getRooms();

    if (!mounted) return;

    setState(() {
        rooms = data;
    });
    }

    Future<void> loadEquipment(int roomId) async {

        final data = await api.getEquipment(roomId);

        if (!mounted) return;

        setState(() {

            equipment = data;

            selectedEquipment = null;

            selectedEquipmentId = null;

        });

        }

    Future<void> loadSuggestedIssues(
        int equipmentId,
    ) async {

        final data =
            await api.getSuggestedIssues(
                equipmentId,
            );

        if (!mounted) return;

        setState(() {

            suggestedIssues = data;

            selectedSuggestedIssueId = null;

        });

    }

    Future<void> loadGlobalSuggestedIssues() async {

        final data =
            await api.getGlobalSuggestedIssues();

        if (!mounted) return;

        setState(() {

            suggestedIssues = data;

            selectedSuggestedIssueId = null;

            showAllGlobalIssues = false;

        });

    }

    Future<void> pickImage() async {

        final picker = ImagePicker();

        final source = await showModalBottomSheet<ImageSource>(
            context: context,
            backgroundColor: Colors.transparent,
            barrierColor: const Color(0x660F172A),
            isScrollControlled: true,
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Add a photo",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sheetActionTile(
                            icon: Icons.photo_camera_rounded,
                            title: "Take photo",
                            subtitle: "Use your camera",
                            onTap: () =>
                                Navigator.pop(context, ImageSource.camera),
                          ),
                          const SizedBox(height: 8),
                          _sheetActionTile(
                            icon: Icons.photo_library_rounded,
                            title: "Choose from gallery",
                            subtitle: "Pick an existing image",
                            onTap: () =>
                                Navigator.pop(context, ImageSource.gallery),
                          ),
                        ],
                      ),
                    ),
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

        if (image == null) return;

        setState(() {
            selectedImage = File(image.path);
        });
        }

    Future<void> confirmSubmitReport() async {
        final submitted = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            barrierColor: const Color(0x660F172A),
            builder: (dialogContext) {
              var phase = "confirm"; // confirm | submitting | success | error
              String errorMessage = "Failed to submit report.";
              var isSending = false;

              return StatefulBuilder(
                builder: (context, setDialogState) {
                  Future<void> sendReport() async {
                    if (isSending) return;
                    isSending = true;
                    setDialogState(() => phase = "submitting");

                    try {
                      await api.submitReport(
                        employeeId: employeeIdController.text.trim(),
                        roomId: selectedRoomId!,
                        equipmentId: equipmentNotListed
                            ? null
                            : selectedEquipmentId,
                        manualEquipmentName: equipmentNotListed
                            ? equipmentController.text.trim()
                            : null,
                        issueTemplateId: selectedSuggestedIssueId,
                        description: descriptionController.text.trim(),
                        priority: priority,
                        photo: selectedImage,
                      );
                      if (!dialogContext.mounted) return;
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
                              trimmed.startsWith("<html") ||
                              trimmed.contains("<title>Laravel</title>")) {
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
                            employeeIdError =
                                "Please enter a valid Employee ID.";
                          });
                        }
                      }

                      if (!dialogContext.mounted) return;
                      isSending = false;
                      setDialogState(() => phase = "error");
                    }
                  }

                  Widget iconBubble({
                    required Color bg,
                    required IconData icon,
                    required Color iconColor,
                    Widget? child,
                  }) {
                    return Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                      ),
                      child: child ??
                          Icon(icon, color: iconColor, size: 24),
                    );
                  }

                  if (phase == "submitting") {
                    return Dialog(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      insetPadding:
                          const EdgeInsets.symmetric(horizontal: 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
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
                              "Submitting report…",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Please wait a moment.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: _muted,
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
                      insetPadding:
                          const EdgeInsets.symmetric(horizontal: 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            iconBubble(
                              bg: const Color(0xFFECFDF5),
                              icon: Icons.check_rounded,
                              iconColor: const Color(0xFF059669),
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
                            const Text(
                              "Your maintenance report was sent successfully.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
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
                                    Navigator.pop(dialogContext, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
                      insetPadding:
                          const EdgeInsets.symmetric(horizontal: 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            iconBubble(
                              bg: const Color(0xFFFEF2F2),
                              icon: Icons.error_outline_rounded,
                              iconColor: const Color(0xFFDC2626),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Submit failed",
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
                                onPressed: sendReport,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  "Try again",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                style: TextButton.styleFrom(
                                  foregroundColor: _muted,
                                ),
                                child: const Text(
                                  "Close",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
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
                    insetPadding:
                        const EdgeInsets.symmetric(horizontal: 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          iconBubble(
                            bg: _chip,
                            icon: Icons.send_rounded,
                            iconColor: _blue,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Submit report?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Your maintenance report will be sent for review.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                              onPressed: sendReport,
                              style: FilledButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "Submit",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              style: TextButton.styleFrom(
                                foregroundColor: _muted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
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

            if (isCheckingReporter) {

                employeeIdError =
                    "Please wait while verifying Employee ID.";

                setState(() {});

                return false;

            }
            GlobalKey? firstErrorKey;

            bool hasError = false;

            setState(() {

                employeeIdError = null;
                locationError = null;
                equipmentError = null;
                issueError = null;
                descriptionError = null;

            });

            // =====================================
            // Employee
            // =====================================

            if (!reporterVerified || reporterError != null) {

                employeeIdError =
                    "Please enter a valid Employee ID.";
                firstErrorKey ??= employeeKey;

                hasError = true;

            }

            // =====================================
            // Location
            // =====================================

            if (selectedRoomId == null) {

                locationError =
                    "Please select a location.";
                firstErrorKey ??= locationKey;

                hasError = true;

            }

            // =====================================
            // Equipment
            // =====================================

            if (equipmentNotListed) {

                if (equipmentController.text.trim().isEmpty) {

                    equipmentError =
                        "Please enter the equipment name.";
                        firstErrorKey ??= equipmentKey;

                    hasError = true;

                }

            } else {

                if (selectedEquipmentId == null) {

                    equipmentError =
                        "Please select equipment.";
                    firstErrorKey ??= equipmentKey;

                    hasError = true;

                }

            }

            // =====================================
            // Suggested Issue OR Description
            // =====================================

            final hasIssue =
                selectedSuggestedIssueId != null;

            final hasDescription =
                descriptionController.text
                    .trim()
                    .isNotEmpty;

            if (!hasIssue && !hasDescription) {

                issueError =
                    "Select a suggested issue or enter a description.";

                descriptionError =
                    "Select a suggested issue or enter a description.";

                firstErrorKey ??= equipmentKey;

                hasError = true;

            }

            setState(() {});

            if (hasError) {

                WidgetsBinding.instance.addPostFrameCallback((_) {

                    if (firstErrorKey != null) {

                        scrollToField(firstErrorKey!);

                    }

                });

                return false;

            }

            return true;

        }

        void scrollToField(GlobalKey key) {
            final context = key.currentContext;

            if (context != null) {
                Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                alignment: 0.15,
                );
            }
            }

    Future<void> showSelectionBottomSheet({
        required String title,
        required List<dynamic> items,
        required String Function(dynamic) label,
        required Function(dynamic) onSelected,
        required IconData icon,
        required dynamic selectedItem,
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
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            barrierColor: const Color(0x660F172A),
            builder: (context) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            return StatefulBuilder(
                builder: (context, setBottomState) {
                final filtered = items.where((item) {
                    return label(item)
                        .toLowerCase()
                        .contains(search.toLowerCase());
                }).toList();

                return AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Material(
                        color: Colors.white,
                        elevation: 0,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.78,
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                          color: _ink,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        dismissKeyboard();
                                        Navigator.pop(context);
                                      },
                                      style: IconButton.styleFrom(
                                        backgroundColor: _soft,
                                      ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: _muted,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                                child: Container(
                                  height: 52,
                                  padding: const EdgeInsets.only(left: 16, right: 6),
                                  decoration: BoxDecoration(
                                    color: _soft,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.search_rounded,
                                        size: 22,
                                        color: _muted,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: searchController,
                                          focusNode: searchFocus,
                                          autofocus: false,
                                          onChanged: (value) {
                                            setBottomState(() => search = value);
                                          },
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w500,
                                            color: _ink,
                                          ),
                                          decoration: const InputDecoration(
                                            isCollapsed: true,
                                            border: InputBorder.none,
                                            hintText: "Search...",
                                            hintStyle: TextStyle(
                                              color: _muted,
                                              fontWeight: FontWeight.w400,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (search.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: () {
                                            searchController.clear();
                                            setBottomState(() => search = "");
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.cancel_rounded,
                                              size: 18,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                      ],
                                      Container(
                                        width: 1,
                                        height: 22,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                      IconButton(
                                        tooltip: "Filter",
                                        onPressed: () {},
                                        icon: const Icon(
                                          Icons.tune_rounded,
                                          color: _muted,
                                          size: 22,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Text(
                                      "${filtered.length} result${filtered.length == 1 ? "" : "s"}",
                                      key: ValueKey(filtered.length),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _muted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: filtered.isEmpty
                                      ? const Center(
                                          key: ValueKey("empty"),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 32),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.search_off_rounded,
                                                  size: 44,
                                                  color: Color(0xFFCBD5E1),
                                                ),
                                                SizedBox(height: 12),
                                                Text(
                                                  "No results found",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: _ink,
                                                  ),
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  "Try another keyword.",
                                                  style: TextStyle(
                                                    color: _muted,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          key: ValueKey("list-${filtered.length}-$search"),
                                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                          itemCount: filtered.length,
                                          itemBuilder: (_, index) {
                                            final item = filtered[index];
                                            final selected =
                                                selectedItem == item.values.first;
                                            return TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0, end: 1),
                                              duration: Duration(
                                                milliseconds: 220 + (index.clamp(0, 8) * 28),
                                              ),
                                              curve: Curves.easeOutCubic,
                                              builder: (context, t, child) {
                                                return Opacity(
                                                  opacity: t,
                                                  child: Transform.translate(
                                                    offset: Offset(0, (1 - t) * 12),
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Material(
                                                  color: selected ? _chip : _soft,
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(16),
                                                    onTap: () {
                                                      dismissKeyboard();
                                                      onSelected(item);
                                                      Navigator.pop(context);
                                                    },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 180),
                                                      curve: Curves.easeOutCubic,
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 12,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(
                                                          color: selected
                                                              ? _blue.withValues(alpha: 0.35)
                                                              : Colors.transparent,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          AnimatedContainer(
                                                            duration: const Duration(milliseconds: 180),
                                                            width: 42,
                                                            height: 42,
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Icon(
                                                              icon,
                                                              color: selected ? _blue : _ink,
                                                              size: 20,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: Text(
                                                              label(item),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 14.5,
                                                                color: _ink,
                                                              ),
                                                            ),
                                                          ),
                                                          AnimatedSwitcher(
                                                            duration: const Duration(milliseconds: 180),
                                                            child: selected
                                                                ? const Icon(
                                                                    key: ValueKey("check"),
                                                                    Icons.check_circle_rounded,
                                                                    color: _blue,
                                                                    size: 22,
                                                                  )
                                                                : const Icon(
                                                                    key: ValueKey("chevron"),
                                                                    Icons.chevron_right_rounded,
                                                                    color: Color(0xFFCBD5E1),
                                                                    size: 22,
                                                                  ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
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
            },
        );

        searchController.dispose();
        searchFocus.dispose();

        if (!mounted) return;
        FocusManager.instance.primaryFocus?.unfocus();
        FocusScope.of(context).unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          FocusManager.instance.primaryFocus?.unfocus();
          FocusScope.of(context).unfocus();
        });
    }

    Widget _sheetActionTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Material(
        color: _soft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _chip,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
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

        void _showError(String message) {

        ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

            backgroundColor: Colors.red,

            content: Text(message),

            ),

        );

        }

        Future<void> showSuccessDialog() async {
            if (!mounted) return;

            await showDialog(
                context: context,
                useRootNavigator: true,
                barrierDismissible: false,
                barrierColor: const Color(0x660F172A),
                builder: (dialogContext) {
                    return Dialog(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
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
                            const Text(
                              "Your maintenance report was sent successfully.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
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
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _ink,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
                },
            );
        }

        Future<void> showErrorDialog(String message) async {
            if (!mounted) return;

            await showDialog(
                context: context,
                useRootNavigator: true,
                barrierDismissible: false,
                barrierColor: const Color(0x660F172A),
                builder: (dialogContext) {
                    return Dialog(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
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
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: FilledButton(
                                onPressed: () {
                                    Navigator.of(dialogContext).pop();

                                    Future.delayed(
                                        const Duration(milliseconds: 200),
                                        () {
                                            if (!mounted) return;

                                            if (employeeIdError != null) {
                                                scrollToField(employeeKey);
                                            } else if (locationError != null) {
                                                scrollToField(locationKey);
                                            } else if (equipmentError != null) {
                                                scrollToField(equipmentKey);
                                            } else if (issueError != null) {
                                                scrollToField(issueKey);
                                            } else if (descriptionError != null) {
                                                scrollToField(descriptionKey);
                                            }
                                        },
                                    );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _ink,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
                },
            );
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

                selectedEquipment = null;
                selectedEquipmentId = null;

                selectedSuggestedIssueId = null;

                suggestedIssues.clear();

                equipment.clear();

                equipmentNotListed = false;

                selectedImage = null;

                priority = "Non-Urgent";

                employeeIdError = null;
                locationError = null;
                equipmentError = null;
                issueError = null;
                descriptionError = null;

            });

        }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EEF5)),
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
        color: Color(0xFFF1F5F9),
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
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _chip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                hasValue ? FontWeight.w700 : FontWeight.w500,
                            color: hasValue ? _ink : const Color(0xFF94A3B8),
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
                      borderRadius: BorderRadius.circular(8),
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
                  padding: const EdgeInsets.only(left: 52),
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
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _chip,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
                  color: Color(0xFF94A3B8),
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

  Widget _optionCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _chip : _soft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _blue.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: leading ??
                  Icon(
                    Icons.build_circle_outlined,
                    size: 22,
                    color: selected ? _blue : _ink,
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
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: selected ? _blue : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusDot() {
    Color color = const Color(0xFFCBD5E1);
    if (isCheckingReporter) {
      color = const Color(0xFFF59E0B);
    } else if (reporterVerified) {
      color = const Color(0xFF22C55E);
    } else if (reporterError != null) {
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
    if (reporterError != null) {
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

  Widget _buildPriorityCard({
    required PriorityOption option,
    required bool selected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          priority = option.value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _chip : _soft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _blue.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? _blue : _ink,
              size: 20,
            ),
            const SizedBox(height: 12),
            Text(
              option.label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.description,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}