import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../core/services/order_service.dart';
import '../../core/services/product_service.dart';
import '../../core/services/customer_supplier_service.dart';
import '../../core/services/customer_service.dart';
import '../../core/services/supplier_service.dart';
import '../../core/models/customer.dart';
import '../../core/models/supplier.dart';
import '../../core/models/order.dart';
import '../../core/models/product.dart';
import '../../widgets/home/home_widgets.dart';
import '../billing/billing_page.dart';
import '../supplier/supplier_page.dart';
import '../inventory/inventory_page.dart';
import '../customer/customer_page.dart';
import '../staff/staff_page.dart';
import '../notifications/notification_center_page.dart';
import '../reports/invoice_history_page.dart';
import '../../widgets/notification_bell.dart';

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
          const NotificationBell(size: 26),
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
          const NotificationBell(size: 26),
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
          const NotificationBell(size: 26),
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

// ─────────────────────────────────────────────────────────────────────────────
// _HomeBody – scrollable content area with real-time stats
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatefulWidget {
  final ValueChanged<int> onTabSelect;
  const _HomeBody({required this.onTabSelect});

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  DateTime _selectedDate = DateTime.now();
  late final Stream<List<OrderData>> _ordersStream;
  late final Stream<List<InventoryItem>> _productsStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = OrderService().getOrdersStream();
    _productsStream = ProductService().getInventoryItemsStream();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isTransactionOnDay(String dateStr, DateTime targetDate) {
    final cleanStr = dateStr.toLowerCase();
    
    // Format 1: 17 Jun 2026
    final months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final monthName = months[targetDate.month - 1];
    final format1 = '${targetDate.day} $monthName ${targetDate.year}';
    if (cleanStr.contains(format1)) return true;
    
    // Format 2: 17-06-2026 or 17-6-2026
    final dayStr = targetDate.day.toString();
    final dayStrPadded = targetDate.day.toString().padLeft(2, '0');
    final monthStr = targetDate.month.toString();
    final monthStrPadded = targetDate.month.toString().padLeft(2, '0');
    final format2a = '$dayStrPadded-$monthStrPadded-${targetDate.year}';
    final format2b = '$dayStr-$monthStr-${targetDate.year}';
    if (cleanStr.contains(format2a) || cleanStr.contains(format2b)) return true;
    
    return false;
  }

  String _getFormattedDateAndDay(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final weekdayStr = weekdays[date.weekday - 1];
    final monthStr = months[date.month - 1];
    return '$weekdayStr, ${date.day} $monthStr ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Horizontal padding adapts to screen width (max 480 logical pixels)
    final screenW = MediaQuery.sizeOf(context).width;
    final hPad    = screenW > 480 ? (screenW - 480) / 2 + 16.0 : 16.0;

    final actions = [
      QuickActionItem(
        label: 'New Order',
        icon: Icons.shopping_cart_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BillingPage()),
          );
        },
      ),
      QuickActionItem(
        label: 'Add stock',
        icon: Icons.add_box_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const InventoryPage(autoShowAddItemForm: true),
            ),
          );
        },
      ),
      QuickActionItem(
        label: 'Expenses',
        icon: Icons.payments_outlined,
        onTap: () => widget.onTabSelect(2),
      ),
      QuickActionItem(
        label: 'Customers',
        icon: Icons.people_outline,
        onTap: () => widget.onTabSelect(1),
      ),
      QuickActionItem(
        label: 'Reports',
        icon: Icons.analytics_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const InvoiceHistoryPage()),
          );
        },
      ),
      QuickActionItem(
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const InventoryPage()),
          );
        },
      ),
    ];

    return StreamBuilder<List<OrderData>>(
      stream: _ordersStream,
      builder: (context, ordersSnapshot) {
        return StreamBuilder<List<InventoryItem>>(
          stream: _productsStream,
          builder: (context, productsSnapshot) {
            return StreamBuilder<List<CustomerData>>(
              stream: CustomerService().getCustomers(),
              builder: (context, customersSnapshot) {
                return StreamBuilder<List<CustomerDueTransaction>>(
                  stream: CustomerService().getAllTransactionsStream(),
                  builder: (context, transactionsSnapshot) {
                    return StreamBuilder<List<SupplierData>>(
                      stream: SupplierService().getSuppliers(),
                      builder: (context, suppliersSnapshot) {
                        return StreamBuilder<List<SupplierTransaction>>(
                          stream: SupplierService().getAllTransactionsStream(),
                          builder: (context, supplierTxsSnapshot) {
                            final orders = ordersSnapshot.data ?? [];
                            final products = productsSnapshot.data ?? [];
                            final customers = customersSnapshot.data ?? [];
                            final customerTxs = transactionsSnapshot.data ?? [];
                            final suppliers = suppliersSnapshot.data ?? [];
                            final supplierTxs = supplierTxsSnapshot.data ?? [];

                            // 1. Calculate Today's Sales
                            final ordersOnSelectedDay = orders.where((o) => _isSameDay(o.date, _selectedDate)).toList();
                            final billingTotal = ordersOnSelectedDay.fold(0.0, (sum, o) => sum + o.total);

                            double customerDuesToday = 0.0;
                            for (final tx in customerTxs) {
                              if (_isSameDay(tx.date, _selectedDate) && !tx.isPayment) {
                                customerDuesToday += tx.amount;
                              }
                            }

                            double supplierDuesToday = 0.0;
                            for (final tx in supplierTxs) {
                              if (_isSameDay(tx.date, _selectedDate) && !tx.isPayment) {
                                supplierDuesToday += tx.amount;
                              }
                            }

                            final todaySales = billingTotal - customerDuesToday - supplierDuesToday;

                            // Calculate yesterday's sales for delta comparison
                            final yesterday = _selectedDate.subtract(const Duration(days: 1));
                            final ordersOnYesterday = orders.where((o) => _isSameDay(o.date, yesterday)).toList();
                            final billingTotalYesterday = ordersOnYesterday.fold(0.0, (sum, o) => sum + o.total);

                            double customerDuesYesterday = 0.0;
                            for (final tx in customerTxs) {
                              if (_isSameDay(tx.date, yesterday) && !tx.isPayment) {
                                customerDuesYesterday += tx.amount;
                              }
                            }

                            double supplierDuesYesterday = 0.0;
                            for (final tx in supplierTxs) {
                              if (_isSameDay(tx.date, yesterday) && !tx.isPayment) {
                                supplierDuesYesterday += tx.amount;
                              }
                            }

                            final yesterdaySales = billingTotalYesterday - customerDuesYesterday - supplierDuesYesterday;
                            final diff = todaySales - yesterdaySales;
                            
                            double percentDiff = 0.0;
                            if (yesterdaySales != 0) {
                              percentDiff = (diff / yesterdaySales) * 100;
                            } else if (todaySales != 0) {
                              percentDiff = todaySales > 0 ? 100.0 : -100.0;
                            }

                            final String deltaText;
                            if (yesterdaySales == 0 && todaySales == 0) {
                              deltaText = '0.0% from yesterday';
                            } else {
                              final sign = percentDiff >= 0 ? '+' : '';
                              deltaText = '$sign${percentDiff.toStringAsFixed(1)}% from yesterday';
                            }

                            // 2. Pending Due (total outstanding you need to get from customers and suppliers)
                            final totalCustomerDue = customers.fold(0.0, (sum, c) => sum + c.netDue);
                            final totalSupplierDue = suppliers.fold(0.0, (sum, s) => sum + s.netDue);
                            final pendingDue = totalCustomerDue + totalSupplierDue;

                            // 3. Today's orders count
                            final todayOrdersCount = ordersOnSelectedDay.length;

                            // 4. Out of stock items count (stock == 0)
                            final outOfStockCount = products.where((p) => p.stock == 0).length;

                            return SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Greeting
                                  const HomeGreeting(
                                    greeting: 'Good Morning 👋,',
                                    userName: 'Admin',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getFormattedDateAndDay(DateTime.now()),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMid,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // 2. Today's Sales Card
                                  TodaysSalesCard(
                                    amount: '₹${todaySales.toStringAsFixed(0)}',
                                    delta: deltaText,
                                    selectedDate: _selectedDate,
                                    onDateChanged: (newDate) {
                                      setState(() {
                                        _selectedDate = newDate;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // 3. Stats Summary Row
                                  _StatsSummaryRow(
                                    pendingDue: pendingDue,
                                    todayOrders: todayOrdersCount,
                                    outOfStockCount: outOfStockCount,
                                    onOutOfStockTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const InventoryPage(
                                            initialStockStatusFilter: 'OUT_OF_STOCK',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 28),

                                  // 4. Quick Actions
                                  QuickActionsSection(
                                    actions: actions,
                                    onViewAll: () {},
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatsSummaryRow – three dynamic stat cards in a row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsSummaryRow extends StatelessWidget {
  const _StatsSummaryRow({
    required this.pendingDue,
    required this.todayOrders,
    required this.outOfStockCount,
    required this.onOutOfStockTap,
  });

  final double pendingDue;
  final int todayOrders;
  final int outOfStockCount;
  final VoidCallback onOutOfStockTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatSummaryCard(
          label: 'Pending Due',
          value: '₹${pendingDue.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: Colors.orange[800],
        ),
        const SizedBox(width: 10),
        StatSummaryCard(
          label: "Today's orders",
          value: '$todayOrders',
          icon: Icons.receipt_long_outlined,
          iconColor: Colors.blue[800],
        ),
        const SizedBox(width: 10),
        StatSummaryCard(
          label: 'Out of stock',
          value: '$outOfStockCount',
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.red[800],
          onTap: onOutOfStockTap,
        ),
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
