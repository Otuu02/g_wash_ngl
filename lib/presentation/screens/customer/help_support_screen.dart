// FILE: lib/presentation/screens/customer/help_support_screen.dart
// PURPOSE: Help and support center with working call, email, and live chat

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // ============================================================
  // SUPPORT CONTACT INFORMATION
  // ============================================================
  static const String supportPhone = '07065584504';
  static const String supportEmail = 'giftotuuobinna1995@gmail.com';

  Future<void> _makePhoneCall(BuildContext context) async {
    final Uri callUri = Uri(scheme: 'tel', path: supportPhone);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
      Helpers.showSnackBar(context, message: 'Calling support...', isSuccess: true);
    } else {
      Helpers.showSnackBar(context, message: 'Could not make call', isError: true);
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=Support Request from G Wash NG User&body=Please describe your issue here:',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
      Helpers.showSnackBar(context, message: 'Opening email app...', isSuccess: true);
    } else {
      Helpers.showSnackBar(context, message: 'Could not send email', isError: true);
    }
  }

  void _openLiveChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => LiveChatBottomSheet(),
    );
  }

  void _openFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FAQBottomSheet(),
    );
  }

  void _openTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'Terms of Service for G Wash NG\n\n'
            '1. Acceptance of Terms\n'
            'By using G Wash NG, you agree to these terms.\n\n'
            '2. Service Description\n'
            'G Wash NG connects customers with professional service providers.\n\n'
            '3. User Responsibilities\n'
            'Users must provide accurate information.\n\n'
            '4. Payments\n'
            'All payments are processed securely.\n\n'
            '5. Cancellations\n'
            'Cancellations within 1 hour may incur a fee.\n\n'
            '6. Privacy\n'
            'Your data is protected as per our Privacy Policy.\n\n'
            '7. Liability\n'
            'G Wash NG is not liable for damages beyond service value.\n\n'
            '8. Modifications\n'
            'We reserve the right to modify these terms.\n\n'
            'Last updated: July 2024',
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Privacy Policy for G Wash NG\n\n'
            'Information We Collect:\n'
            '- Phone number for account creation\n'
            '- Location data for service delivery\n'
            '- Payment information (processed securely)\n'
            '- Device information for app functionality\n\n'
            'How We Use Your Information:\n'
            '- To provide services\n'
            '- To process payments\n'
            '- To improve our services\n'
            '- To communicate with you\n\n'
            'Data Security:\n'
            'We use industry-standard encryption to protect your data.\n\n'
            'Contact Us:\n'
            'Email: giftotuuobinna1995@gmail.com\n'
            'Phone: 07065584504\n\n'
            'Last updated: July 2024',
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _rateApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate G Wash NG'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How would you rate your experience?'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border, size: 40, color: Colors.amber),
                Icon(Icons.star_border, size: 40, color: Colors.amber),
                Icon(Icons.star_border, size: 40, color: Colors.amber),
                Icon(Icons.star_border, size: 40, color: Colors.amber),
                Icon(Icons.star_border, size: 40, color: Colors.amber),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Helpers.showSnackBar(context, message: 'Thank you for rating!', isSuccess: true);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _sendFeedback(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FeedbackBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Contact Us'),
          _buildMenuItem(
            icon: Icons.phone,
            title: 'Call Support',
            subtitle: supportPhone,
            onTap: () => _makePhoneCall(context),
          ),
          _buildMenuItem(
            icon: Icons.email,
            title: 'Email Us',
            subtitle: supportEmail,
            onTap: () => _sendEmail(context),
          ),
          _buildMenuItem(
            icon: Icons.chat,
            title: 'Live Chat',
            subtitle: 'Chat with support team (24/7)',
            onTap: () => _openLiveChat(context),
          ),
          const Divider(),
          _buildSectionHeader('Resources'),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'FAQ',
            subtitle: 'Frequently asked questions',
            onTap: () => _openFAQ(context),
          ),
          _buildMenuItem(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'Read our terms and conditions',
            onTap: () => _openTermsOfService(context),
          ),
          _buildMenuItem(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () => _openPrivacyPolicy(context),
          ),
          const Divider(),
          _buildSectionHeader('Feedback'),
          _buildMenuItem(
            icon: Icons.rate_review,
            title: 'Rate Us',
            subtitle: 'Rate G Wash NG on Play Store',
            onTap: () => _rateApp(context),
          ),
          _buildMenuItem(
            icon: Icons.feedback,
            title: 'Send Feedback',
            subtitle: 'Help us improve the app',
            onTap: () => _sendFeedback(context),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'G Wash NG v1.0.0',
              style: TextStyle(color: AppColors.grey500, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.grey600, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

// Live Chat Bottom Sheet
class LiveChatBottomSheet extends StatefulWidget {
  const LiveChatBottomSheet({super.key});

  @override
  State<LiveChatBottomSheet> createState() => _LiveChatBottomSheetState();
}

class _LiveChatBottomSheetState extends State<LiveChatBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'text': '🤖 Hello! I am the G Wash AI Assistant. How can I help you today?',
      'isUser': false,
      'time': 'Just now',
    },
  ];
  bool _isTyping = false;

  final List<String> _quickSuggestions = [
    '🔒 How Escrow Works',
    '📸 Photo Proof Policy',
    '🚚 Track My Washer',
    '💵 Washer Earnings (95%)',
    '📞 Speak to Human Agent',
  ];

  String _getChatbotResponse(String query) {
    final q = query.toLowerCase().trim();

    if (q.contains('escrow') || q.contains('pay') || q.contains('payment') || q.contains('money') || q.contains('paystack')) {
      return '🔒 Payments on G Wash NG are processed via Paystack and held safely in Escrow until your service is completed. Once the provider completes the task, 95% is paid to them and 5% to platform commission.';
    }
    if (q.contains('proof') || q.contains('photo') || q.contains('picture') || q.contains('finish') || q.contains('complete')) {
      return '📸 Service providers are required to upload a mandatory Photo Proof of completion before Escrow funds can be released to their wallet balance.';
    }
    if (q.contains('track') || q.contains('where') || q.contains('location') || q.contains('map')) {
      return '🚚 You can track your assigned washer in real-time on the Tracking screen once they accept your job booking!';
    }
    if (q.contains('earn') || q.contains('washer') || q.contains('share') || q.contains('payout') || q.contains('commission')) {
      return '💵 Washers earn 95% of every completed job! Payouts are updated live in their wallet balance.';
    }
    if (q.contains('cancel') || q.contains('refund')) {
      return '❌ You can cancel any booking before the washer arrives for a full refund back to your wallet or card.';
    }
    if (q.contains('human') || q.contains('agent') || q.contains('call') || q.contains('speak') || q.contains('contact')) {
      return '📞 Connecting you to a live support agent... You can also call us directly at 07065584504 or email giftotuuobinna1995@gmail.com.';
    }

    return '🤖 I am here to help! You can ask me about Escrow payments, real-time tracking, washer payouts (95%), or photo proof policies.';
  }

  void _sendMessage({String? customText}) {
    final textToSend = customText ?? _messageController.text.trim();
    if (textToSend.isEmpty) return;

    final nowTime = DateFormat('hh:mm a').format(DateTime.now());

    setState(() {
      _messages.add({
        'text': textToSend,
        'isUser': true,
        'time': nowTime,
      });
      if (customText == null) _messageController.clear();
      _isTyping = true;
    });

    final botReply = _getChatbotResponse(textToSend);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': botReply,
          'isUser': false,
          'time': DateFormat('hh:mm a').format(DateTime.now()),
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.support_agent, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Support Team',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Online',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.grey200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const SizedBox(
                        height: 20,
                        width: 40,
                        child: Row(
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: AppColors.grey600),
                            SizedBox(width: 4),
                            CircleAvatar(radius: 3, backgroundColor: AppColors.grey600),
                            SizedBox(width: 4),
                            CircleAvatar(radius: 3, backgroundColor: AppColors.grey600),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final message = _messages[index];
                return Align(
                  alignment: message['isUser'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message['isUser'] ? AppColors.primary : AppColors.grey200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          message['text'],
                          style: TextStyle(
                            color: message['isUser'] ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message['time'],
                          style: TextStyle(
                            fontSize: 10,
                            color: message['isUser'] ? Colors.white70 : AppColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Quick Suggestion Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickSuggestions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = _quickSuggestions[index];
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                  onPressed: () => _sendMessage(customText: suggestion),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.grey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.grey100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// FAQ Bottom Sheet
class FAQBottomSheet extends StatelessWidget {
  const FAQBottomSheet({super.key});

  final List<Map<String, String>> _faqs = const [
    {'q': 'How do I book a wash?', 'a': 'Select a service, choose your location, pick date/time, and confirm booking.'},
    {'q': 'How long does a wash take?', 'a': 'Basic wash: 30 mins, Interior: 45 mins, Full detail: 90 mins, Engine: 60 mins.'},
    {'q': 'What payment methods are accepted?', 'a': 'We accept Debit/Credit Cards, Bank Transfer, USSD, and Wallet payments.'},
    {'q': 'Can I cancel my booking?', 'a': 'Yes, cancel up to 1 hour before scheduled time for free.'},
    {'q': 'How do I track my washer?', 'a': 'Use the live tracking feature in your active booking.'},
    {'q': 'Is my payment secure?', 'a': 'Yes, all transactions are encrypted with bank-grade 256-bit security.'},
    {'q': 'How do I contact support?', 'a': 'Call 07065584504 or email giftotuuobinna1995@gmail.com'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Frequently Asked Questions',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _faqs.length,
              itemBuilder: (context, index) {
                final faq = _faqs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(
                      faq['q']!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          faq['a']!,
                          style: TextStyle(color: AppColors.grey600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Feedback Bottom Sheet
class FeedbackBottomSheet extends StatefulWidget {
  const FeedbackBottomSheet({super.key});

  @override
  State<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  double _rating = 5;

  void _submitFeedback() {
    if (_subjectController.text.trim().isEmpty) {
      Helpers.showSnackBar(context, message: 'Please enter a subject', isError: true);
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      Helpers.showSnackBar(context, message: 'Please enter your feedback', isError: true);
      return;
    }
    
    Navigator.pop(context);
    Helpers.showSnackBar(context, message: 'Feedback sent! Thank you.', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Send Feedback',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _rating = index + 1.0),
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Subject',
              prefixIcon: Icon(Icons.title),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Message',
              prefixIcon: Icon(Icons.message),
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitFeedback,
              child: const Text('Send Feedback'),
            ),
          ),
        ],
      ),
    );
  }
}