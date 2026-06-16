import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../widgets/home/home_widgets.dart';
import '../billing/billing_page.dart';
import '../supplier/supplier_page.dart';
import '../inventory/inventory_page.dart';
import '../customer/customer_page.dart';
import '../staff/staff_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Navigation destination model
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// HomePage – top-level stateful widget that owns bottom-nav state.
// ─────────────────────────────────────────────────────────────────────────────

/// Entry screen for Cassia Bakery ERP.
///
/// Responsibilities:
///   • App bar (menu, title, notification)
///   • Bottom navigation bar with centered FAB
///   • Delegates body rendering to [_HomeBody]
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_outlined,        activeIcon: Icons.home,           label: 'Home'),
    _NavItem(icon: Icons.person_outline,       activeIcon: Icons.person,         label: 'Customer'),
    _NavItem(icon: Icons.people_outline,       activeIcon: Icons.people,         label: 'Supplier'),
    _NavItem(icon: Icons.badge_outlined,       activeIcon: Icons.badge,          label: 'Staff'),
  ];

  void _onNavTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _onFabPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BillingPage()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_currentIndex == 0) {
      return AppBar(
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 26),
          tooltip: 'Menu',
          onPressed: () {
            // TODO: open drawer
          },
        ),
        title: const Text('Cassia Bakery ERP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 26),
            tooltip: 'Notifications',
            onPressed: () {
              // TODO: open notifications
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.divider),
        ),
      );
    } else if (_currentIndex == 1 || _currentIndex == 2) {
      // Unified Management Screen Header (Customer & Supplier)
      return AppBar(
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          tooltip: 'Back to Home',
          onPressed: () => setState(() => _currentIndex = 0),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_pin, color: Colors.orange[400], size: 26),
            const SizedBox(width: 8),
            const Text(
              'MANAGEMENT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 26),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Customer Toggle button
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _currentIndex = 1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _currentIndex == 1 ? Colors.green[100] : Colors.grey[200],
                            border: Border.all(
                              color: _currentIndex == 1 ? Colors.green[500]! : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Customer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _currentIndex == 1 ? Colors.green[800] : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Supplier Toggle button
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _currentIndex = 2),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _currentIndex == 2 ? Colors.green[100] : Colors.grey[200],
                            border: Border.all(
                              color: _currentIndex == 2 ? Colors.green[500]! : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Supplier',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _currentIndex == 2 ? Colors.green[800] : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppTheme.divider),
            ],
          ),
        ),
      );
    } else if (_currentIndex == 3) {
      // Management Screen Header for Staff (No top toggle tabs)
      return AppBar(
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          tooltip: 'Back to Home',
          onPressed: () => setState(() => _currentIndex = 0),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_pin, color: Colors.orange[400], size: 26),
            const SizedBox(width: 8),
            const Text(
              'MANAGEMENT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 26),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.divider),
        ),
      );
    } else {
      final titles = ['Home', 'Customer', 'Supplier', 'Staff'];
      return AppBar(
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          tooltip: 'Back',
          onPressed: () => setState(() => _currentIndex = 0),
        ),
        title: Text(titles[_currentIndex]),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.divider),
        ),
      );
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _HomeBody(onTabSelect: _onNavTapped);
      case 1:
        return const CustomerPage();
      case 2:
        return const SupplierPage();
      case 3:
        return const StaffPage();
      default:
        return _HomeBody(onTabSelect: _onNavTapped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _HomeBottomNav(
        currentIndex : _currentIndex,
        items        : _navItems,
        onTap        : _onNavTapped,
        onFabPressed : _onFabPressed,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HomeBody – scrollable content area
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final ValueChanged<int> onTabSelect;
  const _HomeBody({required this.onTabSelect});

  @override
  Widget build(BuildContext context) {
    // Horizontal padding adapts to screen width (max 480 logical pixels)
    final screenW = MediaQuery.sizeOf(context).width;
    final hPad    = screenW > 480 ? (screenW - 480) / 2 + 16.0 : 16.0;

    final actions = [
      QuickActionItem(
        label: 'New Order',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BillingPage()),
          );
        },
      ),
      QuickActionItem(label: 'Add stock'),
      QuickActionItem(label: 'Expenses'),
      QuickActionItem(
        label: 'Customers',
        onTap: () => onTabSelect(1),
      ),
      QuickActionItem(label: 'Reports'),
      QuickActionItem(
        label: 'Inventory',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const InventoryPage()),
          );
        },
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Greeting ───────────────────────────────────────────────────────
          const HomeGreeting(
            greeting : 'Good Morning 👋,',
            userName : 'Admin',
          ),

          const SizedBox(height: 20),

          // 2. Today's Sales hero card ────────────────────────────────────────
          const TodaysSalesCard(
            amount : '₹28,450',
            delta  : '+12.5 from yesterday',
          ),

          const SizedBox(height: 12),

          // 3. Stats summary row (Pending Due | Today's Orders | Low Stock) ───
          const _StatsSummaryRow(),

          const SizedBox(height: 28),

          // 4. Quick Actions grid ─────────────────────────────────────────────
          QuickActionsSection(
            actions   : actions,
            onViewAll : () {
              // TODO: navigate to all actions screen
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatsSummaryRow – three stat cards in a row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsSummaryRow extends StatelessWidget {
  const _StatsSummaryRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        StatSummaryCard(label: 'Pending Due',      value: '₹15,680'),
        SizedBox(width: 10),
        StatSummaryCard(label: "Today's orders",   value: '32'),
        SizedBox(width: 10),
        StatSummaryCard(label: 'Low stock items',  value: '7'),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HomeBottomNav – bottom nav bar with a floating centre FAB
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.onFabPressed,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  final VoidCallback onFabPressed;

  @override
  Widget build(BuildContext context) {
    // Split nav items into two halves around the centred FAB
    const fabSlotIndex = 2; // FAB sits between index 1 and index 2

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Thin top divider ─────────────────────────────────────────────────
        const Divider(height: 1, thickness: 1, color: AppTheme.divider),

        SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Background bar ────────────────────────────────────────────
              Positioned.fill(
                child: Container(color: Colors.white),
              ),

              // ── Nav items row ─────────────────────────────────────────────
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      // Insert transparent spacer where the FAB sits
                      if (i == fabSlotIndex) const _FabSpacer(),
                      _NavItemWidget(
                        item      : items[i],
                        isActive  : currentIndex == i,
                        onTap     : () => onTap(i),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Centre FAB (floats above the bar) ─────────────────────────
              Positioned(
                top  : -24,
                left : 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: onFabPressed,
                    child: Container(
                      width      : 58,
                      height     : 58,
                      decoration : const BoxDecoration(
                        color : AppTheme.primary,
                        shape : BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color       : Color(0x331A3CDB),
                            blurRadius  : 12,
                            offset      : Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── System bottom safe area ────────────────────────────────────────
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

// ── Transparent spacer that reserves width for the FAB ───────────────────────
class _FabSpacer extends StatelessWidget {
  const _FabSpacer();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 72);
}

// ── Single bottom-nav item ────────────────────────────────────────────────────
class _NavItemWidget extends StatelessWidget {
  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primary : AppTheme.textMid;

    return Expanded(
      child: InkWell(
        onTap        : onTap,
        borderRadius : BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color : color,
              size  : 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize   : 11,
                fontWeight : isActive ? FontWeight.w600 : FontWeight.w400,
                color      : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
