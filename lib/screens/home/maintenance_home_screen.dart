import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../services/role_session.dart';
import '../../utils/equipment_icon.dart';
import '../../widgets/product_list_row.dart';
import '../../widgets/chart_tooltip.dart';
import '../equipment/equipment_screen.dart';
import '../qr/qr_scanner_screen.dart';
import '../qr/scan_to_manage.dart';
import '../schedule/schedule_alerts_screen.dart';
import '../schedule/schedule_screen.dart';

/// Shadows are intentionally disabled on the home screen so cards sit flat on
/// the background instead of appearing to float.
const List<BoxShadow> kSoftShadow = [];
const List<BoxShadow> kSoftShadowSm = [];

/// The home background is white; cards/buttons use this light gray so they read
/// as subtly raised surfaces against it.
const Color kCardGray = Color(0xFFF3F4F6);

class MaintenanceHomeScreen extends StatefulWidget {
  const MaintenanceHomeScreen({super.key});

  @override
  State<MaintenanceHomeScreen> createState() => _MaintenanceHomeScreenState();
}

class _MaintenanceTool {
  final String title;
  final String subtitle;
  final String meta;
  final String route;
  final String imageAsset;

  const _MaintenanceTool({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.route,
    required this.imageAsset,
  });
}

class _MaintenanceHomeScreenState extends State<MaintenanceHomeScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF0025CC);
  static const _blueLight = Color(0xFF93C5FD);
  static const _navy = Color(0xFF0B2F64);
  static const _bg = Colors.white;
  static const _accent = Color(0xFF0B2F64);

  static const _tools = [
    _MaintenanceTool(
      title: "Reports",
      subtitle: "Incoming tickets",
      meta: "Status updates",
      route: "/reports",
      imageAsset: "assets/images/report.png",
    ),
    _MaintenanceTool(
      title: "Semester Check",
      subtitle: "Campus inspection",
      meta: "On-site",
      route: "/semester-inspections",
      imageAsset: "assets/images/qrscanner.png",
    ),
    _MaintenanceTool(
      title: "Record Fix",
      subtitle: "Log a repair",
      meta: "On-site",
      route: "/maintenance",
      imageAsset: "assets/images/record_fix.png",
    ),
    _MaintenanceTool(
      title: "History",
      subtitle: "Timeline log",
      meta: "Past fixes",
      route: "/history",
      imageAsset: "assets/images/history.png",
    ),
  ];

  static const _reminderDayKey = "schedule_reminder_day";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final MaintenanceService _service = MaintenanceService();
  final TextEditingController _homeSearch = TextEditingController();
  final FocusNode _homeSearchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _name = "Maintenance Team";
  late Future<MaintenanceRecent> _recentFuture;
  MaintenanceRecent? _cachedRecent;
  double _savedScrollOffset = 0;
  int _tabIndex = 0;
  /// 0 = Needs attention, 1 = Recent fixes
  int _activitySegment = 0;
  String _overviewRange = "Month";
  String _recentRange = "Month";

  @override
  void initState() {
    super.initState();
    _loadName();
    _recentFuture = _service.getRecent().then((recent) {
      _cachedRecent = recent;
      // Soft daily nudge — never blocks Home permanently.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowDailyReminder(recent);
      });
      return recent;
    });
  }

  @override
  void dispose() {
    _homeSearch.dispose();
    _homeSearchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _unfocusSearch() {
    _homeSearchFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _rememberScroll() {
    if (_scrollController.hasClients) {
      _savedScrollOffset = _scrollController.offset;
    }
  }

  void _restoreScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(_savedScrollOffset.clamp(0.0, max));
    });
  }

  Future<T?> _pushAndKeepSearchClosed<T>(Future<T?> navigation) async {
    _unfocusSearch();
    _rememberScroll();
    final result = await navigation;
    if (!mounted) return result;
    // Drop focus again after pop so the keyboard does not reopen on Home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unfocusSearch();
    });
    _restoreScroll();
    return result;
  }

  Future<void> _openEquipmentSearch([String? query]) async {
    final q = (query ?? _homeSearch.text).trim();
    if (q.isEmpty) return;
    await _pushAndKeepSearchClosed(
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EquipmentScreen(initialSearch: q),
        ),
      ),
    );
    if (mounted) await _refreshRecent(keepScroll: true);
  }

  Future<void> _loadName() async {
    final stored = await _storage.read(key: "name");
    if (stored != null && stored.trim().isNotEmpty && mounted) {
      setState(() => _name = stored.trim());
    }
  }

  Future<void> _refreshRecent({bool keepScroll = false}) async {
    if (keepScroll) _rememberScroll();
    setState(() {
      _recentFuture = _service.getRecent().then((recent) {
        _cachedRecent = recent;
        return recent;
      });
    });
    try {
      await _recentFuture;
    } catch (_) {
      // Keep previous UI path; FutureBuilder handles the error state.
    }
    if (keepScroll && mounted) _restoreScroll();
  }

  String get _todayStamp {
    final n = DateTime.now();
    return "${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}";
  }

  Future<void> _markReminderSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderDayKey, _todayStamp);
  }

  Future<void> _maybeShowDailyReminder(MaintenanceRecent recent) async {
    if (!mounted) return;

    final overdue = recent.overdueSchedules;
    final dueSoon = recent.dueSoonSchedulesCount;
    if (overdue <= 0 && dueSoon <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_reminderDayKey) == _todayStamp) return;
    if (!mounted) return;

    final viewAlerts = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          overdue > 0
              ? Icons.warning_amber_rounded
              : Icons.schedule_rounded,
          color: overdue > 0
              ? const Color(0xFFEF4444)
              : const Color(0xFFF59E0B),
          size: 40,
        ),
        title: Text(
          overdue > 0 ? "Overdue maintenance" : "Maintenance due soon",
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          [
            if (overdue > 0)
              "$overdue equipment schedule${overdue == 1 ? '' : 's'} overdue.",
            if (dueSoon > 0)
              "$dueSoon due within ${recent.dueSoonDays} days.",
            "",
            "Scan each unit’s QR on-site to update its schedule.",
          ].join("\n"),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Later"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("View alerts"),
          ),
        ],
      ),
    );

    await _markReminderSeen();
    if (!mounted) return;

    if (viewAlerts == true) {
      await _pushAndKeepSearchClosed(
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScheduleAlertsScreen()),
        ),
      );
      if (mounted) await _refreshRecent(keepScroll: true);
    }
  }

  /// Preview full (non-truncated) card info first; scan stays optional CTA.
  Future<void> _showCardPreview({
    required String title,
    required List<({String label, String value})> details,
    required Color accent,
    required IconData icon,
    String? badge,
    ScanDestination destination = ScanDestination.profile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kCardGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < details.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: Color(0xFFE8EEF5)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 96,
                                child: Text(
                                  details[i].label,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  details[i].value,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "To update or manage this unit, scan its QR code on-site.",
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pushAndKeepSearchClosed(
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                QRScannerScreen(destination: destination),
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text(
                      "Open scanner",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 18) return "Good afternoon";
    return "Good evening";
  }

  String get _firstName {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return "there";
    // Prefer a friendly first token (skip generic team labels).
    if (_name.toLowerCase().contains("maintenance")) return "Team";
    return parts.first;
  }

  String _headerTip(MaintenanceRecent? recent) {
    final overdue = recent?.overdueSchedules ?? 0;
    final dueSoon = recent?.dueSoonSchedulesCount ?? 0;
    if (overdue > 0) {
      return "You have $overdue overdue schedule${overdue == 1 ? '' : 's'}. Prioritize those units when you're on campus.";
    }
    if (dueSoon > 0) {
      return "$dueSoon unit${dueSoon == 1 ? '' : 's'} due soon. A quick scan keeps maintenance ahead of schedule.";
    }
    return "Campus equipment looks clear today. Scan a QR when you're on-site to manage a unit.";
  }

  Widget _buildHeader() {
    final dateLabel =
        DateFormat("EEEE, MMMM d").format(DateTime.now()).toUpperCase();
    const accent = Color(0xFF0025CC);
    const accentSoft = Color(0xFFE8EEFF);
    const band = Color(0xFF0025CC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top: icons only (right), then date + greeting below.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: FutureBuilder<MaintenanceRecent>(
                  future: _recentFuture,
                  builder: (context, snap) {
                    final recent = snap.data ?? _cachedRecent;
                    final alertCount = (recent?.dueSoonSchedulesCount ?? 0) +
                        (recent?.overdueSchedules ?? 0);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CircleIcon(
                          icon: Icons.notifications_none_rounded,
                          color: accent,
                          background: accentSoft,
                          badge: alertCount > 0,
                          onTap: () async {
                            await _pushAndKeepSearchClosed(
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ScheduleAlertsScreen(),
                                ),
                              ),
                            );
                            if (mounted) {
                              await _refreshRecent(keepScroll: true);
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        _CircleIcon(
                          icon: Icons.settings_outlined,
                          color: accent,
                          background: accentSoft,
                          onTap: () => _confirmLogout(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: Color(0xFF9AA3B2),
                ),
              ),
              //const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1C1E),
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                  children: [
                    TextSpan(text: "$_greeting, "),
                    TextSpan(
                      text: "$_firstName!",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Mascot + speech bubble sitting on a blue band (mascot overlaps bubble).
        FutureBuilder<MaintenanceRecent>(
          future: _recentFuture,
          builder: (context, snap) {
            final tip = _headerTip(snap.data ?? _cachedRecent);
            return SizedBox(
              height: 128,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 72,
                    child: Container(color: band),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 0,
                    child: Image.asset(
                      "assets/images/paayo_home.png",
                      height: 118,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Image.asset(
                        "assets/images/paayo_logo_original.png",
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Bubble last so it sits above the mascot layer.
                  Positioned(
                    left: 108,
                    right: 16,
                    bottom: 18,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "PaAyo",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tip,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF5B6472),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Speech-bubble tail pointing toward PaAyo (bottom-left).
                        Positioned(
                          left: -10,
                          bottom: 14,
                          child: CustomPaint(
                            size: const Size(12, 16),
                            painter: _SpeechTailPainter(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: _buildSearchBar(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pushAndKeepSearchClosed(
          Navigator.pushNamed(context, "/scanner"),
        ),
        backgroundColor: _blue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: _tabIndex,
        onHome: () => _selectTab(0),
        onEquipment: () => _selectTab(1),
        onSchedule: () => _selectTab(2),
        onLogout: () {
          _unfocusSearch();
          _confirmLogout(context);
        },
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildHomeTab(),
          const EquipmentScreen(embedded: true),
          const ScheduleScreen(embedded: true),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    _unfocusSearch();
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
    // Refresh Home data whenever the user returns to it.
    if (index == 0) _refreshRecent(keepScroll: true);
  }

  Widget _buildHomeTab() {
    return SafeArea(
      bottom: false,
      child: GestureDetector(
        onTap: _unfocusSearch,
        behavior: HitTestBehavior.deferToChild,
        child: RefreshIndicator(
          onRefresh: _refreshRecent,
          child: CustomScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildDashboardBody()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: const Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildQuickActions()),
              const SliverToBoxAdapter(child: SizedBox(height: 72)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardBody() {
    return FutureBuilder<MaintenanceRecent>(
      future: _recentFuture,
      builder: (context, snap) {
        final recent = snap.data ?? _cachedRecent;
        if (recent == null &&
            snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }
        if (recent == null) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  "Couldn't load dashboard",
                  style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _refreshRecent, child: const Text("Retry")),
              ],
            ),
          );
        }

        final dateFmt = DateFormat("MMM d, yyyy");
        final todayLabel = dateFmt.format(DateTime.now());
        final history = _filterHistoryByRange(recent.recentHistory, _recentRange);
        final chart = _overviewSeries(recent);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 148,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                children: [
                  _SummaryMetricCard(
                    title: "Total Equipment",
                    value: "${recent.equipmentCount}",
                    dateLabel: todayLabel,
                    sparkline: _sparkFromCount(recent.equipmentCount, up: true),
                    changeLabel: "+${recent.equipmentCount}",
                    changePositive: true,
                    footnote: "${recent.underMaintenance} in maintenance",
                    onTap: () => _pushAndKeepSearchClosed(
                      Navigator.pushNamed(context, "/equipment"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SummaryMetricCard(
                    title: "Due Soon",
                    value: "${recent.dueSoonSchedulesCount}",
                    dateLabel: todayLabel,
                    sparkline: _sparkFromCount(
                      recent.dueSoonSchedulesCount,
                      up: recent.dueSoonSchedulesCount > 0,
                    ),
                    changeLabel: recent.dueSoonSchedulesCount > 0
                        ? "+${recent.dueSoonSchedulesCount}"
                        : "0",
                    changePositive: recent.dueSoonSchedulesCount == 0,
                    footnote: "Within ${recent.dueSoonDays} days",
                    onTap: () => _pushAndKeepSearchClosed(
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduleAlertsScreen(
                            filter: ScheduleAlertFilter.dueSoon,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SummaryMetricCard(
                    title: "Overdue",
                    value: "${recent.overdueSchedules}",
                    dateLabel: todayLabel,
                    sparkline: _sparkFromCount(
                      recent.overdueSchedules,
                      up: false,
                    ),
                    changeLabel: recent.overdueSchedules > 0
                        ? "+${recent.overdueSchedules}"
                        : "0",
                    changePositive: recent.overdueSchedules == 0,
                    footnote: "Past due schedules",
                    onTap: () => _pushAndKeepSearchClosed(
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduleAlertsScreen(
                            filter: ScheduleAlertFilter.overdue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SummaryMetricCard(
                    title: "Under Maintenance",
                    value: "${recent.underMaintenance}",
                    dateLabel: todayLabel,
                    sparkline: _sparkFromCount(recent.underMaintenance, up: true),
                    changeLabel: "${recent.attentionEquipment.length} units",
                    changePositive: true,
                    footnote: "Needs attention",
                    onTap: () => _pushAndKeepSearchClosed(
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EquipmentScreen(
                            attentionOnly: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Maintenance Overview",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  _MonthDropdown(
                    value: _overviewRange,
                    onTap: () => _pickRange(isOverview: true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 180,
                child: _HomeAreaLineChart(
                  labels: chart.labels,
                  seriesA: chart.dueSoon, // blue
                  seriesB: chart.overdue, // yellow
                  colorA: _blue,
                  colorB: const Color(0xFFFFF200),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Recent Activity",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  _MonthDropdown(
                    value: _recentRange,
                    onTap: () => _pickRange(isOverview: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  "No recent maintenance activity yet.",
                  style: TextStyle(color: _muted),
                ),
              )
            else
              for (final r in history.take(8))
                _RecentOrderRow(
                  title: r.equipmentName ?? "Equipment",
                  subtitle: ProductListRow.joinMeta([
                    r.status,
                    if (r.room != null && r.room!.trim().isNotEmpty) r.room,
                  ]),
                  value: DateFormat("MMM d").format(r.date.toLocal()),
                  status: r.status,
                  onTap: () => promptScanToManage(
                    context,
                    equipmentName: r.equipmentName,
                    destination: ScanDestination.history,
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _pickRange({required bool isOverview}) async {
    final current = isOverview ? _overviewRange : _recentRange;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in ["Month", "Week", "Today"])
                ListTile(
                  title: Text(option),
                  trailing: current == option
                      ? const Icon(Icons.check_rounded, color: _blue)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (isOverview) {
        _overviewRange = chosen;
      } else {
        _recentRange = chosen;
      }
    });
  }

  List<MaintenanceRecord> _filterHistoryByRange(
    List<MaintenanceRecord> all,
    String range,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime start;
    switch (range) {
      case "Today":
        start = today;
      case "Week":
        start = today.subtract(const Duration(days: 6));
      default:
        start = DateTime(today.year, today.month - 1, today.day);
    }
    return all.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return !d.isBefore(start);
    }).toList();
  }

  ({List<String> labels, List<double> overdue, List<double> dueSoon})
      _overviewSeries(MaintenanceRecent recent) {
    final labels = <String>[];
    final overdue = <double>[];
    final dueSoon = <double>[];
    final now = DateTime.now();

    if (_overviewRange == "Today" || _overviewRange == "Week") {
      final days = _overviewRange == "Today" ? 1 : 7;
      for (var i = days - 1; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i));
        labels.add(DateFormat("E").format(day).substring(0, 1));
        var o = 0;
        var d = 0;
        for (final s in [
          ...recent.dueSoonSchedules,
          ...recent.upcomingSchedules,
        ]) {
          if (s.nextDate == null) continue;
          final nd = DateTime(
            s.nextDate!.year,
            s.nextDate!.month,
            s.nextDate!.day,
          );
          if (nd != day) continue;
          if (s.isOverdue) {
            o++;
          } else if (s.isDueSoon) {
            d++;
          }
        }
        // Also count history fixes as activity for dueSoon series secondary.
        for (final r in recent.recentHistory) {
          final rd = DateTime(r.date.year, r.date.month, r.date.day);
          if (rd == day) d++;
        }
        overdue.add(o.toDouble());
        dueSoon.add(d.toDouble());
      }
    } else {
      for (var m = 6; m >= 0; m--) {
        final month = DateTime(now.year, now.month - m, 1);
        labels.add(DateFormat("MMM").format(month));
        final next = DateTime(month.year, month.month + 1, 1);
        var o = 0;
        var d = 0;
        for (final s in [
          ...recent.dueSoonSchedules,
          ...recent.upcomingSchedules,
        ]) {
          if (s.nextDate == null) continue;
          final nd = s.nextDate!;
          if (nd.isBefore(month) || !nd.isBefore(next)) continue;
          if (s.isOverdue) {
            o++;
          } else {
            d++;
          }
        }
        for (final r in recent.recentHistory) {
          final rd = r.date;
          if (!rd.isBefore(month) && rd.isBefore(next)) d++;
        }
        overdue.add(o.toDouble());
        dueSoon.add(d.toDouble());
      }
    }
    return (labels: labels, overdue: overdue, dueSoon: dueSoon);
  }

  List<double> _sparkFromCount(int n, {required bool up}) {
    if (up) return [0.2, 0.35, 0.55, 0.45, 0.85];
    return [0.9, 0.7, 0.35, 0.5, 0.25];
  }

  Widget _buildQuickActions() {
    const gap = 14.0;
    const aspect = 1.12;
    const minCardWidth = 128.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final neededForRow =
              minCardWidth * _tools.length + gap * (_tools.length - 1);
          final useCarousel = available < neededForRow;
          final cardWidth = useCarousel
              ? (available * 0.44).clamp(minCardWidth, 156.0)
              : (available - gap * (_tools.length - 1)) / _tools.length;
          final cardHeight = cardWidth / aspect;

          Widget buildCard(_MaintenanceTool tool) {
            return SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: _ToolCard(
                tool: tool,
                onTap: () => _onToolTap(tool),
              ),
            );
          }

          if (!useCarousel) {
            return SizedBox(
              height: cardHeight,
              child: Row(
                children: [
                  for (int i = 0; i < _tools.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(
                      child: SizedBox(
                        height: cardHeight,
                        child: _ToolCard(
                          tool: _tools[i],
                          onTap: () => _onToolTap(_tools[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: _tools.length,
              separatorBuilder: (_, __) => const SizedBox(width: gap),
              itemBuilder: (context, index) => buildCard(_tools[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onToolTap(_MaintenanceTool tool) async {
    // Quick Actions always open the full page (with back arrow). Bottom-nav
    // tabs stay as the embedded switcher.
    await _pushAndKeepSearchClosed(Navigator.pushNamed(context, tool.route));
    if (mounted) await _refreshRecent(keepScroll: true);
  }

  Widget _buildStatsRow(MaintenanceRecent recent) {
    return Row(
      children: [
        _StatChip(
          label: "Equipment",
          value: "${recent.equipmentCount}",
          onTap: () => _pushAndKeepSearchClosed(
            Navigator.pushNamed(context, "/equipment"),
          ),
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: "Due soon",
          value: "${recent.dueSoonSchedulesCount}",
          onTap: () => _pushAndKeepSearchClosed(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ScheduleAlertsScreen(
                  filter: ScheduleAlertFilter.dueSoon,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StatChip(
          label: "Overdue",
          value: "${recent.overdueSchedules}",
          onTap: () => _pushAndKeepSearchClosed(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ScheduleAlertsScreen(
                  filter: ScheduleAlertFilter.overdue,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<MaintenanceRecent>(
      future: _recentFuture,
      builder: (context, snap) {
        final recent = snap.data ?? _cachedRecent;

        if (recent == null &&
            snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              height: 72,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        if (recent == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _buildStatsRow(recent),
        );
      },
    );
  }

  Widget _buildRecentSection() {
    return FutureBuilder<MaintenanceRecent>(
      future: _recentFuture,
      builder: (context, snap) {
        final recent = snap.data ?? _cachedRecent;

        // Only show a spinner on the first load — keep content while refreshing
        // so returning from Quick Actions does not jump the scroll position.
        if (recent == null &&
            snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }

        if (recent == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardGray,
              borderRadius: BorderRadius.circular(16),
              boxShadow: kSoftShadowSm,
            ),
            child: Column(
              children: [
                const Text(
                  "Couldn't load recent activity",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _refreshRecent, child: const Text("Retry")),
              ],
            ),
          );
        }

        final dateFmt = DateFormat("MMM d");
        final overdueById = <int, MaintenanceSchedule>{};
        for (final s in [
          ...recent.upcomingSchedules,
          ...recent.dueSoonSchedules,
        ]) {
          if (s.isOverdue) overdueById[s.id] = s;
        }
        final overdueList = overdueById.values.toList();
        final dueSoonList =
            recent.dueSoonSchedules.where((s) => !s.isOverdue).toList();
        final overduePreview = overdueList.take(3).toList();
        final dueSoonPreview = dueSoonList.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overduePreview.isNotEmpty) ...[
              _SectionHeader(
                title: "Overdue",
                onSeeAll: () => _pushAndKeepSearchClosed(
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScheduleAlertsScreen(
                        filter: ScheduleAlertFilter.overdue,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < overduePreview.length; i++)
                ProductListRow(
                  leading: ProductListRow.thumbnail(
                    background: const Color(0xFFFEE2E2),
                    child: Image.asset(
                      "assets/images/overdue_date.png",
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.hourglass_bottom_rounded,
                        color: Color(0xFFEF4444),
                        size: 26,
                      ),
                    ),
                  ),
                  title: overduePreview[i].title,
                  subtitle: ProductListRow.joinMeta([
                    overduePreview[i].equipmentName ?? "Equipment",
                    if (overduePreview[i].room != null &&
                        overduePreview[i].room!.trim().isNotEmpty &&
                        overduePreview[i].room != "—")
                      overduePreview[i].room,
                    if (overduePreview[i].nextDate != null)
                      "Next: ${dateFmt.format(overduePreview[i].nextDate!)}",
                    overduePreview[i].relativeDueLabel,
                  ]),
                  actionLabel: "View",
                  showDivider: i < overduePreview.length - 1,
                  padding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
                  onTap: () {
                    final s = overduePreview[i];
                    _showCardPreview(
                      title: s.title,
                      accent: const Color(0xFFEF4444),
                      icon: Icons.hourglass_bottom_rounded,
                      badge: s.relativeDueLabel,
                      destination: ScanDestination.schedule,
                      details: [
                        (
                          label: "Equipment",
                          value: s.equipmentName ?? "Equipment",
                        ),
                        if (s.room != null &&
                            s.room!.trim().isNotEmpty &&
                            s.room != "—")
                          (label: "Room", value: s.room!),
                        if (s.nextDate != null)
                          (
                            label: "Next due",
                            value: dateFmt.format(s.nextDate!),
                          ),
                        (label: "Status", value: s.urgencyLabel),
                        if (s.frequency.trim().isNotEmpty &&
                            s.frequency != "—")
                          (label: "Frequency", value: s.frequency),
                      ],
                    );
                  },
                ),
            ],
            if (dueSoonPreview.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SectionHeader(
                title: "Due within ${recent.dueSoonDays} days",
                onSeeAll: () => _pushAndKeepSearchClosed(
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScheduleAlertsScreen(
                        filter: ScheduleAlertFilter.dueSoon,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < dueSoonPreview.length; i++)
                ProductListRow(
                  leading: ProductListRow.thumbnail(
                    background: const Color(0xFFFFF7ED),
                    child: Image.asset(
                      "assets/images/due_within.png",
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFFF59E0B),
                        size: 26,
                      ),
                    ),
                  ),
                  title: dueSoonPreview[i].title,
                  subtitle: ProductListRow.joinMeta([
                    dueSoonPreview[i].equipmentName ?? "Equipment",
                    if (dueSoonPreview[i].room != null &&
                        dueSoonPreview[i].room!.trim().isNotEmpty &&
                        dueSoonPreview[i].room != "—")
                      dueSoonPreview[i].room,
                    if (dueSoonPreview[i].nextDate != null)
                      "Next: ${dateFmt.format(dueSoonPreview[i].nextDate!)}",
                    dueSoonPreview[i].relativeDueLabel,
                  ]),
                  actionLabel: "View",
                  showDivider: i < dueSoonPreview.length - 1,
                  padding: const EdgeInsets.fromLTRB(0, 12, 4, 12),
                  onTap: () {
                    final s = dueSoonPreview[i];
                    _showCardPreview(
                      title: s.title,
                      accent: const Color(0xFFF59E0B),
                      icon: Icons.schedule_rounded,
                      badge: s.relativeDueLabel,
                      destination: ScanDestination.schedule,
                      details: [
                        (
                          label: "Equipment",
                          value: s.equipmentName ?? "Equipment",
                        ),
                        if (s.room != null &&
                            s.room!.trim().isNotEmpty &&
                            s.room != "—")
                          (label: "Room", value: s.room!),
                        if (s.nextDate != null)
                          (
                            label: "Next due",
                            value: dateFmt.format(s.nextDate!),
                          ),
                        (label: "Status", value: s.urgencyLabel),
                        if (s.frequency.trim().isNotEmpty &&
                            s.frequency != "—")
                          (label: "Frequency", value: s.frequency),
                      ],
                    );
                  },
                ),
            ],
            if (recent.attentionEquipment.isNotEmpty ||
                recent.recentHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: "Activity",
                onSeeAll: () => _pushAndKeepSearchClosed(
                  _activitySegment == 0
                      ? Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const EquipmentScreen(attentionOnly: true),
                          ),
                        )
                      : Navigator.pushNamed(context, "/maintenance"),
                ),
              ),
              const SizedBox(height: 12),
              _ActivityPanel(
                index: _activitySegment,
                attentionCount: recent.attentionEquipment.length,
                fixesCount: recent.recentHistory.length,
                onChanged: (i) => setState(() => _activitySegment = i),
                child: () {
                  if (_activitySegment == 0) {
                    final items = recent.attentionEquipment.take(3).toList();
                    if (items.isEmpty) {
                      return const _ActivityEmpty(
                        text: "Nothing needs attention right now.",
                      );
                    }
                    return Column(
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              indent: 70,
                              color: Color(0xFFF1F5F9),
                            ),
                          _ActivityFeedRow(
                            leading: const Center(
                              child: Text(
                                "!",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  height: 1,
                                ),
                              ),
                            ),
                            title: items[i].name,
                            subtitle: items[i].room.trim().isNotEmpty &&
                                    items[i].room != "—"
                                ? items[i].room
                                : (items[i].category.trim().isNotEmpty &&
                                        items[i].category != "—"
                                    ? items[i].category
                                    : "Equipment"),
                            badge: items[i].status,
                            badgeTone: _ActivityBadgeTone.alert,
                            onTap: () => _showCardPreview(
                              title: items[i].name,
                              accent: const Color(0xFFEA580C),
                              icon: Icons.warning_amber_rounded,
                              details: [
                                (label: "Room", value: items[i].room),
                                (label: "Status", value: items[i].status),
                                if (items[i].category.trim().isNotEmpty &&
                                    items[i].category != "—")
                                  (
                                    label: "Category",
                                    value: items[i].category,
                                  ),
                                if (items[i].condition.trim().isNotEmpty &&
                                    items[i].condition != "—")
                                  (
                                    label: "Condition",
                                    value: items[i].condition,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  final items = recent.recentHistory.take(3).toList();
                  if (items.isEmpty) {
                    return const _ActivityEmpty(text: "No recent fixes yet.");
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 70,
                            color: Color(0xFFF1F5F9),
                          ),
                        _ActivityFeedRow(
                          leading: const Icon(
                            Icons.build_rounded,
                            color: Color(0xFF0F172A),
                            size: 26,
                          ),
                          title: items[i].equipmentName ?? "Equipment",
                          subtitle: [
                            if (items[i].room != null &&
                                items[i].room!.trim().isNotEmpty &&
                                items[i].room != "—")
                              items[i].room!,
                            dateFmt.format(items[i].date.toLocal()),
                          ].join(" · "),
                          badge: items[i].status,
                          badgeTone: _ActivityBadgeTone.ok,
                          onTap: () => _showCardPreview(
                            title: items[i].equipmentName ?? "Equipment",
                            accent: const Color(0xFFEA580C),
                            icon: Icons.build_rounded,
                            destination: ScanDestination.history,
                            details: [
                              if (items[i].room != null &&
                                  items[i].room!.trim().isNotEmpty &&
                                  items[i].room != "—")
                                (label: "Room", value: items[i].room!),
                              (label: "Status", value: items[i].status),
                              (
                                label: "Date",
                                value: dateFmt.format(items[i].date.toLocal()),
                              ),
                              if (items[i].personnel.trim().isNotEmpty)
                                (
                                  label: "Personnel",
                                  value: items[i].personnel,
                                ),
                              if (items[i].findings != null &&
                                  items[i].findings!.trim().isNotEmpty)
                                (
                                  label: "Findings",
                                  value: items[i].findings!,
                                ),
                              if (items[i].repairAction != null &&
                                  items[i].repairAction!.trim().isNotEmpty)
                                (
                                  label: "Repair",
                                  value: items[i].repairAction!,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }(),
              ),
            ],
            if (overdueList.isEmpty &&
                dueSoonList.isEmpty &&
                recent.attentionEquipment.isEmpty &&
                recent.recentHistory.isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardGray,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: kSoftShadowSm,
                ),
                child: Column(
                  children: [
                    const Text(
                      "No recent activity yet",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Scan a QR or open Quick Actions to get started.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _pushAndKeepSearchClosed(
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QRScannerScreen(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text("Start scanning"),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF0F4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _ink, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _homeSearch,
              focusNode: _homeSearchFocus,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                if (value.trim().isEmpty) return;
                _openEquipmentSearch(value);
              },
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
            onPressed: () {
              final q = _homeSearch.text.trim();
              if (q.isEmpty) return;
              _openEquipmentSearch(q);
            },
            icon: const Icon(Icons.tune_rounded, color: _ink, size: 22),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDE6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Image behind — free to fill top↔bottom and spill left without
          // affecting text layout.
          Positioned(
            right: -8,
            top: 0,
            bottom: 0,
            width: 190,
            child: Image.asset(
              "assets/images/maintenance_home_card_image.png",
              fit: BoxFit.fitHeight,
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          // Text + CTA on top layer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 110, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome back!",
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Scan an equipment QR code to\nmanage its maintenance.",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _pushAndKeepSearchClosed(
                    Navigator.pushNamed(context, "/scanner"),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      "Start scanning",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x660F172A),
      builder: (ctx) {
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
                    color: Color(0xFFEAF1FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Sign out?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You’ll need to sign in again to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Sign out",
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
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
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

    if (shouldLogout == true) {
      await RoleSession.clear();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, "/login", (r) => false);
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2563EB),
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            "See all",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}

enum _ActivityBadgeTone { alert, ok }

class _ActivityPanel extends StatelessWidget {
  final int index;
  final int attentionCount;
  final int fixesCount;
  final ValueChanged<int> onChanged;
  final Widget child;

  const _ActivityPanel({
    required this.index,
    required this.attentionCount,
    required this.fixesCount,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEEF0F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ActivityTab(
                    label: "Needs attention",
                    count: attentionCount,
                    selected: index == 0,
                    onTap: () => onChanged(0),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActivityTab(
                    label: "Recent fixes",
                    count: fixesCount,
                    selected: index == 1,
                    onTap: () => onChanged(1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          child,
        ],
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF5F5F5) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE8EAED),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$count",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityFeedRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String badge;
  final _ActivityBadgeTone badgeTone;
  final VoidCallback onTap;

  const _ActivityFeedRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeTone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAlert = badgeTone == _ActivityBadgeTone.alert;
    final badgeBg =
        isAlert ? const Color(0xFFFFF1E8) : const Color(0xFFEEF6FF);
    final badgeFg =
        isAlert ? const Color(0xFFEA580C) : const Color(0xFF2563EB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                child: Center(child: leading),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 92),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  final String text;

  const _ActivityEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 16,
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final _MaintenanceTool tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageSize =
                (constraints.maxWidth * 0.48).clamp(52.0, 68.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFEEF0F4)),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + imageSize * 0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          height: 1.15,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(right: imageSize * 0.55),
                        child: Text(
                          tool.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: IgnorePointer(
                    child: Image.asset(
                      tool.imageAsset,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  final Color color;
  final Color background;

  const _CircleIcon({
    required this.icon,
    required this.onTap,
    this.badge = false,
    this.color = const Color(0xFF0F172A),
    this.background = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xFFE8EBE6)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              if (badge)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeechTailPainter extends CustomPainter {
  final Color color;

  _SpeechTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height * 0.55)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SpeechTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onEquipment;
  final VoidCallback onSchedule;
  final VoidCallback onLogout;

  const _BottomBar({
    required this.currentIndex,
    required this.onHome,
    required this.onEquipment,
    required this.onSchedule,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    // Material 3 BottomAppBar shadows are often invisible; paint an explicit
    // upward shadow so the notched top edge stays readable on a white page.
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0B2F64),
            blurRadius: 18,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomItem(
                icon: Icons.home_rounded,
                label: "Home",
                active: currentIndex == 0,
                onTap: onHome,
              ),
              _BottomItem(
                icon: Icons.inventory_2_outlined,
                label: "Equipment",
                active: currentIndex == 1,
                onTap: onEquipment,
              ),
              const SizedBox(width: 48),
              _BottomItem(
                icon: Icons.event_outlined,
                label: "Schedule",
                active: currentIndex == 2,
                onTap: onSchedule,
              ),
              _BottomItem(
                icon: Icons.logout_rounded,
                label: "Logout",
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF0025CC) : const Color(0xFF94A3B8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _MonthDropdown({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String dateLabel;
  final List<double> sparkline;
  final String changeLabel;
  final bool changePositive;
  final String footnote;
  final VoidCallback onTap;

  const _SummaryMetricCard({
    required this.title,
    required this.value,
    required this.dateLabel,
    required this.sparkline,
    required this.changeLabel,
    required this.changePositive,
    required this.footnote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 260,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEF0F4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.6,
                        height: 1.05,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    height: 28,
                    child: CustomPaint(
                      painter: _HomeSparklinePainter(
                        values: sparkline,
                        color: changePositive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    changeLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: changePositive
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      footnote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
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

class _RecentOrderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String status;
  final VoidCallback onTap;

  const _RecentOrderRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: EquipmentGraphic(
                    name: title,
                    size: 28,
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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle.isEmpty ? "Maintenance" : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0025CC),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAreaLineChart extends StatefulWidget {
  final List<String> labels;
  final List<double> seriesA;
  final List<double> seriesB;
  final Color colorA;
  final Color colorB;

  const _HomeAreaLineChart({
    required this.labels,
    required this.seriesA,
    required this.seriesB,
    required this.colorA,
    required this.colorB,
  });

  @override
  State<_HomeAreaLineChart> createState() => _HomeAreaLineChartState();
}

class _HomeAreaLineChartState extends State<_HomeAreaLineChart> {
  int? _focus;

  void _setFocus(Offset local, double width) {
    if (widget.labels.isEmpty || width <= 0) return;
    final i = chartNearestIndex(local.dx, width, widget.labels.length);
    if (_focus != i) setState(() => _focus = i);
  }

  @override
  Widget build(BuildContext context) {
    final peak = [...widget.seriesA, ...widget.seriesB]
        .fold<double>(0, (m, v) => math.max(m, v));
    final maxV = peak <= 0 ? 4.0 : peak * 1.25;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final focusX = _focus == null || widget.labels.length <= 1
                  ? null
                  : constraints.maxWidth *
                      (_focus! / (widget.labels.length - 1));
              return TapRegion(
                onTapOutside: (_) {
                  if (_focus != null) setState(() => _focus = null);
                },
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) =>
                    _setFocus(d.localPosition, constraints.maxWidth),
                onPanUpdate: (d) =>
                    _setFocus(d.localPosition, constraints.maxWidth),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _HomeAreaLinePainter(
                          seriesA: widget.seriesA,
                          seriesB: widget.seriesB,
                          colorA: widget.colorA,
                          colorB: widget.colorB,
                          peak: maxV,
                          focusIndex: _focus,
                          labelCount: widget.labels.length,
                        ),
                      ),
                    ),
                    if (_focus != null && focusX != null)
                      Positioned(
                        left: (focusX - 70).clamp(
                          0.0,
                          math.max(0.0, constraints.maxWidth - 140),
                        ),
                        top: 8,
                        child: ChartTooltipBubble(
                          title: widget.labels[_focus!],
                          rows: [
                            ChartTooltipRow(
                              color: widget.colorA,
                              label: "Due soon",
                              value: chartFmtValue(
                                _focus! < widget.seriesA.length
                                    ? widget.seriesA[_focus!]
                                    : 0,
                              ),
                            ),
                            ChartTooltipRow(
                              color: widget.colorB,
                              label: "Overdue",
                              value: chartFmtValue(
                                _focus! < widget.seriesB.length
                                    ? widget.seriesB[_focus!]
                                    : 0,
                              ),
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
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in widget.labels)
              Expanded(
                child: Text(
                  label.length > 3 ? label.substring(0, 3) : label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeAreaLinePainter extends CustomPainter {
  final List<double> seriesA;
  final List<double> seriesB;
  final Color colorA;
  final Color colorB;
  final double peak;
  final int? focusIndex;
  final int labelCount;

  _HomeAreaLinePainter({
    required this.seriesA,
    required this.seriesB,
    required this.colorA,
    required this.colorB,
    required this.peak,
    this.focusIndex,
    required this.labelCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(seriesA.length, seriesB.length);
    if (n == 0 || peak <= 0) return;

    final grid = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var g = 0; g < 4; g++) {
      final y = size.height * (g / 3);
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), grid);
    }

    Offset pt(List<double> values, int i) {
      final x = n == 1 ? size.width / 2 : size.width * (i / (n - 1));
      final v = i < values.length ? values[i] : 0.0;
      final y = size.height - (v / peak) * size.height;
      return Offset(x, y.clamp(4.0, size.height - 2));
    }

    void drawSeries(List<double> values, Color color, {double stroke = 2.5}) {
      if (values.isEmpty) return;

      final line = Path();
      final fill = Path();
      for (var i = 0; i < n; i++) {
        final p = pt(values, i);
        if (i == 0) {
          line.moveTo(p.dx, p.dy);
          fill.moveTo(p.dx, size.height);
          fill.lineTo(p.dx, p.dy);
        } else {
          final prev = pt(values, i - 1);
          final cx = (prev.dx + p.dx) / 2;
          line.cubicTo(cx, prev.dy, cx, p.dy, p.dx, p.dy);
          fill.cubicTo(cx, prev.dy, cx, p.dy, p.dx, p.dy);
        }
      }
      final last = pt(values, n - 1);
      fill.lineTo(last.dx, size.height);
      fill.close();

      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fill, Paint()..shader = shader);
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    drawSeries(seriesB, colorB, stroke: 2.3);
    drawSeries(seriesA, colorA, stroke: 2.6);

    if (focusIndex != null && labelCount > 0) {
      final fi = focusIndex!.clamp(0, math.max(0, labelCount - 1));
      final fx = labelCount == 1
          ? size.width / 2
          : size.width * (fi / (labelCount - 1));
      canvas.drawLine(
        Offset(fx, 0),
        Offset(fx, size.height),
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = 1.4,
      );
      if (seriesA.isNotEmpty) {
        final ai = fi.clamp(0, seriesA.length - 1).toInt();
        final p = pt(seriesA, ai);
        canvas.drawCircle(p, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          4.5,
          Paint()
            ..color = colorA
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (seriesB.isNotEmpty) {
        final bi = fi.clamp(0, seriesB.length - 1).toInt();
        final p = pt(seriesB, bi);
        canvas.drawCircle(p, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          4.5,
          Paint()
            ..color = colorB
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * math.min(dist + dash, total);
      canvas.drawLine(start, end, paint);
      dist += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _HomeAreaLinePainter oldDelegate) {
    return oldDelegate.seriesA != seriesA ||
        oldDelegate.seriesB != seriesB ||
        oldDelegate.peak != peak ||
        oldDelegate.colorA != colorA ||
        oldDelegate.colorB != colorB ||
        oldDelegate.focusIndex != focusIndex;
  }
}

class _HomeSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _HomeSparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;
    const pad = 2.0;
    final h = size.height - pad * 2;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = pad + h - ((values[i] - minV) / span) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HomeSparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
