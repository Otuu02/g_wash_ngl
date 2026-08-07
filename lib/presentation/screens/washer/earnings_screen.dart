import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/payment_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _selectedPeriod = 0; // 0: Today, 1: Week, 2: Month
  bool _isLoading = false;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController(text: 'GTBank');
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();

  final List<String> _nigerianBanks = const [
    'GTBank',
    'Access Bank',
    'Zenith Bank',
    'First Bank',
    'UBA',
    'Kuda Bank',
    'OPay',
    'PalmPay',
    'Moniepoint',
    'Stanbic IBTC',
    'FCMB',
    'Sterling Bank',
    'Wema Bank',
    'Union Bank',
    'Fidelity Bank',
  ];

  String _selectedBank = 'GTBank';

  void _withdraw(double availableBalance, String washerId, String washerName, Map<String, dynamic> washerData) {
    _amountController.text = availableBalance.toInt().toString();
    
    final savedBank = washerData['bankName'];
    if (savedBank != null && _nigerianBanks.contains(savedBank)) {
      _selectedBank = savedBank;
    }
    _bankNameController.text = _selectedBank;
    
    if ((washerData['accountNumber'] ?? '').toString().isNotEmpty) {
      _accountNumberController.text = washerData['accountNumber'].toString();
    }
    
    if ((washerData['accountName'] ?? '').toString().isNotEmpty) {
      _accountNameController.text = washerData['accountName'].toString();
    } else {
      _accountNameController.text = washerName;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Withdraw Earnings',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Min: ₦10,000', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Available Balance: ₦${NumberFormat('#,###').format(availableBalance)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Withdrawal Amount (₦)',
                    prefixText: '₦ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _nigerianBanks.contains(_selectedBank) ? _selectedBank : _nigerianBanks.first,
                  decoration: const InputDecoration(
                    labelText: 'Select Bank',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  items: _nigerianBanks.map((bank) => DropdownMenuItem(
                    value: bank,
                    child: Text(bank),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        _selectedBank = val;
                        _bankNameController.text = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Account Number (10 digits)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _accountNameController,
                  decoration: const InputDecoration(
                    labelText: 'Account Holder Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final accNum = _accountNumberController.text.trim();
                          final accName = _accountNameController.text.trim();
                          if (accNum.length < 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid 10-digit account number!'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          if (accName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter account holder name!'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          Navigator.pop(context);
                          try {
                            await FirebaseFirestore.instance.collection('washers').doc(washerId).set({
                              'bankName': _selectedBank,
                              'accountNumber': accNum,
                              'accountName': accName,
                              'bankConnected': true,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Bank account details saved successfully!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error saving bank details: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: const Text('Save Bank Details', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final amt = double.tryParse(_amountController.text) ?? 0;
                                if (amt < 1000) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Minimum withdrawal amount is ₦1,000!'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }
                                if (amt > availableBalance && availableBalance > 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Requested amount exceeds available balance!'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }
                                if (_accountNumberController.text.trim().length < 10) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid 10-digit account number!'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }
                                if (_accountNameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('❌ Please enter the account holder name!'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }

                                Navigator.pop(context);
                                setState(() => _isLoading = true);

                                // Save bank details first
                                await FirebaseFirestore.instance.collection('washers').doc(washerId).set({
                                  'bankName': _selectedBank,
                                  'accountNumber': _accountNumberController.text.trim(),
                                  'accountName': _accountNameController.text.trim(),
                                  'bankConnected': true,
                                }, SetOptions(merge: true));

                                final res = await PaymentService().requestWasherPayout(
                                  washerId: washerId,
                                  washerName: washerName,
                                  amount: amt,
                                  bankName: _selectedBank,
                                  accountNumber: _accountNumberController.text.trim(),
                                  accountName: _accountNameController.text.trim(),
                                );

                                setState(() => _isLoading = false);

                                if (res['success'] == true) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('🎉 Withdrawal request submitted! Admin will approve shortly.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('❌ Error: ${res['error']}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Withdraw Payout', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.getCurrentUserId() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Washer Financials & Earnings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('washers')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final washerDocExists = snapshot.hasData && snapshot.data!.exists;
          final washerData = washerDocExists ? (snapshot.data!.data() as Map<String, dynamic>) : {};
          final washerId = userId;
          final washerName = washerData['name'] ?? authService.userName ?? 'Washer';

          final double availableBalance = (washerData['availableBalance'] ?? 0.0).toDouble();
          final double totalEarnings = (washerData['totalEarnings'] ?? 0.0).toDouble();
          final double totalPlatformFees = (washerData['totalPlatformFeesPaid'] ?? 0.0).toDouble();
          final int completedJobs = washerData['completedJobs'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Available Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Available Balance (95% Net Share)',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₦${NumberFormat('#,###').format(availableBalance)}',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () => _withdraw(availableBalance, washerId, washerName, Map<String, dynamic>.from(washerData)),
                          icon: const Icon(
                            Icons.account_balance_wallet,
                            size: 20,
                          ),
                          label: Text(
                            (washerData['accountNumber'] ?? '').toString().isNotEmpty
                                ? 'Withdraw Earnings to Bank'
                                : 'Connect Bank Account & Withdraw',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Connected Bank Account Card (Clickable to Edit/Connect Bank Details)
                InkWell(
                  onTap: () => _withdraw(availableBalance, washerId, washerName, Map<String, dynamic>.from(washerData)),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance, color: Colors.blue, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Connected Bank Account',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                                  ),
                                  const SizedBox(width: 6),
                                  if (washerData['bankConnected'] == true || (washerData['accountNumber'] ?? '').toString().isNotEmpty)
                                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (washerData['accountNumber'] ?? '').toString().isNotEmpty
                                    ? '${washerData['bankName'] ?? 'Bank'} • ${washerData['accountNumber']} (${washerData['accountName'] ?? washerName})'
                                    : 'No bank account connected yet. Tap to connect!',
                                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_note, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Financial Breakdown Stats (Net Share vs 5% Commission)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.savings, color: Colors.green, size: 18),
                                SizedBox(width: 6),
                                Text('Net Earned (95%)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₦${NumberFormat('#,###').format(totalEarnings)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.pie_chart, color: Colors.orange, size: 18),
                                SizedBox(width: 6),
                                Text('5% Platform Fee', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₦${NumberFormat('#,###').format(totalPlatformFees)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

            // Period Selector
                // Completed Jobs Counter Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.blue, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Completed Service Jobs',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        '$completedJobs Jobs',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Recent Washer Earnings Transactions
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Washer Earnings (95% Share)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('washer_transactions')
                      .where('washerId', isEqualTo: washerId)
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, txnSnapshot) {
                    if (txnSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final txns = txnSnapshot.data?.docs ?? [];
                    if (txns.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No earning transactions logged yet',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: txns.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final txn = txns[index].data() as Map<String, dynamic>;
                        final gross = (txn['grossAmount'] ?? 0.0).toDouble();
                        final net = (txn['netEarnings'] ?? 0.0).toDouble();
                        final fee = (txn['platformFee'] ?? 0.0).toDouble();
                        final service = txn['serviceName'] ?? 'Service';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.green.withOpacity(0.12),
                                child: const Icon(Icons.arrow_downward, color: Colors.green, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('Gross: ₦${NumberFormat('#,###').format(gross.toInt())} (5% Fee: ₦${NumberFormat('#,###').format(fee.toInt())})',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Text(
                                '+₦${NumberFormat('#,###').format(net.toInt())}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodButton(String label, int index) {
    final isSelected = _selectedPeriod == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.grey700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: AppColors.grey600, fontSize: 12)),
        ],
      ),
    );
  }
}