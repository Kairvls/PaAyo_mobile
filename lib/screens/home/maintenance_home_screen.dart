import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/equipment.dart';
import '../../services/maintenance_service.dart';
import '../../utils/equipment_icon.dart';
import '../equipment/equipment_screen.dart';
import '../qr/qr_scanner_screen.dart';
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
  static const _blue = Color(0xFF2563EB);
  static const _navy = Color(0xFF0B2F64);
  static const _bg = Color(0xFFF5F5F5);
  static const _accent = Color(0xFF0B2F64);

  static const _tools = [
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                sliver: SliverToBoxAdapter(child: _buildWelcomeCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                  child: Row(
                    children: [
                      for (int i = 0; i < _tools.length; i++) ...[
                        if (i > 0) const SizedBox(width: 14),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1.12,
                            child: _ToolCard(
                              tool: _tools[i],
                              onTap: () => _onToolTap(_tools[i]),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                sliver: SliverToBoxAdapter(child: _buildRecentSection()),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            ),
            if (overdueList.isNotEmpty) ...[
              const SizedBox(height: 22),
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
              _QuietListCard(
                children: [
                  for (final s in overdueList.take(3))
                    _QuietListRow(
                      leading: Image.asset(
                        "assets/images/overdue_date.png",
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.hourglass_bottom_rounded,
                          color: Color(0xFFEF4444),
                          size: 28,
                        ),
                      ),
                      color: const Color(0xFFEF4444),
                      title: s.title,
                      subtitle: [
                        s.equipmentName ?? "Equipment",
                        if (s.room != null &&
                            s.room!.trim().isNotEmpty &&
                            s.room != "—")
                          s.room!,
                      ].join(" · "),
                      trailing: s.relativeDueLabel,
                      onTap: () => _showCardPreview(
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
                      ),
                    ),
                ],
              ),
            ],
            if (dueSoonList.isNotEmpty) ...[
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
              _QuietListCard(
                children: [
                  for (final s in dueSoonList.take(3))
                    _QuietListRow(
                      leading: Image.asset(
                        "assets/images/due_within.png",
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFFF59E0B),
                          size: 28,
                        ),
                      ),
                      color: const Color(0xFFF59E0B),
                      title: s.title,
                      subtitle: [
                        s.equipmentName ?? "Equipment",
                        if (s.room != null &&
                            s.room!.trim().isNotEmpty &&
                            s.room != "—")
                          s.room!,
                      ].join(" · "),
                      trailing: s.relativeDueLabel,
                      onTap: () => _showCardPreview(
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
                      ),
                    ),
                ],
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
      await _storage.delete(key: "token");
      await _storage.delete(key: "name");
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

class _QuietListCard extends StatelessWidget {
  final List<Widget> children;

  const _QuietListCard({required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _QuietListRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color color;
  final Color? iconBg;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;
  final bool compact;

  const _QuietListRow({
    this.icon,
    this.leading,
    required this.color,
    this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final leadSize = 50.0;
    final pad = compact
        ? const EdgeInsets.fromLTRB(12, 8, 8, 8)
        : const EdgeInsets.fromLTRB(14, 12, 10, 12);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(compact ? 16 : 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        child: Container(
          padding: pad,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 16 : 20),
            border: Border.all(color: const Color(0xFFEEF0F4)),
          ),
          child: Row(
            children: [
              if (leading != null)
                SizedBox(
                  width: leadSize,
                  height: leadSize,
                  child: leading,
                )
              else
                Container(
                  width: leadSize,
                  height: leadSize,
                  decoration: BoxDecoration(
                    color: iconBg ?? color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 14.5 : 15,
                        color: const Color(0xFF0F172A),
                        height: 1.15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      SizedBox(height: compact ? 2 : 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 12.5 : 13,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              trailing!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
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
        child: Stack(
          children: [
            // Soft edge so white cards still read on white page
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEEF0F4)),
                ),
              ),
            ),
            // Text — top/left + bottom meta
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.title,
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                      height: 1.25,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 72),
                    child: Text(
                      tool.meta,
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
            // Bottom-right illustration
            Positioned(
              right: -6,
              bottom: -8,
              child: IgnorePointer(
                child: Image.asset(
                  tool.imageAsset,
                  width: 94,
                  height: 94,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
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
    return Material(
      color: Colors.white,
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xFFEEF0F4)),
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
