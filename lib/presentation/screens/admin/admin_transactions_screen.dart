// FILE: lib/presentation/screens/admin/admin_transactions_screen.dart
// PURPOSE: Admin Financial Audit & Washer Payout Request Management Screen

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/payment_service.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PaymentService _paymentService = PaymentService();
  bool _isProcessing = false;

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
      appBar: AppBar(
        title: const Text('Financial Audit & Payouts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Payment Logs (5% Fee Split)'),
            Tab(text: 'Washer Payout Requests'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          double totalGrossVolume = 0.0;
          double totalPlatformRevenue = 0.0;
          double totalWasherPayouts = 0.0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final gross = (data['amount'] ?? 0.0).toDouble();
            final fee = (data['platformFee'] ?? (gross * 0.05)).toDouble();
            final share = (data['providerShare'] ?? (gross * 0.95)).toDouble();

            totalGrossVolume += gross;
            totalPlatformRevenue += fee;
            totalWasherPayouts += share;
          }

          return Column(
            children: [
              // Summary Financial Stats Banner
              Container(
                padding: const EdgeInsets.all(14),
                color: AppColors.primary.withOpacity(0.06),
                child: Row(
                  children: [
                    _buildFinancialKPI('5% Platform Revenue', totalPlatformRevenue, Colors.orange, Icons.pie_chart),
                    const SizedBox(width: 8),
                    _buildFinancialKPI('Gross Volume', totalGrossVolume, Colors.blue, Icons.payments),
                    const SizedBox(width: 8),
                    _buildFinancialKPI('Washer 95% Share', totalWasherPayouts, Colors.green, Icons.account_balance_wallet),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentLogsTab(),
                    _buildPayoutRequestsTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFinancialKPI(String label, double amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '₦${NumberFormat('#,###').format(amount.toInt())}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .orderBy('paymentDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('No transactions recorded yet', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final gross = (data['amount'] ?? 0.0).toDouble();
            final fee = (data['platformFee'] ?? (gross * 0.05)).toDouble();
            final net = (data['providerShare'] ?? (gross * 0.95)).toDouble();
            final customerName = data['userName'] ?? 'Customer';
            final serviceName = data['serviceName'] ?? 'Service';
            final method = data['paymentMethod'] ?? 'Paystack';

            final date = data['paymentDate'] is Timestamp
                ? (data['paymentDate'] as Timestamp).toDate()
                : DateTime.now();

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
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$serviceName • $customerName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Method: ${method.toUpperCase()} • Ref: ${data['paymentReference'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d, yyyy • h:mm a').format(date),
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₦${NumberFormat('#,###').format(gross.toInt())}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Fee (5%): ₦${NumberFormat('#,###').format(fee.toInt())}',
                          style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Washer (95%): ₦${NumberFormat('#,###').format(net.toInt())}',
                        style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPayoutRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payout_requests')
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('No payout requests yet', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final docId = docs[index].id;
            final data = docs[index].data() as Map<String, dynamic>;
            final washerName = data['washerName'] ?? 'Washer';
            final amount = (data['amount'] ?? 0.0).toDouble();
            final bankName = data['bankName'] ?? 'Bank';
            final accNum = data['accountNumber'] ?? '0000000000';
            final accName = data['accountName'] ?? washerName;
            final status = data['status'] ?? 'pending';

            final isApproved = status == 'approved';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isApproved ? Colors.green.withOpacity(0.3) : Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        washerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '₦${NumberFormat('#,###').format(amount.toInt())}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.account_balance, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('$bankName • $accNum ($accName)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isApproved ? Colors.green.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isApproved ? '✅ Approved & Transferred' : '⏳ Pending Approval',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isApproved ? Colors.green : Colors.amber[800],
                          ),
                        ),
                      ),
                      if (!isApproved)
                        ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  setState(() => _isProcessing = true);
                                  final res = await _paymentService.approvePayoutRequest(docId);
                                  setState(() => _isProcessing = false);

                                  if (res['success'] == true) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✅ Payout approved and marked transferred!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Approve & Pay', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
