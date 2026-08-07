// FILE: lib/services/web_push_web.dart
import 'dart:html' as html;

void requestWebPushPermission() {
  try {
    if (html.Notification.permission != 'granted') {
      html.Notification.requestPermission();
    }
  } catch (_) {}
}

void triggerNativeWebPushNotification(String title, String message) {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: message);
    }
  } catch (_) {}
}
