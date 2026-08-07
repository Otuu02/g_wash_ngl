import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  static const String _storageKey = 'saved_customer_payment_methods';
  List<Map<String, dynamic>> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> rawList = jsonDecode(jsonStr);
        final filteredList = rawList
            .map((item) => Map<String, dynamic>.from(item))
            .where((card) => card['last4'] != '4242' && card['last4'] != '8888')
            .toList();
        
        setState(() {
          _paymentMethods = filteredList;
        });
        await prefs.setString(_storageKey, jsonEncode(filteredList));
      } else {
        setState(() {
          _paymentMethods = [];
        });
      }
    } catch (e) {
      debugPrint('ℹ️ Error loading saved cards: $e');
    }
  }

  Future<void> _saveCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(_paymentMethods);
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('ℹ️ Error saving cards: $e');
    }
  }

  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddCardBottomSheet(onAdd: _addCard),
    );
  }

  void _addCard(Map<String, dynamic> card) {
    setState(() {
      final bool isFirstCard = _paymentMethods.isEmpty;
      _paymentMethods.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': card['type'],
        'name': card['name'],
        'last4': card['last4'],
        'expiry': card['expiry'],
        'isDefault': isFirstCard,
      });
    });
    _saveCards();
    Helpers.showSnackBar(context, message: 'Card added successfully!', isSuccess: true);
  }

  void _setDefaultPayment(String id) {
    setState(() {
      for (var method in _paymentMethods) {
        method['isDefault'] = method['id'] == id;
      }
    });
    _saveCards();
    Helpers.showSnackBar(context, message: 'Default payment method updated', isSuccess: true);
  }

  void _unsetDefaultPayment(String id) {
    setState(() {
      for (var method in _paymentMethods) {
        if (method['id'] == id) {
          method['isDefault'] = false;
        }
      }
    });
    _saveCards();
    Helpers.showSnackBar(context, message: 'Default status removed', isSuccess: true);
  }

  void _removePayment(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Card'),
        content: const Text('Are you sure you want to remove this card?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _paymentMethods.removeWhere((method) => method['id'] == id);
              });
              _saveCards();
              Navigator.pop(context);
              Helpers.showSnackBar(context, message: 'Card removed', isSuccess: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'Payment Methods',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _addPaymentMethod,
          ),
        ],
      ),
      body: _paymentMethods.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _paymentMethods.length,
              itemBuilder: (context, index) {
                final method = _paymentMethods[index];
                return _buildPaymentCard(method);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off, size: 80, color: AppColors.grey400),
          const SizedBox(height: 16),
          const Text(
            'No payment methods',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first card',
            style: TextStyle(color: AppColors.grey600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _addPaymentMethod,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: const Text('Add Card', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> method) {
    final isDefault = method['isDefault'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? AppColors.primary : AppColors.grey200,
          width: isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _setDefaultPayment(method['id']),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 35,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grey300),
          ),
          child: Center(
            child: Text(
              method['type'] == 'visa' ? 'VISA' : 'MC',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: method['type'] == 'visa' ? Colors.blue : Colors.orange,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              '•••• ${method['last4']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Expires ${method['expiry']}',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: AppColors.primary),
          itemBuilder: (context) => [
            if (!isDefault)
              const PopupMenuItem(
                value: 'default',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                    SizedBox(width: 12),
                    Text('Set as Default'),
                  ],
                ),
              )
            else
              const PopupMenuItem(
                value: 'unset',
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Text('Unset Default'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  SizedBox(width: 12),
                  Text('Remove', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'default') {
              _setDefaultPayment(method['id']);
            } else if (value == 'unset') {
              _unsetDefaultPayment(method['id']);
            } else if (value == 'remove') {
              _removePayment(method['id']);
            }
          },
        ),
      ),
    );
  }
}

// Add Card Bottom Sheet
class AddCardBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const AddCardBottomSheet({super.key, required this.onAdd});

  @override
  State<AddCardBottomSheet> createState() => _AddCardBottomSheetState();
}

class _AddCardBottomSheetState extends State<AddCardBottomSheet> {
  final TextEditingController _cardNumber = TextEditingController();
  final TextEditingController _expiry = TextEditingController();
  final TextEditingController _cvv = TextEditingController();
  final TextEditingController _cardholderName = TextEditingController();
  String _cardType = 'visa';

  void _submit() {
    if (_cardNumber.text.replaceAll(' ', '').length < 15) {
      Helpers.showSnackBar(context, message: 'Enter valid card number', isError: true);
      return;
    }
    if (_expiry.text.length < 5) {
      Helpers.showSnackBar(context, message: 'Enter valid expiry date (MM/YY)', isError: true);
      return;
    }
    if (_cvv.text.length < 3) {
      Helpers.showSnackBar(context, message: 'Enter valid CVV', isError: true);
      return;
    }
    if (_cardholderName.text.isEmpty) {
      Helpers.showSnackBar(context, message: 'Enter cardholder name', isError: true);
      return;
    }

    final last4 = _cardNumber.text.replaceAll(' ', '');
    widget.onAdd({
      'type': _cardType,
      'name': _cardType == 'visa' ? 'VISA' : 'Mastercard',
      'last4': last4.substring(last4.length - 4),
      'expiry': _expiry.text,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Card',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Card Type Selector - Green
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('VISA'),
                  selected: _cardType == 'visa',
                  onSelected: (selected) => setState(() => _cardType = 'visa'),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _cardType == 'visa' ? Colors.white : Colors.black87,
                    fontWeight: _cardType == 'visa' ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Mastercard'),
                  selected: _cardType == 'mastercard',
                  onSelected: (selected) => setState(() => _cardType = 'mastercard'),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _cardType == 'mastercard' ? Colors.white : Colors.black87,
                    fontWeight: _cardType == 'mastercard' ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Card Number - Green Focus
          TextField(
            controller: _cardNumber,
            decoration: const InputDecoration(
              labelText: 'Card Number',
              prefixIcon: Icon(Icons.credit_card, color: AppColors.primary),
              hintText: '1234 5678 9012 3456',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            maxLength: 19,
            onChanged: (value) {
              // Auto-format card number
              final text = value.replaceAll(' ', '');
              if (text.length > 4) {
                final formatted = StringBuffer();
                for (int i = 0; i < text.length; i++) {
                  if (i > 0 && i % 4 == 0) formatted.write(' ');
                  formatted.write(text[i]);
                }
                _cardNumber.value = TextEditingValue(
                  text: formatted.toString(),
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
          ),

          const SizedBox(height: 12),

          // Expiry and CVV - Green Focus
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiry,
                  decoration: const InputDecoration(
                    labelText: 'Expiry (MM/YY)',
                    prefixIcon: Icon(Icons.date_range, color: AppColors.primary),
                    hintText: 'MM/YY',
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (value) {
                    // Auto-format expiry
                    final text = value.replaceAll('/', '');
                    if (text.length >= 2) {
                      final formatted = '${text.substring(0, 2)}/${text.substring(2)}';
                      _expiry.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvv,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    prefixIcon: Icon(Icons.lock, color: AppColors.primary),
                    hintText: '***',
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Cardholder Name - Green Focus
          TextField(
            controller: _cardholderName,
            decoration: const InputDecoration(
              labelText: 'Cardholder Name',
              prefixIcon: Icon(Icons.person, color: AppColors.primary),
              hintText: 'John Doe',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Add Card Button - Green
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Add Card',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}