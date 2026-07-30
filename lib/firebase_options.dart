// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw",
    authDomain: "g-wash-ng.firebaseapp.com",
    projectId: "g-wash-ng",
    storageBucket: "g-wash-ng.appspot.com",
    messagingSenderId: "268073858735",
    appId: "1:268073858735:web:e0d0510cdee83a1506065a",
    measurementId: "G-1YSN7QM6E8",
  );

  static const FirebaseOptions current = web;
}
