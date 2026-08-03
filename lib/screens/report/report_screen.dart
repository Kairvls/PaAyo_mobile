import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'dart:async';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';


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

    Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF7F9FC),
        foregroundColor: const Color(0xff1A1D29),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Maintenance Report",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Report broken or faulty equipment.",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xff64748B),
              ),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        

        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                color: const Color(0xffE8EDF3),
                ),
                boxShadow: const [
                BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                ),
                ],
            ),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // ===========================
            // REPORTER INFORMATION
            // ===========================

            const Text(
                "Reporter Information",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff0F172A),
                ),
                ),

            const SizedBox(height: 15),

            TextField(

                controller: employeeIdController,

                onChanged: (_) {

                    _verifyTimer?.cancel();

                    setState(() {

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

                        () {

                        verifyReporter();

                        },

                    );

                    },

                

                decoration: InputDecoration(
                labelText: "Employee ID *",
                hintText: "Enter Employee ID",
                enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                ),
                ),

                focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: Color(0xff2563EB),
                    width: 1.5,
                ),
                ),
                filled: true,
                fillColor: const Color(0xffF8FAFC),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),

            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),

              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xffE2E8F0),
                ),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    "Reporter Status",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 8),

                  if (isCheckingReporter)

                    const Center(

                        child: CircularProgressIndicator(),

                    )

                    else if (reporterVerified)

                    Row(

                        children: [

                        const Icon(

                            Icons.verified,

                            color: Colors.green,

                        ),

                        const SizedBox(width: 8),

                        Text(

                            reporterName,

                            style: const TextStyle(

                            fontWeight: FontWeight.bold,

                            fontSize: 16,

                            ),

                        ),

                        ],

                    )

                    else if (reporterError != null)

                    Text(

                        reporterError!,

                        style: const TextStyle(

                        color: Colors.red,

                        ),

                    )

                    else

                    const Text(

                        "Waiting for Employee ID...",

                    ),

                ],
              ),
            ),

            const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Divider(
                    thickness: .8,
                    color: Color(0xffEEF2F7),
                ),
                ),

            

            // ===========================
            // LOCATION
            // ===========================

            _buildSectionTitle("Location"),

            const SizedBox(height: 15),

            TextField(

                controller: TextEditingController(
                    text: selectedLocation ?? "",
                ),

                readOnly: true,

                decoration: InputDecoration(

                    labelText: selectedLocation == null
                        ? null
                        : "Location",
                    hintText: "Location",

                    suffixIcon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    ),

                    filled: true,

                    fillColor: const Color(0xffF8FAFC),

                    enabledBorder: OutlineInputBorder(

                    borderRadius: BorderRadius.circular(16),

                    borderSide: const BorderSide(
                        color: Color(0xffE2E8F0),
                    ),

                    ),

                    focusedBorder: OutlineInputBorder(

                    borderRadius: BorderRadius.circular(16),

                    borderSide: const BorderSide(
                        color: Color(0xff2563EB),
                        width: 1.5,
                    ),

                    ),

                ),

                onTap: () {

                    showSelectionBottomSheet(

                    title: "Select Location",

                    items: rooms,

                    selectedItem: selectedRoomId,

                    icon: Icons.location_on_outlined,

                    label: (room) => room["location"],

                    onSelected: (room) {

                        setState(() {

                        selectedLocation = room["location"];

                        selectedRoomId = room["room_id"];

                        });

                        loadEquipment(room["room_id"]);

                    },

                    );

                },

                ),

            const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(
                        thickness: .8,
                        color: Color(0xffEEF2F7),
                    ),
                    ),

            

            // ===========================
            // EQUIPMENT
            // ===========================

            _buildSectionTitle("Equipment"),

            const SizedBox(height: 15),

            if (!equipmentNotListed)

                TextField(

                    controller: TextEditingController(
                        text: selectedEquipment ?? "",
                    ),

                    readOnly: true,

                    decoration: InputDecoration(

                        labelText: selectedEquipment == null
                            ? null
                            : "Equipment",
                        hintText: "Equipment",

                        suffixIcon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                        ),

                        filled: true,

                        fillColor: const Color(0xffF8FAFC),

                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Color(0xffE2E8F0),
                            ),
                        ),

                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Color(0xff2563EB),
                                width: 1.5,
                            ),
                        ),

                    ),

                    onTap: () {

                        showSelectionBottomSheet(

                            title: "Select Equipment",

                            items: equipment,

                            selectedItem: selectedEquipmentId,

                            icon: Icons.computer_rounded,

                            label: (item) =>
                                item["equipment_name"],

                            onSelected: (item) {

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

                )

            else

                TextField(

                    controller: equipmentController,

                    decoration: InputDecoration(

                        labelText: "Equipment Name",

                        hintText: "Enter equipment name",

                        filled: true,

                        fillColor: const Color(0xffF8FAFC),

                        enabledBorder: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(16),

                            borderSide: const BorderSide(
                                color: Color(0xffE2E8F0),
                            ),

                        ),

                        focusedBorder: OutlineInputBorder(

                            borderRadius: BorderRadius.circular(16),

                            borderSide: const BorderSide(
                                color: Color(0xff2563EB),
                                width: 1.5,
                            ),

                        ),

                    ),

                ),

            const SizedBox(height: 12),

            SwitchListTile(
                value: equipmentNotListed,
                onChanged: (value) async {

                    setState(() {

                        equipmentNotListed = value;

                        if (value) {

                            // switched to manual equipment

                            selectedEquipment = null;

                            selectedEquipmentId = null;

                        } else {

                            // switched back to dropdown

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
                activeColor: const Color(0xff2563EB),
                title: const Text(
                    "Equipment not listed",
                    style: TextStyle(
                    fontWeight: FontWeight.w600,
                    ),
                ),
                contentPadding: EdgeInsets.zero,
            ),

            const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(
                        thickness: .8,
                        color: Color(0xffEEF2F7),
                    ),
                    ),

            

            // ===========================
            // SUGGESTED ISSUE
            // ===========================

            _buildSectionTitle("Suggested Issue"),

            const SizedBox(height: 15),

            if (suggestedIssues.isEmpty)

                Container(

                    width: double.infinity,

                    padding: const EdgeInsets.all(18),

                    decoration: BoxDecoration(

                        color: const Color(0xffF8FAFC),

                        borderRadius: BorderRadius.circular(16),

                        border: Border.all(

                            color: const Color(0xffE2E8F0),

                        ),

                    ),

                    child: Column(

                        children: [

                            Icon(

                                Icons.info_outline_rounded,

                                color: Colors.grey.shade500,

                                size: 34,

                            ),

                            SizedBox(height: 10),

                            Text(

                                equipmentNotListed
                                    ? "Enable Equipment Not Listed to load global suggested issues."
                                    : "Select an equipment first to see suggested issues.",

                                textAlign: TextAlign.center,

                                style: TextStyle(

                                    color: Color(0xff64748B),

                                    fontSize: 14,

                                ),

                            ),

                        ],

                    ),

                )
                else

            Wrap(

                spacing: 10,

                runSpacing: 10,

                children: [

                    ...visibleSuggestedIssues.map((issue) {

                    return ChoiceChip(

                        label: Text(
                        issue["issue_template_name"],
                        ),

                        selected:
                            selectedSuggestedIssueId ==
                            issue["issue_template_id"],

                        onSelected: (_) {

                        setState(() {

                            selectedSuggestedIssueId =
                                issue["issue_template_id"];

                        });

                        },

                    );

                    }),

                    if (
                    equipmentNotListed &&
                    !showAllGlobalIssues &&
                    suggestedIssues.length > 5
                    )

                    ActionChip(

                        avatar: const Icon(
                        Icons.search,
                        size: 18,
                        ),

                        label: Text(
                        "+${suggestedIssues.length - 5} More Issues",
                        ),

                        onPressed: () {

                            showSelectionBottomSheet(

                                title: "Select Suggested Issue",

                                items: suggestedIssues,

                                selectedItem: selectedSuggestedIssueId,

                                icon: Icons.build_circle_outlined,

                                label: (item) =>
                                    item["issue_template_name"],

                                onSelected: (item) {

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

            const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(
                        thickness: .8,
                        color: Color(0xffEEF2F7),
                    ),
                    ),

            

            // ===========================
            // DESCRIPTION
            // ===========================

            _buildSectionTitle("Description"),

            const SizedBox(height: 15),

            TextField(
              controller: descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Describe the problem...",
                enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: Color(0xffE2E8F0),
                ),
                ),

                focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                    color: Color(0xff2563EB),
                    width: 1.5,
                ),
                ),
                filled: true,
                fillColor: const Color(0xffF8FAFC),
              ),
            ),

            const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(
                        thickness: .8,
                        color: Color(0xffEEF2F7),
                    ),
                    ),

            

            // ===========================
            // PRIORITY
            // ===========================

            _buildSectionTitle("Priority"),

            const SizedBox(height: 15),

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

            const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(
                        thickness: .8,
                        color: Color(0xffEEF2F7),
                    ),
                    ),

            

            // ===========================
            // PHOTO
            // ===========================

            _buildSectionTitle("Upload Photo (Optional)"),

            const SizedBox(height: 15),

            GestureDetector(
                onTap: pickImage,
                child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                    color: const Color(0xffF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xffD6E2F0),
                    ),
                    ),
                    child: selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Icon(
                                Icons.cloud_upload_outlined,
                                size: 42,
                                color: Color(0xff2563EB),
                            ),
                            SizedBox(height: 12),
                            Text(
                                "Tap to upload a photo",
                                style: TextStyle(
                                fontWeight: FontWeight.w600,
                                ),
                            ),
                            SizedBox(height: 6),
                            Text(
                                "PNG • JPG • JPEG",
                                style: TextStyle(
                                color: Color(0xff94A3B8),
                                ),
                            ),
                            ],
                        )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                            selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            ),
                        ),
                ),
                ),

            const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(
                        thickness: .8,
                        color: Color(0xffEEF2F7),
                    ),
                    ),

            const SizedBox(height: 35),

            SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                    style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff2563EB),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                    ),
                    ),
                    onPressed: confirmSubmitReport,
                    child: const Text(
                    "Submit Report",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                    ),
                    ),
                ),
                ),

            const SizedBox(height: 40),

          ],
        ),

        ),

        ),
      
    );
  }

  @override
    void dispose() {

    _verifyTimer?.cancel();

    employeeIdController.dispose();

    descriptionController.dispose();

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

            isCheckingReporter = false;

            });

        } else {

            setState(() {

            reporterVerified = false;

            reporterName = "";

            reporterError =

                "Employee ID not found.";

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

            submitReport();

        }

        }

    Future<void> submitReport() async {

        // =====================================
        // Employee ID
        // =====================================

        if (!reporterVerified) {

            _showError(
            "Please enter a valid Employee ID."
            );

            return;

        }

        // =====================================
        // Location
        // =====================================

        if (selectedRoomId == null) {

            _showError(
            "Please select a location."
            );

            return;

        }

        // =====================================
        // Equipment
        // =====================================

        if (equipmentNotListed) {

            if (equipmentController.text.trim().isEmpty) {

            _showError(
                "Please enter the equipment name."
            );

            return;

            }

        } else {

            if (selectedEquipmentId == null) {

            _showError(
                "Please select equipment."
            );

            return;

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

            _showError(

            "Select a suggested issue or provide a description.",

            );

            return;

        }

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

            _showSuccess(
            "Report submitted successfully."
            );

        } catch (e) {

            _showError(
            "Failed to submit report."
            );

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

                            fontWeight: FontWeight.bold,

                            ),

                        ),

                        const SizedBox(height: 18),

                        TextField(

                            autofocus: true,

                            decoration: InputDecoration(

                            hintText: "Search...",

                            prefixIcon: const Icon(
                                Icons.search_rounded,
                            ),

                            filled: true,

                            fillColor: const Color(0xffF8FAFC),

                            border: OutlineInputBorder(

                                borderRadius:
                                    BorderRadius.circular(16),

                            ),

                            ),

                            onChanged: (value) {

                            setBottomState(() {

                                search = value;

                            });

                            },

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

                                return Card(

                                elevation: 0,

                                margin:
                                    const EdgeInsets.only(bottom: 10),

                                shape: RoundedRectangleBorder(

                                    borderRadius:
                                        BorderRadius.circular(16),

                                ),

                                color: selected
                                    ? const Color(0xffEFF6FF)
                                    : Colors.white,

                                child: ListTile(

                                    leading: CircleAvatar(

                                    backgroundColor:
                                        const Color(0xffEFF6FF),

                                    child: Icon(

                                        icon,

                                        color:
                                            const Color(0xff2563EB),

                                    ),

                                    ),

                                    title: Text(

                                    label(item),

                                    maxLines: 1,

                                    overflow:
                                        TextOverflow.ellipsis,

                                    ),

                                    trailing: selected

                                        ? const Icon(

                                            Icons.check_circle,

                                            color:
                                                Color(0xff2563EB),

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

        void _showSuccess(String message) {

        ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

            backgroundColor: Colors.green,

            content: Text(message),

            ),

        );

        }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: Color(0xff1E293B),
      ),
    );
  }

  

    Widget _buildPriorityCard({

        required PriorityOption option,
        required bool selected,

    }) {
        return InkWell(

            borderRadius: BorderRadius.circular(18),

            onTap: () {

            setState(() {

                priority = option.value;

            });

            },

            child: AnimatedContainer(

            duration: const Duration(milliseconds: 220),

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(

                color: selected
                    ? const Color(0xffEFF6FF)
                    : Colors.white,

                borderRadius: BorderRadius.circular(18),

                border: Border.all(

                color: selected
                    ? const Color(0xff2563EB)
                    : const Color(0xffE2E8F0),

                width: selected ? 2 : 1,

                ),

            ),

            child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                Icon(

                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,

                    color: const Color(0xff2563EB),

                ),

                const SizedBox(height: 12),

                Text(

                    option.label,

                    style: const TextStyle(

                    fontWeight: FontWeight.bold,

                    fontSize: 16,

                    ),

                ),

                const SizedBox(height: 6),

                Text(

                    option.description,

                    style: const TextStyle(

                    color: Color(0xff64748B),

                    fontSize: 12,

                    ),

                ),

                ],

            ),

            ),

        );
        }
}