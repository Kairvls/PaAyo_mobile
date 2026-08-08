import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final Color color;

  const _MaintenanceTool({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.color,
  });
}

class _MaintenanceHomeScreenState extends State<MaintenanceHomeScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF2563EB);
  static const _bg = Color(0xFFF3F4F6);

  static const _tools = [
    _MaintenanceTool(
      title: "QR Scanner",
      subtitle: "Scan equipment",
      route: "/scanner",
      icon: Icons.qr_code_scanner_rounded,
      color: Color(0xFF2563EB),
    ),
    _MaintenanceTool(
      title: "Equipment",
      subtitle: "Browse & edit",
      route: "/equipment",
      icon: Icons.inventory_2_rounded,
      color: Color(0xFF7C3AED),
    ),
    _MaintenanceTool(
      title: "Record Fix",
      subtitle: "Log a repair",
      route: "/maintenance",
      icon: Icons.build_rounded,
      color: Color(0xFFEA580C),
    ),
    _MaintenanceTool(
      title: "Schedule",
      subtitle: "Upcoming tasks",
      route: "/schedule",
      icon: Icons.event_rounded,
      color: Color(0xFF059669),
    ),
    _MaintenanceTool(
      title: "History",
      subtitle: "Timeline log",
      route: "/history",
      icon: Icons.history_rounded,
      color: Color(0xFF0EA5E9),
    ),
  ];

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _name = "Maintenance Team";

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final stored = await _storage.read(key: "name");
    if (stored != null && stored.trim().isNotEmpty && mounted) {
      setState(() => _name = stored.trim());
    }
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
        onPressed: () => Navigator.pushNamed(context, "/scanner"),
        backgroundColor: _blue,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
      ),
      bottomNavigationBar: _BottomBar(
        onEquipment: () => Navigator.pushNamed(context, "/equipment"),
        onSchedule: () => Navigator.pushNamed(context, "/schedule"),
        onProfile: () => _confirmLogout(context),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverToBoxAdapter(child: _buildWelcomeCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      "Phase 4",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _blue.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ToolCard(
                    tool: _tools[i],
                    onTap: () =>
                        Navigator.pushNamed(context, _tools[i].route),
                  ),
                  childCount: _tools.length,
                ),
              ),
            ),
          ],
        ),
      ),
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
              const Text(
                "Home",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              _CircleIcon(
                icon: Icons.notifications_none_rounded,
                badge: true,
                onTap: () => Navigator.pushNamed(context, "/history"),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Icon(Icons.search_rounded, color: _muted),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: "Search equipment or rooms",
                hintStyle: TextStyle(color: _muted, fontSize: 14.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome back!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Scan an equipment QR code to view\nits profile and record maintenance.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, "/scanner"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      "Start scanning",
                      style: TextStyle(
                        color: _blue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sign out"),
        content: const Text("Do you want to sign out of PaAyo?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sign out"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _storage.delete(key: "token");
      await _storage.delete(key: "name");
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, "/home", (r) => false);
      }
    }
  }
}

class _ToolCard extends StatelessWidget {
  final _MaintenanceTool tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tool.icon, color: tool.color, size: 24),
              ),
              const Spacer(),
              Text(
                tool.title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tool.subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
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
    return Material(
      color: Colors.white,
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
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onEquipment;
  final VoidCallback onSchedule;
  final VoidCallback onProfile;

  const _BottomBar({
    required this.onEquipment,
    required this.onSchedule,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
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
              active: true,
              onTap: () {},
            ),
            _BottomItem(
              icon: Icons.inventory_2_outlined,
              label: "Equipment",
              onTap: onEquipment,
            ),
            const SizedBox(width: 48),
            _BottomItem(
              icon: Icons.event_outlined,
              label: "Schedule",
              onTap: onSchedule,
            ),
            _BottomItem(
              icon: Icons.person_outline_rounded,
              label: "Profile",
              onTap: onProfile,
            ),
          ],
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
