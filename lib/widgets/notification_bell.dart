import 'package:flutter/material.dart';
import '../core/core.dart';
import '../core/models/product.dart';
import '../core/models/customer.dart';
import '../core/models/supplier.dart';
import '../core/models/staff.dart';
import '../core/services/product_service.dart';
import '../core/services/customer_service.dart';
import '../core/services/supplier_service.dart';
import '../core/services/staff_service.dart';
import '../core/services/customer_supplier_service.dart';
import '../screens/notifications/notification_center_page.dart';

class NotificationBell extends StatelessWidget {
  final double size;
  const NotificationBell({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CustomerSupplierService(),
      builder: (context, _) {
        final settings = CustomerSupplierService();

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
                        int count = 0;

                        // Products Stock Alerts
                        if (productsSnapshot.hasData) {
                          for (final prod in productsSnapshot.data!) {
                            if (prod.stock <= 0) {
                              if (settings.enableOutOfStockAlerts) count++;
                            } else if (prod.stock <= prod.reorderLevel) {
                              if (settings.enableLowStockAlerts) count++;
                            }
                          }
                        }

                        // Customer Dues
                        if (customersSnapshot.hasData && settings.enableCustomerDuesAlerts) {
                          for (final cust in customersSnapshot.data!) {
                            if (cust.netDue > 0) count++;
                          }
                        }

                        // Supplier Dues
                        if (suppliersSnapshot.hasData && settings.enableSupplierDuesAlerts) {
                          for (final supp in suppliersSnapshot.data!) {
                            if (supp.isEnabled && supp.netDue > 0) count++;
                          }
                        }

                        // Staff Dues
                        if (staffSnapshot.hasData && settings.enableStaffDuesAlerts) {
                          for (final st in staffSnapshot.data!) {
                            if (st.balance > 0) count++;
                          }
                        }

                        final bellIcon = Icon(Icons.notifications_outlined, size: size, color: AppTheme.textDark);

                        Widget child = bellIcon;
                        if (count > 0) {
                          child = Badge(
                            label: Text(
                              '$count',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            backgroundColor: Colors.red[800]!,
                            textColor: Colors.white,
                            offset: const Offset(4, -4),
                            child: bellIcon,
                          );
                        }

                        return IconButton(
                          icon: child,
                          tooltip: 'Notifications ($count active)',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const NotificationCenterPage()),
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
