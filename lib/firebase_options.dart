// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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

  // Use web config for all platforms
  static const FirebaseOptions current = web;
}
