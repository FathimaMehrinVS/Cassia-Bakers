import 'package:flutter/foundation.dart';

class CustomerSupplierService extends ChangeNotifier {
  static final CustomerSupplierService _instance = CustomerSupplierService._internal();
  factory CustomerSupplierService() => _instance;
  CustomerSupplierService._internal();

  // Notification Alerts Configuration Toggles
  bool enableLowStockAlerts = true;
  bool enableOutOfStockAlerts = true;
  bool enableCustomerDuesAlerts = true;
  bool enableSupplierDuesAlerts = true;
  bool enableStaffDuesAlerts = true;

  void toggleLowStockAlerts(bool value) {
    enableLowStockAlerts = value;
    notifyListeners();
  }

  void toggleOutOfStockAlerts(bool value) {
    enableOutOfStockAlerts = value;
    notifyListeners();
  }

  void toggleCustomerDuesAlerts(bool value) {
    enableCustomerDuesAlerts = value;
    notifyListeners();
  }

  void toggleSupplierDuesAlerts(bool value) {
    enableSupplierDuesAlerts = value;
    notifyListeners();
  }

  void toggleStaffDuesAlerts(bool value) {
    enableStaffDuesAlerts = value;
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }
}
