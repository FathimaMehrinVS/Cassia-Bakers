import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/core.dart';

class TransactionEntryPage extends StatefulWidget {
  final String title;
  final String phone;
  final double currentDue;
  final String dueLabel;
  final bool isPayment; // true if cash received/paid (green), false if credit given/salary (red)
  final String avatarInitial;
  final Color avatarColor;
  final Function(double amount, String notes, DateTime date, Uint8List? attachedImageBytes, String? attachedImageName) onConfirm;

  const TransactionEntryPage({
    super.key,
    required this.title,
    required this.phone,
    required this.currentDue,
    required this.dueLabel,
    required this.isPayment,
    required this.avatarInitial,
    required this.avatarColor,
    required this.onConfirm,
  });

  @override
  State<TransactionEntryPage> createState() => _TransactionEntryPageState();
}

class _TransactionEntryPageState extends State<TransactionEntryPage> {
  String _amountString = '0';
  double _firstOperand = 0.0;
  String _operator = '';
  bool _shouldResetDisplay = false;
  late TextEditingController _amountController;
  bool _isEditingAmount = false;

  String _notes = '';
  DateTime _selectedDate = DateTime.now();
  Uint8List? _attachedImageBytes;
  String? _attachedImageName;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onKeypadTap(String val) {
    setState(() {
      if (val == 'backspace') {
        if (_amountString.length > 1) {
          _amountString = _amountString.substring(0, _amountString.length - 1);
        } else {
          _amountString = '0';
        }
      } else if (val == '✕') {
        _amountString = '0';
        _firstOperand = 0.0;
        _operator = '';
      } else if (val == '+' || val == '-' || val == '*' || val == '/') {
        _firstOperand = double.tryParse(_amountString) ?? 0.0;
        _operator = val;
        _shouldResetDisplay = true;
      } else if (val == '=') {
        if (_operator.isNotEmpty) {
          double secondOperand = double.tryParse(_amountString) ?? 0.0;
          double result = 0.0;
          if (_operator == '+') result = _firstOperand + secondOperand;
          else if (_operator == '-') result = _firstOperand - secondOperand;
          else if (_operator == '*') result = _firstOperand * secondOperand;
          else if (_operator == '/') result = secondOperand != 0 ? _firstOperand / secondOperand : 0.0;

          _amountString = result.toStringAsFixed(result % 1 == 0 ? 0 : 2);
          _operator = '';
        }
      } else if (val == '.') {
        if (_shouldResetDisplay) {
          _amountString = '0.';
          _shouldResetDisplay = false;
        } else if (!_amountString.contains('.')) {
          _amountString += '.';
        }
      } else {
        // Digit
        if (_amountString == '0' || _shouldResetDisplay) {
          _amountString = val;
          _shouldResetDisplay = false;
        } else {
          _amountString += val;
        }
      }
      // Keep the controller text in sync
      _amountController.text = _amountString;
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountController.text.length),
      );
    });
  }

  Future<void> _showNotesDialog() async {
    final controller = TextEditingController(text: _notes);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Notes'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter transaction notes or details...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _notes = controller.text.trim();
              });
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo (Camera)'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        final image = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200);
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _attachedImageBytes = bytes;
            _attachedImageName = image.name;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open camera or gallery')),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final netDue = widget.currentDue;
    final displayDueText = netDue > 0
        ? '₹${netDue.toStringAsFixed(0)} ${widget.dueLabel}'
        : netDue < 0
            ? '₹${(-netDue).toStringAsFixed(0)} Advance'
            : 'Settled';

    final dueColor = widget.isPayment ? Colors.green[800] : Colors.red[800];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.avatarColor,
              child: Text(
                widget.avatarInitial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.title} ${widget.phone}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayDueText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: dueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [

                    // 2. Large Centered Amount Display (tappable text field)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '₹',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 220,
                              child: TextField(
                                controller: _amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  final cleaned = val.replaceAll(',', '');
                                  setState(() {
                                    _amountString = cleaned.isEmpty ? '0' : cleaned;
                                  });
                                },
                                onTap: () {
                                  // Select all text on tap for quick replacement
                                  _amountController.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: _amountController.text.length,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 160,
                          height: 2.5,
                          color: Colors.green[600],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap amount to type, or use keypad below',
                          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 3. Add Notes Card
                    _buildOptionCard(
                      icon: Icons.description_outlined,
                      title: _notes.isEmpty ? 'Add Notes' : _notes,
                      titleColor: _notes.isEmpty ? Colors.grey[600]! : AppTheme.textDark,
                      trailing: const Icon(Icons.mic, color: Colors.green, size: 22),
                      onTap: _showNotesDialog,
                    ),
                    const SizedBox(height: 12),

                    // 4. Bill Date Card
                    _buildOptionCard(
                      icon: Icons.calendar_today_outlined,
                      title: 'Bill Date',
                      subtitle: _formatDate(_selectedDate),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
                      onTap: _selectDate,
                    ),
                    const SizedBox(height: 12),

                    // 5. Add Bills (Image Picker) Card
                    _buildOptionCard(
                      icon: Icons.camera_alt_outlined,
                      title: _attachedImageName != null ? '📎 $_attachedImageName' : 'Add Bills',
                      titleColor: _attachedImageName != null ? AppTheme.primary : Colors.grey[600]!,
                      trailing: const Icon(Icons.add, color: Colors.green, size: 22),
                      onTap: _pickImage,
                    ),
                  ],
                ),
              ),
            ),

            // Confirm Button and Keypad Panel
            Column(
              children: [
                // Confirm Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final val = double.tryParse(_amountString) ?? 0.0;
                        if (val <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount', style: TextStyle(fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        widget.onConfirm(val, _notes, _selectedDate, _attachedImageBytes, _attachedImageName);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text(
                        'Confirm',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),

                // Numerical Keypad
                Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildKeypadButton('1'),
                          _buildKeypadButton('2'),
                          _buildKeypadButton('3'),
                          _buildKeypadButton('backspace', color: const Color(0xFFFDE8E8), child: const Icon(Icons.backspace_outlined, color: Colors.red, size: 20)),
                        ],
                      ),
                      Row(
                        children: [
                          _buildKeypadButton('4'),
                          _buildKeypadButton('5'),
                          _buildKeypadButton('6'),
                          _buildKeypadButton('✕', child: const Icon(Icons.close, color: Colors.grey, size: 20)),
                        ],
                      ),
                      Row(
                        children: [
                          _buildKeypadButton('7'),
                          _buildKeypadButton('8'),
                          _buildKeypadButton('9'),
                          _buildKeypadButton('-', child: const Text('－', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark))),
                        ],
                      ),
                      Row(
                        children: [
                          _buildKeypadButton('.'),
                          _buildKeypadButton('0'),
                          _buildKeypadButton('=', color: Colors.green[600], child: const Text('＝', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                          _buildKeypadButton('+', child: const Text('＋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textMid, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: subtitle == null
                  ? Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? AppTheme.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ],
                    ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String key, {Color? color, Widget? child}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: InkWell(
          onTap: () => _onKeypadTap(key),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: color ?? Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: color == null
                  ? [
                      const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 1,
                        offset: Offset(0, 1),
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: child ??
                Text(
                  key,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
