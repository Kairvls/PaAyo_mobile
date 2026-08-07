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
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF3F4F6),
        foregroundColor: const Color(0xFF111827),
        titleSpacing: 8,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Maintenance Report",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.4,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Report broken or faulty equipment.",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                            iconColor: const Color(0xFF111827),
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
                            iconColor: const Color(0xFF111827),
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
                                  iconColor: const Color(0xFFEF4444),
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
                                  iconColor: const Color(0xFFEF4444),
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
                      activeTrackColor: const Color(0xFF111827),
                      title: const Text(
                        "Equipment not listed",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF111827),
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
                                    color: Color(0xFF111827),
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
                          color: Color(0xFF111827),
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
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: selectedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 34,
                                  color: Color(0xFF111827),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Add a photo",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "PNG • JPG • JPEG",
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.file(
                                selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ===========================
          // BOTTOM CTA
          // ===========================
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () async {
                    if (validateForm()) {
                      await confirmSubmitReport();
                    }
                  },
                  child: const Text(
                    "Submit Report",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
            builder: (context) => SafeArea(
            child: Wrap(
                children: [

                ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text("Take Photo"),
                    onTap: () =>
                        Navigator.pop(context, ImageSource.camera),
                ),

                ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text("Choose from Gallery"),
                    onTap: () =>
                        Navigator.pop(context, ImageSource.gallery),
                ),

                ],
            ),
            ),
        );

        if (source == null) return;

        final image = await picker.pickImage(
            source: source,
            imageQuality: 80,
        );

        if (image == null) return;

        setState(() {
            selectedImage = File(image.path);
        });
        }

    Future<void> confirmSubmitReport() async {

        final confirmed = await showDialog<bool>(

            context: context,

            builder: (context) {

            return AlertDialog(

                title: const Text(
                "Submit Maintenance Report?"
                ),

                content: const Text(
                "Are you sure you want to submit this maintenance report?"
                ),

                actions: [

                TextButton(

                    onPressed: () {

                    Navigator.pop(context, false);

                    },

                    child: const Text("Cancel"),

                ),

                FilledButton(

                    onPressed: () {

                    Navigator.pop(context, true);

                    },

                    child: const Text("Submit"),

                ),

                ],

            );

            },

        );

        if (confirmed == true) {
            // Wait until the confirm dialog route is fully gone,
            // otherwise the success/error alert may not appear.
            await Future<void>.delayed(Duration.zero);
            if (!mounted) return;
            await submitReport();
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

    Future<void> submitReport() async {
        try {
            await api.submitReport(
            employeeId: employeeIdController.text.trim(),
            roomId: selectedRoomId!,
            equipmentId:
                equipmentNotListed
                    ? null
                    : selectedEquipmentId,
            manualEquipmentName:
                equipmentNotListed
                    ? equipmentController.text.trim()
                    : null,
            issueTemplateId:
                selectedSuggestedIssueId,
            description:
                descriptionController.text.trim(),
            priority:
                priority,
            photo:
                selectedImage,
            );

            if (!mounted) return;
            await showSuccessDialog();
            if (!mounted) return;
            resetForm();

        } catch (e) {
            String message = "Failed to submit report.";

            if (e is DioException) {
                final data = e.response?.data;

                if (data is Map) {
                  message = data["message"]?.toString() ?? message;
                } else if (data is String) {
                  final trimmed = data.trim();
                  // Laravel sometimes returns an HTML error page instead of JSON.
                  if (trimmed.startsWith("<!DOCTYPE") ||
                      trimmed.startsWith("<html") ||
                      trimmed.contains("<title>Laravel</title>")) {
                    final status = e.response?.statusCode;
                    message = status == null
                        ? "Server error while submitting the report. Please try again."
                        : "Server error ($status) while submitting the report. Please try again.";
                  } else {
                    message = trimmed.isEmpty ? message : trimmed;
                  }
                } else {
                  message = e.message ?? message;
                }

                // ============================
                // Employee ID became invalid
                // ============================
                if (message.toLowerCase().contains("employee id")) {
                    setState(() {
                        reporterVerified = false;
                        reporterName = "";
                        reporterError = "Employee ID not found.";
                        employeeIdError = "Please enter a valid Employee ID.";
                    });
                }
            }

            if (!mounted) return;
            await showErrorDialog(message);
        }
        }

    void showSelectionBottomSheet({

        required String title,

        required List<dynamic> items,

        required String Function(dynamic) label,

        required Function(dynamic) onSelected,

        required IconData icon,

        required dynamic selectedItem,

        }) {

        String search = "";

        showModalBottomSheet(

            context: context,

            isScrollControlled: true,

            backgroundColor: Colors.transparent,

            builder: (context) {

            return StatefulBuilder(

                builder: (context, setBottomState) {

                final filtered = items.where((item) {

                    return label(item)
                        .toLowerCase()
                        .contains(search.toLowerCase());

                }).toList();

                return Container(

                    height: MediaQuery.of(context).size.height * .78,

                    decoration: const BoxDecoration(

                    color: Colors.white,

                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                    ),

                    ),

                    child: Padding(

                    padding: const EdgeInsets.all(20),

                    child: Column(

                        children: [

                        Container(

                            width: 45,

                            height: 5,

                            decoration: BoxDecoration(

                            color: Colors.grey.shade300,

                            borderRadius:
                                BorderRadius.circular(100),

                            ),

                        ),

                        const SizedBox(height: 18),

                        Text(

                            title,

                            style: const TextStyle(

                            fontSize: 22,

                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Color(0xFF111827),

                            ),

                        ),

                        const SizedBox(height: 18),

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: TextField(

                            autofocus: true,

                            decoration: _minimalInputDecoration(

                            hintText: "Search...",

                            prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                            ),

                            ),

                            onChanged: (value) {

                            setBottomState(() {

                                search = value;

                            });

                            },

                        ),
                        ),

                        const SizedBox(height: 18),

                        Expanded(

                        child: filtered.isEmpty

                            ? Align(

                                alignment: Alignment.topCenter,

                                child: Padding(

                                    padding: const EdgeInsets.only(top: 70),

                                    child: Column(

                                        mainAxisSize: MainAxisSize.min,

                                        children: const [

                                            Icon(

                                                Icons.search_off_rounded,

                                                size: 56,

                                                color: Color(0xffCBD5E1),

                                            ),

                                            SizedBox(height: 14),

                                            Text(

                                                "No results found",

                                                style: TextStyle(

                                                    fontSize: 18,

                                                    fontWeight: FontWeight.w600,

                                                    color: Color(0xff475569),

                                                ),

                                            ),

                                            SizedBox(height: 6),

                                            Text(

                                                "Try another keyword.",

                                                style: TextStyle(

                                                    color: Color(0xff94A3B8),

                                                ),

                                            ),

                                        ],

                                    ),

                                ),

                            )

                            :ListView.builder(

                            itemCount: filtered.length,

                            itemBuilder: (_, index) {

                                final item = filtered[index];

                                final selected =
                                    selectedItem ==
                                    item.values.first;

                                return Container(

                                margin:
                                    const EdgeInsets.only(bottom: 10),

                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(18),
                                ),

                                child: ListTile(

                                    leading: CircleAvatar(

                                    backgroundColor: selected
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.white,

                                    child: Icon(

                                        icon,

                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF111827),

                                    ),

                                    ),

                                    title: Text(

                                    label(item),

                                    maxLines: 1,

                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),

                                    ),

                                    trailing: selected

                                        ? const Icon(

                                            Icons.check_circle,

                                            color: Colors.white,

                                        )

                                        : null,

                                    onTap: () {

                                    onSelected(item);

                                    Navigator.pop(context);

                                    },

                                ),

                                );

                            },

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
                builder: (dialogContext) {
                    return AlertDialog(
                        icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 60,
                        ),
                        title: const Text(
                            "Report Submitted",
                        ),
                        content: const Text(
                            "Your maintenance report has been submitted successfully.",
                        ),
                        actions: [
                            FilledButton(
                                onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                },
                                child: const Text("OK"),
                            )
                        ],
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
                builder: (dialogContext) {
                    return AlertDialog(
                        icon: const Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 60,
                        ),
                        title: const Text(
                            "Submission Failed",
                        ),
                        content: Text(message),
                        actions: [
                            FilledButton(
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
                                child: const Text("OK"),
                            )
                        ],
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
        color: Color(0xFF6B7280),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
        color: Color(0xFFF3F4F6),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    hasValue ? value : placeholder,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD1D5DB),
                ),
              ],
            ),
            if (errorText != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 36),
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
      padding: const EdgeInsets.fromLTRB(18, 4, 14, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              decoration: InputDecoration(
                hintText: hint,
                errorText: errorText,
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.08 : 0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: leading ??
                  Icon(
                    Icons.build_circle_outlined,
                    size: 22,
                    color: selected ? Colors.white : const Color(0xFF111827),
                  ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: selected ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.65)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: selected
                  ? Colors.white
                  : const Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusDot() {
    Color color = const Color(0xFFD1D5DB);
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
          color: Color(0xFF6B7280),
        ),
      );
    }
    if (reporterVerified && reporterName.isNotEmpty) {
      return Text(
        reporterName,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
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
        color: Color(0xFF9CA3AF),
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
        color: Color(0xFF9CA3AF),
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFEF4444),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: const Color(0xFF9CA3AF),
      suffixIconColor: const Color(0xFF9CA3AF),
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
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        setState(() {
          priority = option.value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.08 : 0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? Colors.white : const Color(0xFF111827),
              size: 20,
            ),
            const SizedBox(height: 12),
            Text(
              option.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: selected ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.description,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.65)
                    : const Color(0xFF9CA3AF),
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