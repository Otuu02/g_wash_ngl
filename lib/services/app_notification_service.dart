// FILE: lib/services/app_notification_service.dart
// PURPOSE: Manage System Push Notifications (Android Status Bar), In-App Popups & Persistent Storage

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_push_helper.dart';
import '../core/constants/app_colors.dart';

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type; // 'booking', 'provider', 'promo', 'system'
  bool isRead;
  final String? jobId; // Link to order

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.type = 'system',
    this.isRead = false,
    this.jobId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'type': type,
        'isRead': isRead,
        'jobId': jobId,
      };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) =>
      AppNotificationItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        type: json['type'] ?? 'system',
        isRead: json['isRead'] ?? false,
        jobId: json['jobId'],
      );
}

class AppNotificationService extends ChangeNotifier {
  static final AppNotificationService _instance = AppNotificationService._internal();
  factory AppNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isLocalNotificationsInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  AppNotificationService._internal() {
    loadSavedNotifications();
    requestPushPermission();
    _initLocalNotifications();
    _initFCM();
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('ðŸ”” [Notification Tapped]: ${details.payload}');
        },
      );

      // Create Android High-Priority Channel for Job Requests (Ringtone / Vibrates like Uber)
      final androidPlugin = _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'gwash_job_requests_channel',
            'Incoming Job Requests',
            description: 'High-priority real-time alerts for incoming service requests',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      _isLocalNotificationsInitialized = true;
      debugPrint('ðŸ”” [Local System Push Notifications & High-Priority Channel Initialized]');
    } catch (e) {
      debugPrint('âŒ Error initializing local notifications plugin: $e');
    }
  }

  Future<void> _initFCM() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('â„¹ï¸ FCM init skipped (headless test mode)');
        return;
      }
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('ðŸ”” [FCM Push Permission Granted]');
      }

      _fcmToken = await messaging.getToken();
      debugPrint('ðŸ”‘ [FCM Token Obtained]: $_fcmToken');

      // Listen for FCM token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('ðŸ”„ [FCM Token Refreshed]: $newToken');
      });

      // Foreground Message Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('ðŸ“© [FCM Foreground Message Received]: ${message.notification?.title}');
        final title = message.notification?.title ?? message.data['title'] ?? 'New Request';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        final isJobRequest = message.data['type'] == 'incoming_job';
        
        _triggerNativeSystemPush(
          title, 
          body, 
          isJobRequest: isJobRequest,
          jobId: message.data['jobId'],
        );
        addNotification(
          title: title, 
          message: body, 
          type: isJobRequest ? 'booking' : 'system',
          jobId: message.data['jobId'],
        );
      });
    } catch (e) {
      debugPrint('â„¹ï¸ FCM setup info: $e');
    }
  }

  /// Save or update FCM token in user's or washer's document in Firestore
  Future<void> updateUserFCMToken(String userId, {bool isWasher = false}) async {
    if (_fcmToken == null || _fcmToken!.isEmpty || userId.isEmpty) return;
    try {
      final collection = isWasher ? 'washers' : 'users';
      await FirebaseFirestore.instance.collection(collection).doc(userId).set({
        'fcmToken': _fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('âœ… FCM token saved to $collection/$userId');
    } catch (e) {
      debugPrint('âŒ Error updating FCM token in Firestore: $e');
    }
  }

  void requestPushPermission() {
    if (kIsWeb) {
      requestWebPushPermission();
    }
  }

  Future<void> _triggerNativeSystemPush(
    String title, 
    String message, {
    bool isJobRequest = false,
    String? jobId,
  }) async {
    // 1. Web Push
    if (kIsWeb) {
      triggerNativeWebPushNotification(title, message);
      return;
    }

    // 2. Android / iOS Local System Push Notification in Status Bar
    if (!_isLocalNotificationsInitialized) {
      await _initLocalNotifications();
    }

    try {
      final bigTextStyle = BigTextStyleInformation(
        message,
        htmlFormatBigText: true,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
        summaryText: isJobRequest ? 'âš¡ Instant Request' : 'G-Wash NG Alert',
        htmlFormatSummaryText: true,
      );

      final channelId = isJobRequest ? 'gwash_job_requests_channel' : 'gwash_updates_channel_v2';
      final channelName = isJobRequest ? 'Incoming Job Requests' : 'G-Wash Order & Service Notifications';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Real-time order updates, provider status, and booking alerts',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        styleInformation: bigTextStyle,
        enableVibration: true,
        playSound: true,
        fullScreenIntent: isJobRequest,
        visibility: NotificationVisibility.public,
        category: isJobRequest ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = (DateTime.now().millisecondsSinceEpoch % 100000);
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        message,
        notificationDetails,
      );
      debugPrint('ðŸ“² [System Push Notification Shown in Status Bar]: $title');
    } catch (e) {
      debugPrint('âŒ Error showing native system push notification: $e');
    }
  }

  String _activeUserId = '';
  List<AppNotificationItem> _notifications = [];

  void setActiveUser(String userId) {
    if (_activeUserId != userId) {
      _activeUserId = userId;
      loadSavedNotifications();
    }
  }

  String get _storageKey => _activeUserId.isNotEmpty
      ? 'local_app_notifications_$_activeUserId'
      : 'local_app_notifications';

  List<AppNotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _notifications = list.map((item) => AppNotificationItem.fromJson(item)).toList();
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('âŒ Error loading local notifications: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonStr = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('âŒ Error saving local notifications: $e');
    }
  }

  // ============================================================
  // ADD NOTIFICATION
  // ============================================================
  void addNotification({
    required String title,
    required String message,
    required String type,
    String? jobId,
  }) {
    final newItem = AppNotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      jobId: jobId,
    );
    
    _notifications.insert(0, newItem);
    _saveToStorage();
    _triggerNativeSystemPush(title, message);
    notifyListeners();
  }

  // ============================================================
  // SHOW NOTIFICATION WITH OVERLAY & NATIVE SYSTEM PUSH
  // ============================================================
  Future<void> notify({
    BuildContext? context,
    required String title,
    required String message,
    String type = 'system',
    IconData icon = Icons.notifications_active,
    Color backgroundColor = AppColors.primary,
    String? jobId,
    Duration displayDuration = const Duration(milliseconds: 4000),
  }) async {
    // Add to persistent storage
    final newItem = AppNotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      jobId: jobId,
    );

    _notifications.insert(0, newItem);
    await _saveToStorage();
    
    // Trigger native OS status bar push notification
    await _triggerNativeSystemPush(title, message);
    
    notifyListeners();

    // Show overlay banner if context available
    if (context != null && context.mounted) {
      showTopOverlayBanner(
        context,
        title: title,
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        duration: displayDuration,
      );
    }

    debugPrint('ðŸ“¢ NOTIFICATION: $title - $message');
  }

  // ============================================================
  // GET NOTIFICATIONS BY JOB ID
  // ============================================================
  List<AppNotificationItem> getNotificationsByJobId(String jobId) {
    return _notifications.where((n) => n.jobId == jobId).toList();
  }

  // ============================================================
  // CLEAR NOTIFICATIONS FOR A JOB
  // ============================================================
  void clearNotificationsForJob(String jobId) {
    _notifications.removeWhere((n) => n.jobId == jobId);
    _saveToStorage();
    notifyListeners();
  }

  // ============================================================
  // MARK ALL AS READ
  // ============================================================
  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    await _saveToStorage();
    notifyListeners();
  }

  // ============================================================
  // MARK SINGLE AS READ
  // ============================================================
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      await _saveToStorage();
      notifyListeners();
    }
  }

  // ============================================================
  // CLEAR ALL NOTIFICATIONS
  // ============================================================
  Future<void> clearAll() async {
    _notifications.clear();
    await _saveToStorage();
    notifyListeners();
  }

  // ============================================================
  // SHOW OVERLAY BANNER WITH FLEXIBLE DURATION
  // ============================================================
  static void showTopOverlayBanner(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active,
    Color backgroundColor = AppColors.primary,
    Duration duration = const Duration(milliseconds: 4000),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopBannerWidget(
        title: title,
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        duration: duration,
        onDismissed: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

// ============================================================
// TOP BANNER WIDGET
// ============================================================
class _TopBannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Duration duration;
  final VoidCallback onDismissed;

  const _TopBannerWidget({
    required this.title,
    required this.message,
    required this.icon,
    required this.backgroundColor,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_TopBannerWidget> createState() => _TopBannerWidgetState();
}

class _TopBannerWidgetState extends State<_TopBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Positioned(
      top: mediaQuery.padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _dismiss,
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < -5) _dismiss();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.close, color: Colors.white.withOpacity(0.7), size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}