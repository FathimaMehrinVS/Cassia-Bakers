import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/core.dart';
import '../../core/models/staff.dart';
import '../../core/services/staff_service.dart';
import 'staff_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StaffPage Widget
// ─────────────────────────────────────────────────────────────────────────────

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedStaffIds = {};

  // ── Add Staff Form State ───────────────────────────────────────────────────
  bool _showAddStaffForm = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Handlers ───────────────────────────────────────────────────────────────
  Future<void> _saveStaff() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showErrorSnackbar('Please enter Staff Name');
      return;
    }
    if (phone.isEmpty) {
      _showErrorSnackbar('Please enter Phone Number');
      return;
    }

    final newId = 'st_${DateTime.now().millisecondsSinceEpoch}';
    final nowStr = '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}';

    final staffMember = StaffData(
      id: newId,
      name: name,
      phone: phone,
      dateAdded: nowStr,
      balance: 0.0,
    );

    try {
      await StaffService().addStaff(staffMember);

      setState(() {
        _nameController.clear();
        _phoneController.clear();
        _showAddStaffForm = false;
      });

      _showSuccessSnackbar('Staff member "$name" added successfully!');
    } catch (e) {
      _showErrorSnackbar('Error adding staff: $e');
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'Jun';
  }

  void _showSuccessSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.positive,
      ),
    );
  }

  void _showErrorSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffData>>(
      stream: StaffService().getStaffStream(),
      builder: (context, snapshot) {
        final staffList = snapshot.data ?? [];
        final totalNetBalance = staffList.fold(0.0, (sum, s) => sum + s.balance);
        final accountsCount = staffList.length;
        final hasPayable = totalNetBalance > 0;

        return Stack(
          children: [
              // Main Scrollable Area
              SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  AppTheme.getResponsivePadding(context),
                  _selectedStaffIds.isNotEmpty ? 72 : 16,
                  AppTheme.getResponsivePadding(context),
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Hero Balance Card ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.grey[400]!, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Net Balance',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 16, color: AppTheme.textDark),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$accountsCount Accounts',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹ ',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: hasPayable ? Colors.green[800] : Colors.green[800]),
                              ),
                              Text(
                                totalNetBalance.toStringAsFixed(0),
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: hasPayable ? Colors.green[800] : Colors.green[800]),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Salary',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 2. Scrollable Staff Directory List ────────────────────────
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: staffList.length,
                      itemBuilder: (context, idx) {
                        final staff = staffList[idx];
                        final isDue = staff.balance > 0;
                        final isSelected = _selectedStaffIds.contains(staff.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.indigo[50] : Colors.grey[100],
                            border: Border.all(
                              color: isSelected ? Colors.indigo[400]! : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              if (_selectedStaffIds.isNotEmpty) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedStaffIds.remove(staff.id);
                                  } else {
                                    _selectedStaffIds.add(staff.id);
                                  }
                                });
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => StaffDetailPage(
                                      staff: staff,
                                      onChanged: () {
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
                              HapticFeedback.vibrate();
                              setState(() {
                                if (isSelected) {
                                  _selectedStaffIds.remove(staff.id);
                                } else {
                                  _selectedStaffIds.add(staff.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Avatar placeholder or checkmark
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.indigo[100] : Colors.grey[300],
                                      border: Border.all(
                                        color: isSelected ? Colors.indigo[300]! : Colors.grey[400]!,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: isSelected
                                        ? const Icon(Icons.check, color: Colors.indigo, size: 24)
                                        : const Text(
                                            '[pic]',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Details block
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          staff.name,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          staff.phone,
                                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          staff.dateAdded,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Balance indicator
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹ ${staff.balance.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDue ? Colors.green[800] : Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Salary',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 80), // Space for bottom FAB
                  ],
                ),
              ),

              // ── 3. Add Staff Bottom Sheet Overlay ──
              if (_showAddStaffForm)
                _buildAddStaffOverlay(),

              // ── 4. Add Staff FAB ──
              if (!_showAddStaffForm && _selectedStaffIds.isEmpty)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showAddStaffForm = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green[500],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.person_add_alt_1_sharp, color: Colors.black, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Add Staff',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Contextual Selection Toolbar ──
              if (_selectedStaffIds.isNotEmpty)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _selectedStaffIds.clear();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedStaffIds.length} Selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () => _confirmDeleteStaff(context),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

  // ── Overlay: Add Staff ──
  Widget _buildAddStaffOverlay() {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showAddStaffForm = false),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // Prevent click propagation
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (screenHeight - topPadding - 56) * 0.85,
              ),
              child: Container(
                width: AppTheme.isWideScreen(context) ? 500 : double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16,
                  bottomPadding + 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Add New Staff Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _showAddStaffForm = false),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('Staff Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter staff name',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Staff Phone Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Enter staff phone number',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => setState(() => _showAddStaffForm = false),
                              child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                minimumSize: const Size(0, 48),
                                elevation: 0,
                              ),
                              onPressed: _saveStaff,
                              child: const Text('SAVE STAFF', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteStaff(BuildContext ctx) async {
    final count = _selectedStaffIds.length;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Delete $count ${count == 1 ? 'Staff Member' : 'Staff Members'}?',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${count == 1 ? 'this staff member' : 'these staff members'}? '
          'This will permanently delete all associated ledger transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final idsToDelete = List<String>.from(_selectedStaffIds);
        for (final id in idsToDelete) {
          await StaffService().deleteStaff(id);
        }
        setState(() {
          _selectedStaffIds.clear();
        });
        _showSuccessSnackbar('Deleted staff member(s) successfully!');
      } catch (e) {
        _showErrorSnackbar('Failed to delete staff member(s): $e');
      }
    }
  }
}
