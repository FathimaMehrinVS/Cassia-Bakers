import 'package:flutter/foundation.dart';
import '../../screens/customer/customer_page.dart';
import '../../screens/supplier/supplier_page.dart';

class CustomerSupplierService extends ChangeNotifier {
  static final CustomerSupplierService _instance = CustomerSupplierService._internal();
  factory CustomerSupplierService() => _instance;
  CustomerSupplierService._internal();

  final List<CustomerData> customers = [
    CustomerData(
      id: 'c000',
      name: 'Rahul Sharma',
      phone: '+91 98765 43210',
      dateAdded: '10 Jun 2026',
      transactions: [
        CustomerDueTransaction(description: 'Initial Due (Order #1002)', date: '10 Jun 2026 at 11:32 AM', amount: 2500, isPayment: false),
        CustomerDueTransaction(description: 'Cash Payment', date: '11 Jun 2026 at 11:32 AM', amount: 1000, isPayment: true),
      ],
    ),
    CustomerData(
      id: 'c001',
      name: 'Priya Nair',
      phone: '+91 87654 32109',
      dateAdded: '12 Jun 2026',
      transactions: [
        CustomerDueTransaction(description: 'Initial Due (Order #1005)', date: '12 Jun 2026 at 11:32 AM', amount: 850, isPayment: false),
      ],
    ),
    CustomerData(
      id: 'c002',
      name: 'Amit Patel',
      phone: '+91 76543 21098',
      dateAdded: '14 Jun 2026',
      transactions: [
        CustomerDueTransaction(description: 'Order #1012', date: '14 Jun 2026 at 11:32 AM', amount: 3200, isPayment: false),
      ],
    ),
    CustomerData(
      id: 'c003',
      name: 'Sneha Rao',
      phone: '+91 65432 10987',
      dateAdded: '15 Jun 2026',
      transactions: [],
    ),
  ];

  final List<SupplierData> suppliers = [
    SupplierData(
      id: 'sri_lakshmi',
      name: 'Sri Lakshmi Foods',
      phone: '+9198765 43210',
      gstin: '32AABCU1234K1Z5',
      status: 'ACTIVE',
      isEnabled: true,
      bills: [
        BillData(
          billNo: 'BILL-1020',
          date: '15-05-2026',
          subtotal: 350.0,
          gst: 17.5,
          total: 367.5,
          notes: 'Regular monthly supply of spices.',
          items: [
            BillItemRow(name: 'Cardamom', quantity: 1, unit: 'kg', rate: 200),
            BillItemRow(name: 'Black Pepper', quantity: 1.5, unit: 'kg', rate: 100),
          ],
        ),
        BillData(
          billNo: 'BILL-1023',
          date: '22-05-2026',
          subtotal: 540.0,
          gst: 27.0,
          total: 567.0,
          notes: 'Flour delivery.',
          items: [
            BillItemRow(name: 'All Purpose Flour', quantity: 10, unit: 'kg', rate: 40),
            BillItemRow(name: 'Wheat Flour', quantity: 5, unit: 'kg', rate: 28),
          ],
        ),
      ],
      transactions: [
        SupplierTransaction(description: 'Bill BILL-1020', date: '15-05-2026 at 11:32 AM', amount: 367.5, isPayment: false),
        SupplierTransaction(description: 'Bill BILL-1023', date: '22-05-2026 at 11:32 AM', amount: 567.0, isPayment: false),
        SupplierTransaction(description: 'Cash Payment', date: '23-05-2026 at 06:00 PM', amount: 500.0, isPayment: true),
      ],
    ),
    SupplierData(
      id: 'kerala_snacks',
      name: 'Kerala Snacks Supply',
      phone: '+9198765 43210',
      gstin: '32AABCU1234K1Z5',
      status: 'ACTIVE',
      isEnabled: true,
      bills: [
        BillData(
          billNo: 'BILL-1018',
          date: '10-05-2026',
          subtotal: 980.0,
          gst: 49.0,
          total: 1029.0,
          notes: 'Initial snack load for summer season.',
          items: [
            BillItemRow(name: 'Banana Chips', quantity: 5, unit: 'kg', rate: 120),
            BillItemRow(name: 'Tapioca Chips', quantity: 4, unit: 'kg', rate: 95),
          ],
        ),
      ],
      transactions: [
        SupplierTransaction(description: 'Bill BILL-1018', date: '10-05-2026 at 11:32 AM', amount: 1029.0, isPayment: false),
        SupplierTransaction(description: 'Bank Transfer', date: '11-05-2026 at 04:30 PM', amount: 1000.0, isPayment: true),
      ],
    ),
    SupplierData(
      id: 'global_dry_fruits',
      name: 'Global Dry Fruits',
      phone: '+9198765 43210',
      gstin: '32AABCU1234K1Z5',
      status: 'INACTIVE',
      isEnabled: false,
      bills: [],
      transactions: [],
    ),
  ];

  void notify() {
    notifyListeners();
  }
}
