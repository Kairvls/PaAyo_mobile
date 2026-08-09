import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../utils/equipment_icon.dart';
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
  final String route;
  final IconData icon;

  const _MaintenanceTool({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });
}

class _MaintenanceHomeScreenState extends State<MaintenanceHomeScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF2563EB);
  static const _navy = Color(0xFF0B2F64);
  static const _bg = Colors.white;

  static const _tools = [
    _MaintenanceTool(
      title: "Record Fix",
      subtitle: "Log a repair",
      route: "/maintenance",
      icon: Icons.build_rounded,
    ),
    _MaintenanceTool(
      title: "History",
      subtitle: "Timeline log",
      route: "/history",
      icon: Icons.history_rounded,
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

  Future<void> _promptScan(
    String? equipmentName, {
    ScanDestination destination = ScanDestination.profile,
  }) {
    return _pushAndKeepSearchClosed(
      promptScanToManage(
        context,
        equipmentName: equipmentName,
        destination: destination,
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 18) return "Good Afternoon";
    return "Good Evening";
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                sliver: SliverToBoxAdapter(child: _buildWelcomeCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                sliver: SliverToBoxAdapter(child: _buildRecentSection()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                sliver: const SliverToBoxAdapter(
                  child: Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 38),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ToolCard(
                      tool: _tools[i],
                      onTap: () => _onToolTap(_tools[i]),
                    ),
                    childCount: _tools.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onToolTap(_MaintenanceTool tool) async {
    // Quick Actions always open the full page (with back arrow). Bottom-nav
    // tabs stay as the embedded switcher.
    await _pushAndKeepSearchClosed(Navigator.pushNamed(context, tool.route));
    if (mounted) await _refreshRecent(keepScroll: true);
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatChip(
                  label: "Equipment",
                  value: "${recent.equipmentCount}",
                  color: const Color(0xFF7C3AED),
                  backgroundImage: "assets/images/equipment.jpg",
                  onTap: () => _pushAndKeepSearchClosed(
                    Navigator.pushNamed(context, "/equipment"),
                  ),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: "Due soon",
                  value: "${recent.dueSoonSchedulesCount}",
                  color: const Color(0xFFF59E0B),
                  backgroundImage: "assets/images/due_soon.jpg",
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
                  color: const Color(0xFFEF4444),
                  backgroundImage: "assets/images/overdue.jpg",
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
            ),
            if (recent.dueSoonSchedules.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Due within ${recent.dueSoonDays} days",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pushAndKeepSearchClosed(
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScheduleAlertsScreen(
                            filter: ScheduleAlertFilter.dueSoon,
                          ),
                        ),
                      ),
                    ),
                    child: const Text("See all"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...recent.dueSoonSchedules.take(3).map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecentTile(
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFFF59E0B),
                    title: s.title,
                    subtitle: [
                      s.equipmentName ?? "Equipment",
                      if (s.room != null && s.room!.trim().isNotEmpty &&
                          s.room != "—")
                        s.room!,
                      if (s.nextDate != null) dateFmt.format(s.nextDate!),
                      "Due soon",
                    ].join(" · "),
                    onTap: () => _promptScan(
                      s.equipmentName,
                      destination: ScanDestination.schedule,
                    ),
                  ),
                ),
              ),
            ],
            if (recent.attentionEquipment.isNotEmpty ||
                recent.recentHistory.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActivitySegment(
                      index: _activitySegment,
                      onChanged: (i) => setState(() => _activitySegment = i),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _pushAndKeepSearchClosed(
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
                    child: const Text("See all"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_activitySegment == 0) ...[
                if (recent.attentionEquipment.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      "Nothing needs attention right now.",
                      style: TextStyle(color: _muted, fontSize: 13.5),
                    ),
                  )
                else
                  ...recent.attentionEquipment.take(3).map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RecentTile(
                        leading: EquipmentGraphic(
                          name: e.name,
                          category: e.category,
                          size: 26,
                          fallbackColor: const Color(0xFF2563EB),
                        ),
                        color: const Color(0xFFEA580C),
                        title: e.name,
                        subtitle: "${e.room} · ${e.status}",
                        onTap: () => _promptScan(e.name),
                      ),
                    ),
                  ),
              ] else ...[
                if (recent.recentHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      "No recent fixes yet.",
                      style: TextStyle(color: _muted, fontSize: 13.5),
                    ),
                  )
                else
                  ...recent.recentHistory.take(3).map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RecentTile(
                        icon: Icons.build_rounded,
                        color: _blue,
                        iconBg: const Color(0xFFEAF1FF),
                        title: r.equipmentName ?? "Equipment",
                        subtitle: [
                          if (r.room != null &&
                              r.room!.trim().isNotEmpty &&
                              r.room != "—")
                            r.room!,
                          r.status,
                          dateFmt.format(r.date.toLocal()),
                        ].join(" · "),
                        onTap: () => _promptScan(
                          r.equipmentName,
                          destination: ScanDestination.history,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
            if (recent.dueSoonSchedules.isEmpty &&
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleIcon(
                icon: Icons.grid_view_rounded,
                onTap: () {},
              ),
              Image.asset(
                "assets/images/paayo_logo_second.png",
                height: 62,
                fit: BoxFit.contain,
              ),
              FutureBuilder<MaintenanceRecent>(
                future: _recentFuture,
                builder: (context, snap) {
                  final recent = snap.data ?? _cachedRecent;
                  final alertCount = (recent?.dueSoonSchedulesCount ?? 0) +
                      (recent?.overdueSchedules ?? 0);
                  return _CircleIcon(
                    icon: Icons.notifications_none_rounded,
                    badge: alertCount > 0,
                    onTap: () async {
                      await _pushAndKeepSearchClosed(
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScheduleAlertsScreen(),
                          ),
                        ),
                      );
                      if (mounted) await _refreshRecent(keepScroll: true);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Hi, $_name!",
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _greeting,
            style: const TextStyle(
              fontSize: 14,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: kCardGray,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _muted, size: 22),
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
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: "Search...",
                hintStyle: TextStyle(color: _muted, fontSize: 14.5),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: const Color(0xFFCBD5E1),
          ),
          IconButton(
            tooltip: "Search",
            onPressed: () {
              final q = _homeSearch.text.trim();
              if (q.isEmpty) return;
              _openEquipmentSearch(q);
            },
            icon: const Icon(Icons.tune_rounded, color: _muted, size: 22),
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
          // Full image sits behind, on the right, slightly overlapping toward
          // the center; the text column below is painted on top of it.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 150,
            child: Image.asset(
              "assets/images/maintenance_home_card_image.png",
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 96, 18),
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
                      color: _blue,
                      borderRadius: BorderRadius.circular(30),
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
      await _storage.delete(key: "token");
      await _storage.delete(key: "name");
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, "/login", (r) => false);
      }
    }
  }
}

class _ActivitySegment extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _ActivitySegment({
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kCardGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentPill(
              label: "Needs attention",
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentPill(
              label: "Recent fixes",
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Center(
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
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? backgroundImage;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    this.backgroundImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: kSoftShadowSm,
        ),
        child: Material(
          color: backgroundImage == null ? kCardGray : Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                if (backgroundImage != null)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Image.asset(
                        backgroundImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Padding(
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
                          color: Color(0xFF334155),
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
  }
}

class _RecentTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color color;
  final Color? iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RecentTile({
    this.icon,
    this.leading,
    required this.color,
    this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: kSoftShadowSm,
      ),
      child: Material(
      color: kCardGray,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: leading != null ? const EdgeInsets.all(7) : null,
                decoration: BoxDecoration(
                  color: leading != null
                      ? Colors.white
                      : (iconBg ?? color.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: leading ?? Icon(icon, color: color, size: 20),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
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

  static const _navy = Color(0xFF0B2F64);
  static const _iconBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B2F64),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: _navy.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(tool.icon, color: _iconBlue, size: 24),
                ),
                const Spacer(),
                Text(
                  tool.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tool.subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
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

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  const _CircleIcon({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: kSoftShadowSm,
      ),
      child: Material(
      color: kCardGray,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: const Color(0xFF0F172A), size: 22),
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
      ),
    );
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
    final color = active ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);
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
