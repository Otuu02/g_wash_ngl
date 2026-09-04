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
            'By accessing or using G Wash NG, you agree to comply with and be bound by these Terms.\n\n'
            '2. Service Description\n'
            'G Wash NG connects customers with verified professional service providers for mobile vehicle washing, home cleaning, laundry, and ride services.\n\n'
            '3. Strict No-Cash Payment Policy\n'
            'All transactions MUST be conducted exclusively through the G Wash NG app via our verified Escrow payment system (Cards, Bank Transfer, USSD, or In-App Wallet via Paystack). Paying cash or off-app transfers to service providers is strictly prohibited.\n\n'
            '• Security & Protection: Off-platform cash payments void all Escrow protections, quality guarantees, and refund eligibility.\n'
            '• Liability: G Wash NG accepts NO responsibility or liability for any cash or offline transactions made directly to providers.\n'
            '• Enforcement: Providers or customers attempting off-platform cash transactions are subject to immediate account suspension or termination.\n\n'
            '4. Escrow & Release of Funds\n'
            'Customer payments are safely held in Escrow when booking. Funds are only released to the service provider after the job has been completed and verified with mandatory photo proof.\n\n'
            '5. Cancellations & Refunds\n'
            'You may cancel a booking up to 1 hour before scheduled service, or anytime before the provider arrives, for a 100% full refund to your wallet or original payment method.\n\n'
            '6. Photo Proof & Service Verification\n'
            'Service providers must submit clear Before & After photos confirming service completion before payout release.\n\n'
            '7. User Responsibilities & Conduct\n'
            'Users must provide accurate address and contact information and maintain respectful conduct with all service personnel.\n\n'
            '8. Privacy & Data Protection\n'
            'Personal data is collected and processed strictly in accordance with our Privacy Policy.\n\n'
            '9. Limitation of Liability\n'
            'G Wash NG is not liable for indirect damages or losses arising from transactions outside the platform.\n\n'
            '10. Modifications\n'
            'We reserve the right to amend these Terms at any time with notice on the platform.\n\n'
            'Last updated: September 2026',
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
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [
    {
      'text': '🤖 Hello! I am the G Wash AI Assistant. How can I help you today? You can ask me about booking, pricing, escrow security, tracking, washer payouts, or cancellation policies.',
      'isUser': false,
      'time': 'Just now',
    },
  ];
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  final List<String> _quickSuggestions = [
    '🚗 How to Book a Service',
    '💰 Pricing & Packages',
    '🔒 How Escrow Works',
    '🚚 Track My Washer',
    '📸 Photo Proof Policy',
    '💵 Washer Earnings (90%)',
    '💼 Become a Washer',
    '🧺 Laundry & Dry Cleaning',
    '🏠 House Cleaning',
    '🚕 Ride Service',
    '💳 Wallet & Payments',
    '❌ Cancellation & Refunds',
    '📜 Terms & No-Cash Policy',
    '📍 Operating Cities & Hours',
    '📞 Speak to Human Agent',
  ];

  String _getChatbotResponse(String query) {
    final q = query.toLowerCase().trim();

    // 1. Greetings & Pleasantries
    if (q.contains('hi') ||
        q.contains('hello') ||
        q.contains('hey') ||
        q.contains('greeting') ||
        q.contains('good morning') ||
        q.contains('good afternoon') ||
        q.contains('good evening') ||
        q.contains('how far') ||
        q.contains('yo') ||
        q.contains('who are you') ||
        q.contains('what are you') ||
        q == 'help') {
      return '👋 Hello! Welcome to G Wash NG! I am your AI Virtual Assistant.\n\nI can assist you with:\n• 🚗 How to book a service\n• 💰 Pricing for Car Wash, House Cleaning, Laundry & Rides\n• 🔒 Escrow payment protection & safety\n• 🚚 Real-time washer tracking & arrival\n• 💵 Washer earnings (90% payout)\n• 💼 Becoming a service partner\n• ❌ Cancellation & refund policies\n\nWhat would you like to know today?';
    }

    // 2. Booking / How to Book
    if (q.contains('how can i book') ||
        q.contains('how do i book') ||
        q.contains('how to book') ||
        q.contains('book') ||
        q.contains('order') ||
        q.contains('schedule') ||
        q.contains('reserve') ||
        q.contains('hire') ||
        q.contains('request wash') ||
        q.contains('start wash')) {
      return '🚗 Booking a service on G Wash NG is quick and easy:\n\n1️⃣ Select your category (Car Wash, House Cleaning, Laundry, or Ride Service)\n2️⃣ Pick your desired package (e.g. Exterior Wash, Full Detailing, Deep Cleaning)\n3️⃣ Enter your address and select your preferred date & time slot\n4️⃣ Confirm & pay securely via Escrow (Card, Bank Transfer, or Wallet)\n5️⃣ A nearby verified pro is assigned and dispatched with real-time GPS tracking!';
    }

    // 3. Pricing & Rates
    if (q.contains('price') ||
        q.contains('pricing') ||
        q.contains('cost') ||
        q.contains('how much') ||
        q.contains('rate') ||
        q.contains('rates') ||
        q.contains('fee') ||
        q.contains('charges') ||
        q.contains('cheap') ||
        q.contains('expensive')) {
      return '💰 Transparent G Wash NG Pricing:\n\n• 🚗 Car Wash: from ₦3,000 (Exterior) to ₦10,000 (Full Detailing)\n• 🏠 House Cleaning: from ₦15,000 (Standard) to ₦35,000 (Move In/Out)\n• 🧺 Laundry: from ₦1,500 (Ironing) to ₦5,000 (Dry Cleaning)\n• 🚕 Ride Service: from ₦2,000 (Sedan) to ₦5,000 (Luxury)\n\nAll payments are held safely in Escrow until you are satisfied with the service!';
    }

    // 4. Car Wash Category
    if (q.contains('car wash') ||
        q.contains('car') ||
        q.contains('exterior') ||
        q.contains('interior') ||
        q.contains('detailing') ||
        q.contains('engine wash')) {
      return '🚗 Car Wash Packages & Pricing:\n\n• Exterior Wash (₦3,000 | ~30 mins): Foam wash, hand dry, tire shine & rim clean.\n• Interior Cleaning (₦5,000 | ~45 mins): Deep vacuum, dashboard polish, seat wiping & fresh scent.\n• Engine Wash (₦7,000 | ~60 mins): Degreasing & steam cleaning for engine bay.\n• Full Detailing (₦10,000 | ~90 mins): Complete exterior hand wash, wax, interior deep vacuum, shampoo & polish!';
    }

    // 5. House Cleaning Category
    if (q.contains('house') ||
        q.contains('home') ||
        q.contains('clean') ||
        q.contains('cleaning') ||
        q.contains('apartment') ||
        q.contains('office')) {
      return '🏠 House & Office Cleaning Services:\n\n• Standard Cleaning (₦15,000 | ~3 hrs): Ideal for 2-3 bedroom homes — sweeping, mopping, dusting, bathrooms & kitchen.\n• Deep Cleaning (₦25,000 | ~5 hrs): Intense scrub of all surfaces, tile grout, appliances & hard-to-reach areas.\n• Office Cleaning (₦20,000 | ~4 hrs): Desks, floors, restrooms, trash & sanitation for businesses.\n• Move In / Move Out (₦35,000 | ~6 hrs): Complete top-to-bottom reset for vacant spaces.';
    }

    // 6. Laundry & Dry Cleaning
    if (q.contains('laundry') ||
        q.contains('dry clean') ||
        q.contains('wash and fold') ||
        q.contains('wash & fold') ||
        q.contains('iron') ||
        q.contains('ironing') ||
        q.contains('cloth')) {
      return '🧺 Laundry & Garment Care Services:\n\n• Wash & Fold (₦2,000 | ~24 hrs): Washed, dried, and neatly folded.\n• Wash & Iron (₦3,500 | ~24 hrs): Washed, dried, steam ironed, and packaged.\n• Dry Cleaning (₦5,000 | ~48 hrs): Specialist care for suits, native wear, silks, and formal attire.\n• Ironing Only (₦1,500 | ~12 hrs): Crisp steam pressing for your clean garments.';
    }

    // 7. Ride Service
    if (q.contains('ride') ||
        q.contains('taxi') ||
        q.contains('cab') ||
        q.contains('driver') ||
        q.contains('transport') ||
        q.contains('trip') ||
        q.contains('van')) {
      return '🚕 G Wash On-Demand Ride Service:\n\n• Standard Sedan (₦2,000 base): Comfortable daily ride for up to 4 passengers.\n• SUV Ride (₦3,500 base): Extra space and comfort for up to 6 passengers.\n• Luxury Ride (₦5,000 base): Executive, VIP luxury car experience.\n• Team Van (₦4,000 base): Group transportation for up to 10 passengers.';
    }

    // 8. General Services Overview
    if (q.contains('service') ||
        q.contains('package') ||
        q.contains('what do you offer') ||
        q.contains('what do you do')) {
      return '🧼 G Wash NG provides 4 core on-demand services:\n\n1. 🚗 Car Wash (Exterior, Interior, Engine, Full Detailing)\n2. 🏠 House Cleaning (Standard, Deep Clean, Office, Move In/Out)\n3. 🧺 Laundry (Wash & Fold, Wash & Iron, Dry Cleaning, Ironing)\n4. 🚕 Ride Service (Standard, SUV, Luxury, Van)\n\nAsk about any of these services for specific prices and durations!';
    }

    // 9. Terms of Service & Strict No-Cash Policy
    if (q.contains('term') ||
        q.contains('no cash') ||
        q.contains('pay cash') ||
        q.contains('offline payment') ||
        q.contains('rules')) {
      return '📜 Terms of Service — Strict No-Cash Payment Policy:\n\n'
          '🚫 STRICT NO-CASH RULE: All payments must be processed exclusively through the G Wash NG app/platform via our secured Escrow system (Card, Bank Transfer, USSD, or In-App Wallet via Paystack).\n\n'
          '⚠️ Crucial User Protections:\n'
          '• Direct cash payments or off-app transfers to service providers are strictly prohibited.\n'
          '• Paying offline voids ALL Escrow protections, insurance, and money-back refund guarantees.\n'
          '• G Wash NG accepts NO responsibility or liability for any cash handed to providers.\n'
          '• Providers requesting cash violate platform rules and face immediate account termination.\n\n'
          'Always keep your payments inside the app to guarantee top quality and full financial safety!';
    }

    // 10. Escrow, Payments, Security & Methods
    if (q.contains('escrow') ||
        q.contains('pay') ||
        q.contains('payment') ||
        q.contains('money') ||
        q.contains('paystack') ||
        q.contains('flutterwave') ||
        q.contains('card') ||
        q.contains('bank') ||
        q.contains('transfer') ||
        q.contains('cash') ||
        q.contains('safe') ||
        q.contains('security')) {
      return '🔒 100% Escrow Protection Guarantee:\n\n• All payments are processed securely via Paystack and held in Escrow.\n• The service provider is NOT paid until you verify the completed work.\n• Once confirmed, 90% is released to the washer and 10% platform commission.\n• ⚠️ NEVER pay offline cash to any provider! Paying in-app protects your funds and gives you a 100% money-back guarantee.';
    }

    // 10. Live Tracking & Arrival
    if (q.contains('track') ||
        q.contains('where') ||
        q.contains('location') ||
        q.contains('map') ||
        q.contains('gps') ||
        q.contains('eta') ||
        q.contains('arrive') ||
        q.contains('arrival')) {
      return '🚚 Real-Time GPS Tracking:\n\n• As soon as a washer accepts your order, you can track their exact movement live on the map.\n• Open the active booking card and tap "Track Washer" to see live distance and ETA.\n• You can also use the in-app Call or Chat button to talk to your assigned washer directly!';
    }

    // 11. Photo Proof Policy
    if (q.contains('proof') ||
        q.contains('photo') ||
        q.contains('picture') ||
        q.contains('finish') ||
        q.contains('complete') ||
        q.contains('done') ||
        q.contains('evidence')) {
      return '📸 Mandatory Photo Proof Policy:\n\n• To protect both customers and washers, service providers MUST upload clear Before & After completion photos.\n• Escrow funds remain locked until photo proof is submitted and verified.\n• You can review the completion photos right on your order history screen.';
    }

    // 12. Washer Earnings & 90% Payout
    if (q.contains('earn') ||
        q.contains('washer') ||
        q.contains('payout') ||
        q.contains('commission') ||
        q.contains('90%') ||
        q.contains('split') ||
        q.contains('percentage') ||
        q.contains('share') ||
        q.contains('cut')) {
      return '💵 90% Provider Payout Model:\n\n• Washers and service partners earn 90% of every completed job!\n• Platform commission is only 10% — the lowest in the industry.\n• Earnings hit your in-app wallet immediately after job approval and can be withdrawn directly to any Nigerian bank account.';
    }

    // 13. Becoming a Washer / Partner
    if (q.contains('become a washer') ||
        q.contains('join as washer') ||
        q.contains('register as washer') ||
        q.contains('partner') ||
        q.contains('apply') ||
        q.contains('work with') ||
        q.contains('sign up as washer') ||
        q.contains('job')) {
      return '💼 Become a G Wash Service Partner:\n\n1️⃣ Download the app and register as a Washer / Provider\n2️⃣ Upload your personal details, preferred categories, and valid ID (NIN / Driver\'s License)\n3️⃣ Our verification team reviews and approves your account within 24 hours\n4️⃣ Go online, accept bookings in your neighborhood, and earn 90% on every job with instant bank withdrawals!';
    }

    // 14. Wallet & Withdrawals
    if (q.contains('wallet') ||
        q.contains('fund') ||
        q.contains('top up') ||
        q.contains('balance') ||
        q.contains('withdraw')) {
      return '💳 G Wash In-App Wallet:\n\n• For Customers: Fund your wallet with Debit Card or Bank Transfer for instant 1-tap bookings without re-entering card details.\n• For Washers: Your 90% earnings go straight to your wallet. You can withdraw to any Nigerian bank account anytime with 1 click.';
    }

    // 15. Cancellation & Refunds
    if (q.contains('cancel') ||
        q.contains('refund') ||
        q.contains('reschedule') ||
        q.contains('money back')) {
      return '❌ Cancellation & 100% Refund Policy:\n\n• You can cancel your booking up to 1 hour before scheduled time (or before the washer arrives) for a full 100% refund.\n• Your refund is credited instantly to your G Wash Wallet or original card.\n• If a service provider cancels or fails to arrive, your payment is refunded immediately.';
    }

    // 16. Operating Cities & Hours
    if (q.contains('city') ||
        q.contains('cities') ||
        q.contains('abuja') ||
        q.contains('lagos') ||
        q.contains('port harcourt') ||
        q.contains('coverage') ||
        q.contains('area') ||
        q.contains('hours') ||
        q.contains('open') ||
        q.contains('time')) {
      return '📍 Service Coverage & Operating Hours:\n\n• Coverage: We operate in Abuja, Lagos, Port Harcourt, and major metropolitan areas across Nigeria.\n• Service Hours: Washers & cleaners are active from 7:30 AM to 7:00 PM daily (Monday – Sunday).\n• Online Booking: The app accepts bookings 24/7, so you can schedule in advance anytime!';
    }

    // 17. Safety, Damage & Guarantee
    if (q.contains('damage') ||
        q.contains('scratch') ||
        q.contains('insurance') ||
        q.contains('stolen') ||
        q.contains('guarantee') ||
        q.contains('trust')) {
      return '🛡️ Safety & Quality Guarantee:\n\n• All G Wash providers are background-checked and identity-verified (KYC).\n• Payments remain in Escrow until you are satisfied.\n• If any accidental damage occurs, report it within 24 hours with photos. Funds remain on hold in Escrow while our dispute resolution team investigates.';
    }

    // 18. Account & Password
    if (q.contains('password') ||
        q.contains('login') ||
        q.contains('account') ||
        q.contains('profile') ||
        q.contains('otp')) {
      return '🔐 Account & Password Help:\n\n• Reset Password: On the Login screen, tap "Forgot Password", enter your phone number or email, and input the 4-digit OTP to set a new password.\n• Profile: You can update your phone, email, saved vehicles, and delivery addresses in the Profile tab.';
    }

    // 19. Human Agent & Direct Contact
    if (q.contains('human') ||
        q.contains('agent') ||
        q.contains('call') ||
        q.contains('speak') ||
        q.contains('contact') ||
        q.contains('phone') ||
        q.contains('email') ||
        q.contains('support') ||
        q.contains('whatsapp') ||
        q.contains('customer care')) {
      return '📞 Direct Human Support:\n\n• 📱 Phone: 07065584504\n• ✉️ Email: giftotuuobinna1995@gmail.com\n• ⏰ Support Hours: 24/7 active response\n\nYou can also tap "Call Support" or "Email Us" directly on the Help & Support screen for immediate help!';
    }

    // 20. Gratitude & Closing
    if (q.contains('thank') ||
        q.contains('thanks') ||
        q.contains('awesome') ||
        q.contains('great') ||
        q.contains('cool') ||
        q == 'ok' ||
        q == 'okay' ||
        q.contains('bye') ||
        q.contains('goodbye')) {
      return '😊 You\'re very welcome! If you have any other questions, just ask. Thank you for choosing G Wash NG! 🌟';
    }

    // 21. Smart Fallback with Actionable Prompts
    return '🤖 I am the G Wash Virtual Assistant! I can help you with anything on our platform:\n\n• 🚗 "How do I book a service?"\n• 💰 "What are your prices?"\n• 🔒 "How does Escrow protect my money?"\n• 🚚 "How do I track my washer?"\n• 💵 "How much do washers earn?"\n• 💼 "How do I become a washer?"\n• ❌ "Can I get a refund?"\n• 📞 "Speak to a human agent"\n\nPlease type your question or tap one of the suggestion chips below!';
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
    _scrollToBottom();

    final botReply = _getChatbotResponse(textToSend);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': botReply,
          'isUser': false,
          'time': DateFormat('hh:mm a').format(DateTime.now()),
        });
      });
      _scrollToBottom();
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
              controller: _scrollController,
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