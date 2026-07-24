// FILE: notifications_screen.dart
// PURPOSE: Manage notification preferences and view local offline notification inbox

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../services/app_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppNotificationService _notificationService = AppNotificationService();

  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = true; // ✅ Changed to true by default
  bool _promotionalOffers = true;
  bool _orderUpdates = true;
  bool _washerArrival = true;
  bool _deliveryNotifications = true; // ✅ NEW: Delivery/SMS notifications

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notificationService.addListener(_onNotificationChanged);
    
    // ✅ Send a test notification for delivery
    _notificationService.addNotification(
      title: '🚗 Washer On The Way!',
      message: 'Your washer John A. is 5 minutes away with your car wash service.',
      type: 'delivery',
    );
    _notificationService.addNotification(
      title: '📦 Order Delivered!',
      message: 'Your car wash service has been completed successfully. Thank you for using G Wash NG!',
      type: 'delivery',
    );
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onNotificationChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notificationService.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Inbox'),
                  if (_notificationService.unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_notificationService.unreadCount}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInboxTab(notifications),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildInboxTab(List<AppNotificationItem> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'You will receive order and status updates here',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${notifications.length} Messages',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _notificationService.markAllAsRead();
                    },
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _notificationService.clearAll();
                    },
                    icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.red),
                    label: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = notifications[index];
              final formattedTime = DateFormat('MMM d, h:mm a').format(item.timestamp);

              IconData icon = Icons.notifications;
              Color iconColor = AppColors.primary;
              if (item.type == 'booking') {
                icon = Icons.local_car_wash;
                iconColor = Colors.blue;
              } else if (item.type == 'provider') {
                icon = Icons.person_pin_circle;
                iconColor = Colors.green;
              } else if (item.type == 'promo') {
                icon = Icons.local_offer;
                iconColor = Colors.orange;
              } else if (item.type == 'delivery') {
                icon = Icons.delivery_dining;
                iconColor = Colors.purple;
              }

              return Container(
                color: item.isRead ? Colors.white : AppColors.primary.withOpacity(0.04),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.12),
                    child: Icon(icon, color: iconColor),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(item.message, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        formattedTime,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      // ✅ Show SMS indicator for delivery notifications
                      if (item.type == 'delivery')
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sms, size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              const Text(
                                'SMS Sent',
                                style: TextStyle(fontSize: 10, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      item.isRead = true;
                    });
                    _notificationService.markAllAsRead();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      children: [
        const SizedBox(height: 16),
        _buildSwitchTile(
          title: 'Push Notifications',
          subtitle: 'Receive notifications on your device',
          value: _pushNotifications,
          onChanged: (value) {
            setState(() => _pushNotifications = value);
            _saveSettings();
          },
        ),
        _buildSwitchTile(
          title: 'Email Notifications',
          subtitle: 'Receive updates via email',
          value: _emailNotifications,
          onChanged: (value) {
            setState(() => _emailNotifications = value);
            _saveSettings();
          },
        ),
        _buildSwitchTile(
          title: 'SMS Notifications',
          subtitle: 'Receive text message alerts when your washer is on the way',
          value: _smsNotifications,
          onChanged: (value) {
            setState(() => _smsNotifications = value);
            _saveSettings();
          },
        ),
        _buildSwitchTile(
          title: 'Delivery Notifications',
          subtitle: 'Get SMS when your service provider arrives',
          value: _deliveryNotifications,
          onChanged: (value) {
            setState(() => _deliveryNotifications = value);
            _saveSettings();
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Notification Types',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        _buildSwitchTile(
          title: 'Promotional Offers',
          subtitle: 'Get updates on discounts and offers',
          value: _promotionalOffers,
          onChanged: (value) {
            setState(() => _promotionalOffers = value);
            _saveSettings();
          },
        ),
        _buildSwitchTile(
          title: 'Order Updates',
          subtitle: 'Receive order status updates',
          value: _orderUpdates,
          onChanged: (value) {
            setState(() => _orderUpdates = value);
            _saveSettings();
          },
        ),
        _buildSwitchTile(
          title: 'Washer Arrival',
          subtitle: 'Get notified when washer is arriving',
          value: _washerArrival,
          onChanged: (value) {
            setState(() => _washerArrival = value);
            _saveSettings();
          },
        ),
        const SizedBox(height: 30),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _pushNotifications = true;
                _emailNotifications = true;
                _smsNotifications = true;
                _deliveryNotifications = true;
                _promotionalOffers = true;
                _orderUpdates = true;
                _washerArrival = true;
              });
              _saveSettings();
              Helpers.showSnackBar(
                context,
                message: 'Settings reset to default',
                isSuccess: true,
              );
            },
            child: const Text('Reset to Default'),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.grey600, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  void _saveSettings() {
    Helpers.showSnackBar(
      context,
      message: 'Settings saved',
      isSuccess: true,
      duration: const Duration(seconds: 1),
    );
  }
}