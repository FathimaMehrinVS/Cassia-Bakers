import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../core/models/product.dart';
import '../../core/models/customer.dart';
import '../../core/models/supplier.dart';
import '../../core/models/staff.dart';
import '../../core/services/product_service.dart';
import '../../core/services/customer_service.dart';
import '../../core/services/supplier_service.dart';
import '../../core/services/staff_service.dart';
import '../../core/services/customer_supplier_service.dart';
import '../inventory/inventory_page.dart';
import '../customer/customer_detail_page.dart';
import '../supplier/supplier_detail_page.dart';
import '../staff/staff_detail_page.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Alert Center',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSub,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'ACTIVE ALERTS'),
            Tab(text: 'SETTINGS'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: CustomerSupplierService(),
        builder: (context, _) {
          final settings = CustomerSupplierService();

          return Center(
            child: SizedBox(
              width: AppTheme.isWideScreen(context) ? 650.0 : double.infinity,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAlertsFeed(settings),
                  _buildSettingsView(settings),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertsFeed(CustomerSupplierService settings) {
    return StreamBuilder<List<InventoryItem>>(
      stream: ProductService().getInventoryItemsStream(),
      builder: (context, productsSnapshot) {
        return StreamBuilder<List<CustomerData>>(
          stream: CustomerService().getCustomers(),
          builder: (context, customersSnapshot) {
            return StreamBuilder<List<SupplierData>>(
              stream: SupplierService().getSuppliers(),
              builder: (context, suppliersSnapshot) {
                return StreamBuilder<List<StaffData>>(
                  stream: StaffService().getStaffStream(),
                  builder: (context, staffSnapshot) {
                    if (productsSnapshot.connectionState == ConnectionState.waiting &&
                        customersSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final alerts = <_AlertItem>[];

                    // Process Products
                    if (productsSnapshot.hasData) {
                      for (final prod in productsSnapshot.data!) {
                        if (prod.stock <= 0) {
                          if (settings.enableOutOfStockAlerts) {
                            alerts.add(_AlertItem(
                              type: _AlertType.outOfStock,
                              title: 'Out of Stock',
                              message: '${prod.name} has run out of stock!',
                              associatedName: prod.name,
                              severity: 1, // High
                              onAction: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const InventoryPage(initialStockStatusFilter: 'OUT_OF_STOCK'),
                                  ),
                                );
                              },
                              actionLabel: 'RESTOCK',
                            ));
                          }
                        } else if (prod.stock <= prod.reorderLevel) {
                          if (settings.enableLowStockAlerts) {
                            alerts.add(_AlertItem(
                              type: _AlertType.lowStock,
                              title: 'Low Stock',
                              message: '${prod.name} is running low (${prod.stock.toStringAsFixed(0)} ${prod.unit} left)',
                              associatedName: prod.name,
                              severity: 2, // Med
                              onAction: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const InventoryPage(initialStockStatusFilter: 'LOW_STOCK'),
                                  ),
                                );
                              },
                              actionLabel: 'RESTOCK',
                            ));
                          }
                        }
                      }
                    }

                    // Process Customers
                    if (customersSnapshot.hasData && settings.enableCustomerDuesAlerts) {
                      for (final cust in customersSnapshot.data!) {
                        if (cust.netDue > 0) {
                          alerts.add(_AlertItem(
                            type: _AlertType.customerDue,
                            title: 'Customer Pending Due',
                            message: '${cust.name} has pending dues of ₹${cust.netDue.toStringAsFixed(0)}',
                            associatedName: cust.name,
                            severity: 3,
                            onAction: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailPage(
                                    customer: cust,
                                    onChanged: () => CustomerSupplierService().notify(),
                                  ),
                                ),
                              );
                            },
                            actionLabel: 'COLLECT',
                          ));
                        }
                      }
                    }

                    // Process Suppliers
                    if (suppliersSnapshot.hasData && settings.enableSupplierDuesAlerts) {
                      for (final supp in suppliersSnapshot.data!) {
                        if (supp.isEnabled && supp.netDue > 0) {
                          alerts.add(_AlertItem(
                            type: _AlertType.supplierDue,
                            title: 'Supplier Pending Payment',
                            message: 'Payment of ₹${supp.netDue.toStringAsFixed(0)} is due to ${supp.name}',
                            associatedName: supp.name,
                            severity: 4,
                            onAction: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SupplierDetailPage(
                                    supplier: supp,
                                    onChanged: () => CustomerSupplierService().notify(),
                                  ),
                                ),
                              );
                            },
                            actionLabel: 'PAY',
                          ));
                        }
                      }
                    }

                    // Process Staff
                    if (staffSnapshot.hasData && settings.enableStaffDuesAlerts) {
                      for (final st in staffSnapshot.data!) {
                        if (st.balance > 0) {
                          alerts.add(_AlertItem(
                            type: _AlertType.staffSalaryDue,
                            title: 'Outstanding Staff Salary',
                            message: '₹${st.balance.toStringAsFixed(0)} is outstanding for ${st.name}',
                            associatedName: st.name,
                            severity: 5,
                            onAction: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StaffDetailPage(
                                    staff: st,
                                    onChanged: () => CustomerSupplierService().notify(),
                                  ),
                                ),
                              );
                            },
                            actionLabel: 'PAY SALARY',
                          ));
                        }
                      }
                    }

                    // Sort: Out of stock, Low stock, Dues
                    alerts.sort((a, b) => a.severity.compareTo(b.severity));

                    if (alerts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_circle_outline, size: 64, color: Colors.green[600]),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'All Clear!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No active alerts matching your preferences.',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return _buildAlertCard(alert);
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

  Widget _buildAlertCard(_AlertItem alert) {
    Color cardColor;
    Color borderCol;
    Color iconCol;
    IconData icon;

    switch (alert.type) {
      case _AlertType.outOfStock:
        cardColor = Colors.red[50]!;
        borderCol = Colors.red[100]!;
        iconCol = Colors.red[700]!;
        icon = Icons.error_outline_rounded;
        break;
      case _AlertType.lowStock:
        cardColor = Colors.amber[50]!;
        borderCol = Colors.amber[100]!;
        iconCol = Colors.amber[800]!;
        icon = Icons.warning_amber_rounded;
        break;
      case _AlertType.customerDue:
        cardColor = Colors.cyan[50]!;
        borderCol = Colors.cyan[100]!;
        iconCol = Colors.cyan[800]!;
        icon = Icons.arrow_downward_rounded;
        break;
      case _AlertType.supplierDue:
        cardColor = Colors.purple[50]!;
        borderCol = Colors.purple[100]!;
        iconCol = Colors.purple[800]!;
        icon = Icons.arrow_upward_rounded;
        break;
      case _AlertType.staffSalaryDue:
        cardColor = Colors.teal[50]!;
        borderCol = Colors.teal[100]!;
        iconCol = Colors.teal[800]!;
        icon = Icons.badge_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardColor.withOpacity(0.5), Colors.white],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored Icon Wrapper
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconCol, size: 24),
              ),
              const SizedBox(width: 14),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: iconCol, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 10),
                    // Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconCol,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: alert.onAction,
                      child: Text(
                        alert.actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsView(CustomerSupplierService settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title Block
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize Alerts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              SizedBox(height: 4),
              Text(
                'Select which real-time indicators you want to monitor in your alert feed.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildToggleItem(
          icon: Icons.error_outline_rounded,
          iconCol: Colors.red[800]!,
          bgCol: Colors.red[50]!,
          title: 'Out of Stock Alerts',
          description: 'Notify when a product inventory is fully depleted.',
          value: settings.enableOutOfStockAlerts,
          onChanged: settings.toggleOutOfStockAlerts,
        ),
        const Divider(height: 24, thickness: 1, color: AppTheme.divider),

        _buildToggleItem(
          icon: Icons.warning_amber_rounded,
          iconCol: Colors.amber[800]!,
          bgCol: Colors.amber[50]!,
          title: 'Low Stock Alerts',
          description: 'Notify when products dip below their defined reorder level.',
          value: settings.enableLowStockAlerts,
          onChanged: settings.toggleLowStockAlerts,
        ),
        const Divider(height: 24, thickness: 1, color: AppTheme.divider),

        _buildToggleItem(
          icon: Icons.arrow_downward_rounded,
          iconCol: Colors.cyan[800]!,
          bgCol: Colors.cyan[50]!,
          title: 'Customer Pending Dues',
          description: 'Flag customers with positive outstanding balance.',
          value: settings.enableCustomerDuesAlerts,
          onChanged: settings.toggleCustomerDuesAlerts,
        ),
        const Divider(height: 24, thickness: 1, color: AppTheme.divider),

        _buildToggleItem(
          icon: Icons.arrow_upward_rounded,
          iconCol: Colors.purple[800]!,
          bgCol: Colors.purple[50]!,
          title: 'Supplier Dues Notification',
          description: 'Track payables and invoices due to suppliers.',
          value: settings.enableSupplierDuesAlerts,
          onChanged: settings.toggleSupplierDuesAlerts,
        ),
        const Divider(height: 24, thickness: 1, color: AppTheme.divider),

        _buildToggleItem(
          icon: Icons.badge_outlined,
          iconCol: Colors.teal[800]!,
          bgCol: Colors.teal[50]!,
          title: 'Staff Outstanding Salary',
          description: 'Monitor salary credits that are pending disbursement.',
          value: settings.enableStaffDuesAlerts,
          onChanged: settings.toggleStaffDuesAlerts,
        ),
      ],
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required Color iconCol,
    required Color bgCol,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconCol, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeColor: iconCol,
            activeTrackColor: bgCol,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

enum _AlertType { outOfStock, lowStock, customerDue, supplierDue, staffSalaryDue }

class _AlertItem {
  final _AlertType type;
  final String title;
  final String message;
  final String associatedName;
  final int severity;
  final VoidCallback onAction;
  final String actionLabel;

  _AlertItem({
    required this.type,
    required this.title,
    required this.message,
    required this.associatedName,
    required this.severity,
    required this.onAction,
    required this.actionLabel,
  });
}
