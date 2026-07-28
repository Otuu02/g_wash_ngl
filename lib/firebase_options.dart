// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class FirebaseConfig {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDVZmeFAuWz47ovO7AJesNevZ7fdH1Y3Bo",
    authDomain: "g-wash-ng.firebaseapp.com",
    projectId: "g-wash-ng",
    storageBucket: "g-wash-ng.firebasestorage.app",
    messagingSenderId: "268073858735",
    appId: "1:268073858735:web:e0d0510cdee83a1506065a",
    measurementId: "G-1YSN7QM6E8",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDVZmeFAuWz47ovO7AJesNevZ7fdH1Y3Bo",
    authDomain: "g-wash-ng.firebaseapp.com",
    projectId: "g-wash-ng",
    storageBucket: "g-wash-ng.firebasestorage.app",
    messagingSenderId: "268073858735",
    appId: "1:268073858735:android:YOUR_ANDROID_APP_ID_HERE",
    // You need to get Android app ID from Firebase Console
    // Go to: Firebase Console → Project Settings → Your Apps → Android App
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyDVZmeFAuWz47ovO7AJesNevZ7fdH1Y3Bo",
    authDomain: "g-wash-ng.firebaseapp.com",
    projectId: "g-wash-ng",
    storageBucket: "g-wash-ng.firebasestorage.app",
    messagingSenderId: "268073858735",
    appId: "1:268073858735:ios:YOUR_IOS_APP_ID_HERE",
    iosBundleId: "com.gwashng.gwashng",
  );

  static FirebaseOptions get current {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }
}
