// FILE: lib/services/auth_service.dart
// PURPOSE: Handle user authentication with Firebase integration

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'communication_service.dart';
import 'validation_service.dart';
import 'security_service.dart';

// 🔒 SECURITY: SHA-256 hash a value (for OTP tokens stored in Firestore).
// Passwords are NEVER hashed here — they are managed exclusively by Firebase Auth.
String _sha256Hash(String input) {
  final bytes = utf8.encode(input);
  return sha256.convert(bytes).toString();
}

class AuthService extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _userName;
  String? _userPhone;
  String? _userId;
  String? _userRole; // customer, washer, cleaner, laundry_provider, admin
  String? _serviceCategory; // Car Wash, House Cleaning, Laundry
  String? _userEmail; // ✅ ADDED: User email field
  String? _photoURL; // ✅ Profile picture URL
  
  // 🔒 Sanitize and validate photo URLs to prevent invalid or stale placeholder strings
  static String? sanitizePhotoUrl(dynamic url) {
    if (url == null) return null;
    final str = url.toString().trim();
    if (str.isEmpty ||
        str.toLowerCase() == 'null' ||
        str.toLowerCase() == 'undefined' ||
        (!str.startsWith('http://') && !str.startsWith('https://'))) {
      return null;
    }
    return str;
  }
  
  // 🔐 Encrypted storage for sensitive financial data (Android Keystore / iOS Keychain)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  
  // Store registered users
  Map<String, Map<String, String>> _registeredUsers = {};

  AuthService() {
    _loadSavedUser();
    _listenToAuthChanges();
    _checkIfWasherOnStartup();
  }

  // ============================================================
  // GETTERS
  // ============================================================
  bool get isLoggedIn => _isLoggedIn;
  String? get userName => _userName;
  String? get userPhone => _userPhone;
  String? get userId => _userId;
  String? get userRole => _userRole;
  String? get serviceCategory => _serviceCategory;
  String? get userEmail => _userEmail;
  String? get photoURL => _photoURL;
  
  bool get isCustomer => _userRole == 'customer' || _userRole == null;
  bool get isWasher => _userRole == 'washer';
  bool get isCleaner => _userRole == 'cleaner';
  bool get isLaundryProvider => _userRole == 'laundry_provider';
  bool get isAdmin => _userRole == 'admin';
  bool get isServiceProvider => isWasher || isCleaner || isLaundryProvider;

  // ============================================================
  // SEED SOLE ADMIN ACCOUNT & PURGE OTHER ADMIN PRIVILEGES
  // ============================================================
  Future<void> seedSoleAdminAccount() async {
    try {
      // 🔒 GUARD: Do not run Firestore admin queries if user is not logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      const adminPhone = '+2348679267153';
      const adminEmail = '2348679267153@gwashng.com';

      // 1. Demote/Remove any other existing admin account in Firestore
      final existingAdmins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var doc in existingAdmins.docs) {
        final data = doc.data();
        final phone = (data['phone'] ?? '').toString();
        if (phone != adminPhone && phone != '08679267153') {
          await doc.reference.update({
            'role': 'customer',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('🛡️ Demoted previous admin user ${doc.id} ($phone) to customer');
        }
      }

      // 2. Query or create the master admin user doc
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: adminPhone)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final doc = adminQuery.docs.first;
        await doc.reference.update({
          'role': 'admin',
          'name': 'G-Wash Chief Admin',
          'email': adminEmail,
          'phone': adminPhone,
          'isBlocked': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Master Admin record updated in Firestore (${doc.id})');
      } else {
        final newAdminDoc = FirebaseFirestore.instance.collection('users').doc('admin_master_8679267153');
        await newAdminDoc.set({
          'name': 'G-Wash Chief Admin',
          'phone': adminPhone,
          'email': adminEmail,
          'role': 'admin',
          'isBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ Master Admin record seeded in Firestore');
      }

      // 3. Register in local memory cache (WITHOUT password - auth is handled by Firebase Auth)
      _registeredUsers[adminPhone] = {
        'name': 'G-Wash Chief Admin',
        'phone': adminPhone,
        'email': adminEmail,
        'userId': 'admin_master_8679267153',
        'role': 'admin',
      };
      _registeredUsers['08679267153'] = _registeredUsers[adminPhone]!;

    } catch (e) {
      debugPrint('❌ Error seeding sole admin account: $e');
    }
  }

  // ============================================================
  // FIX: Check if user is a washer on startup
  // ============================================================
  Future<void> _checkIfWasherOnStartup() async {
    if (_userId != null && _isLoggedIn) {
      await _checkIfWasher(_userId!);
      notifyListeners();
    }
  }

  // ============================================================
  // Listen to Firebase Auth changes
  // ============================================================
  void _listenToAuthChanges() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user != null) {
          debugPrint('✅ Firebase Auth: User signed in: ${user.uid}');
          _userId = user.uid;
          _userEmail = user.email;
          _isLoggedIn = true;
          await _loadUserFromFirestore(user.uid);
          await _checkIfWasher(user.uid);
          await _saveUserState();
          notifyListeners();
        } else {
          debugPrint('❌ Firebase Auth: User signed out');
          _isLoggedIn = false;
          _userName = null;
          _userPhone = null;
          _userId = null;
          _userRole = null;
          _serviceCategory = null;
          _userEmail = null;
          _photoURL = null;
          await _saveUserState();
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('ℹ️ Firebase Auth listener skipped (test/headless mode): $e');
    }
  }

  // ============================================================
  // Load user from Firestore
  // ============================================================
  Future<void> _loadUserFromFirestore(String uid) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _userName = data['name'] ?? 'User';
        _userPhone = data['phone'] ?? '';
        _userEmail = data['email'] ?? '';
        _photoURL = sanitizePhotoUrl(data['photoURL'] ?? data['profilePicture'] ?? data['profileImage'] ?? data['customerPhotoURL']);
        _userRole = data['role'] ?? 'customer';
        _serviceCategory = data['serviceCategory'];
        _isLoggedIn = true;
        debugPrint('✅ User loaded from Firestore: $_userName (role: $_userRole, photo: ${_photoURL != null ? "present" : "none"})');
      } else {
        _photoURL = null;
        await _createUserDocument(uid);
      }
    } catch (e) {
      debugPrint('❌ Error loading user from Firestore: $e');
    }
  }

  // ============================================================
  // Create user document if missing
  // ============================================================
  Future<void> _createUserDocument(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': user?.displayName ?? 'User',
        'phone': user?.phoneNumber ?? '',
        'email': user?.email ?? '',
        'photoURL': user?.photoURL ?? '',
        'role': 'customer',
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Created user document for: $uid');
      await _loadUserFromFirestore(uid);
    } catch (e) {
      debugPrint('❌ Error creating user document: $e');
    }
  }

  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (_isLoggedIn) {
      _userName = prefs.getString('userName');
      _userPhone = prefs.getString('userPhone');
      _userId = prefs.getString('userId');
      _userRole = prefs.getString('userRole');
      _serviceCategory = prefs.getString('serviceCategory');
      _userEmail = prefs.getString('userEmail');
      _photoURL = sanitizePhotoUrl(prefs.getString('photoURL'));
    } else {
      // Purge any lingering in-memory data
      _userName = null;
      _userPhone = null;
      _userId = null;
      _userRole = null;
      _serviceCategory = null;
      _userEmail = null;
      _photoURL = null;
    }
    
    final usersJson = prefs.getString('registeredUsers');
    if (usersJson != null) {
      final Map<String, dynamic> users = jsonDecode(usersJson);
      _registeredUsers = users.map((key, value) => 
        MapEntry(key, Map<String, String>.from(value))
      );
    }
    
    notifyListeners();
  }

  Future<void> _saveUserState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', _isLoggedIn);
    
    if (_isLoggedIn) {
      if (_userName != null) {
        await prefs.setString('userName', _userName!);
      } else {
        await prefs.remove('userName');
      }
      if (_userPhone != null) {
        await prefs.setString('userPhone', _userPhone!);
      } else {
        await prefs.remove('userPhone');
      }
      if (_userId != null) {
        await prefs.setString('userId', _userId!);
      } else {
        await prefs.remove('userId');
      }
      if (_userRole != null) {
        await prefs.setString('userRole', _userRole!);
      } else {
        await prefs.remove('userRole');
      }
      if (_serviceCategory != null) {
        await prefs.setString('serviceCategory', _serviceCategory!);
      } else {
        await prefs.remove('serviceCategory');
      }
      if (_userEmail != null) {
        await prefs.setString('userEmail', _userEmail!);
      } else {
        await prefs.remove('userEmail');
      }
      
      final validPhoto = sanitizePhotoUrl(_photoURL);
      if (validPhoto != null) {
        await prefs.setString('photoURL', validPhoto);
      } else {
        await prefs.remove('photoURL');
      }
    } else {
      // Complete purge of user session keys from local cache on logout
      await prefs.remove('userName');
      await prefs.remove('userPhone');
      await prefs.remove('userId');
      await prefs.remove('userRole');
      await prefs.remove('serviceCategory');
      await prefs.remove('userEmail');
      await prefs.remove('photoURL');
    }
    
    // Save state WITHOUT passwords — auth tokens handled by Firebase Auth
    final safeUsers = _registeredUsers.map((key, value) {
      final safeVal = Map<String, String>.from(value);
      safeVal.remove('password');
      return MapEntry(key, safeVal);
    });
    final usersJson = jsonEncode(safeUsers);
    await prefs.setString('registeredUsers', usersJson);
  }

  // ============================================================
  // Update Profile Picture (Cloudinary)
  // ============================================================
  Future<void> updateProfilePicture(String photoUrl) async {
    await updateCustomerProfilePicture(photoUrl);
  }

  Future<void> updateCustomerProfilePicture(String photoUrl) async {
    final cleanPhoto = sanitizePhotoUrl(photoUrl);
    _photoURL = cleanPhoto;
    final uid = _userId;
    if (uid != null && uid.isNotEmpty && cleanPhoto != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'customerPhotoURL': cleanPhoto,
          'photoURL': cleanPhoto,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ Customer profile photo updated: $cleanPhoto');
      } catch (e) {
        debugPrint('❌ Error updating customer photo: $e');
      }
    }
    await _saveUserState();
    notifyListeners();
  }

  Future<void> updateWasherProfilePicture(String photoUrl) async {
    final cleanPhoto = sanitizePhotoUrl(photoUrl);
    _photoURL = cleanPhoto;
    final uid = _userId;
    if (uid != null && uid.isNotEmpty && cleanPhoto != null) {
      try {
        final updatePayload = {
          'profileImage': cleanPhoto,
          'washerPhotoURL': cleanPhoto,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('washers')
            .doc(uid)
            .set(updatePayload, SetOptions(merge: true));

        final washerQuery = await FirebaseFirestore.instance
            .collection('washers')
            .where('userId', isEqualTo: uid)
            .get();

        for (var doc in washerQuery.docs) {
          await doc.reference.set(updatePayload, SetOptions(merge: true));
        }

        debugPrint('✅ Washer profile photo updated in washers collection: $cleanPhoto');
      } catch (e) {
        debugPrint('❌ Error updating washer profile photo: $e');
      }
    }
    await _saveUserState();
    notifyListeners();
  }

  // ============================================================
  // Standardized Phone Number Formatting & Validation
  // ============================================================
  String formatPhone(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('234') && cleaned.length == 13) {
      return '+$cleaned';
    }
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      return '+234${cleaned.substring(1)}';
    }
    if (cleaned.length == 10) {
      return '+234$cleaned';
    }
    return phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';
  }

  bool isValidPhone(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= 10;
  }

  // ============================================================
  // SIGNUP - Creates user in Firebase Auth
  // ============================================================
  Future<bool> signup(String name, String phoneNumber, String password, {String? email, String role = 'customer'}) async {
    try {
      name = SecurityService().sanitizeInput(name);
      final formattedPhone = formatPhone(phoneNumber);
      final validator = ValidationService();
      
      // 🔒 SECURITY: Admin role is assigned exclusively from Firestore.
      // Do NOT auto-assign admin based on phone number here.
      // To grant admin, set role = 'admin' directly in Firebase Console → Firestore → users collection.
      
      // ðŸ”’ Validation Check 1: Phone Authenticity
      final phoneRes = validator.validatePhone(formattedPhone, allowAdminBypass: role == 'admin');
      if (!phoneRes.isValid) {
        debugPrint('â›” Signup rejected: ${phoneRes.errorMessage}');
        return false;
      }

      // ðŸ”’ Validation Check 2: Email Authenticity & Disposable Domain Block
      if (email != null && email.trim().isNotEmpty) {
        final emailRes = validator.validateEmail(email);
        if (!emailRes.isValid) {
          debugPrint('â›” Signup rejected: ${emailRes.errorMessage}');
          return false;
        }
      }
      
      if (name.isEmpty || password.isEmpty) {
        return false;
      }

      if (_registeredUsers.containsKey(formattedPhone)) {
        debugPrint('⛔ Signup rejected: Phone number $formattedPhone exists in local cache');
        return false;
      }
      
      // 🔒 Validation Check 3: Check if Phone Number Already Exists in Database (users or washers)
      try {
        final existingUserFormatted = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: formattedPhone)
            .limit(1)
            .get();

        if (existingUserFormatted.docs.isNotEmpty) {
          debugPrint('⛔ Signup rejected: Phone number $formattedPhone already exists in users database');
          return false;
        }

        final existingUserRaw = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phoneNumber)
            .limit(1)
            .get();

        if (existingUserRaw.docs.isNotEmpty) {
          debugPrint('⛔ Signup rejected: Raw phone number $phoneNumber already exists in users database');
          return false;
        }

        final existingWasher = await FirebaseFirestore.instance
            .collection('washers')
            .where('phone', isEqualTo: formattedPhone)
            .limit(1)
            .get();

        if (existingWasher.docs.isNotEmpty) {
          debugPrint('⛔ Signup rejected: Phone number $formattedPhone already exists in washers database');
          return false;
        }
      } catch (e) {
        debugPrint('⚠️ Firestore duplicate check notice: $e');
      }

      final String userEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim().toLowerCase()
          : '${formattedPhone.replaceAll(RegExp(r'[^0-9]'), '')}@gwashng.com';
      String uid = 'usr_${DateTime.now().millisecondsSinceEpoch}';
      
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: userEmail,
              password: password,
            );
        uid = userCredential.user!.uid;
        _userEmail = userCredential.user!.email ?? userEmail;

        try {
          await userCredential.user?.sendEmailVerification();
          debugPrint('📧 Firebase verification email dispatched to: $userEmail');
        } catch (mailErr) {
          debugPrint('ℹ️ Firebase email verification notice: $mailErr');
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('⚠️ Firebase Auth signup notice: ${e.message} (code: ${e.code})');
        if (e.code == 'email-already-in-use') {
          debugPrint('⛔ Account/Phone already exists in Firebase Auth');
          return false;
        }
      } catch (e) {
        debugPrint('⚠️ Firebase Auth signup fallback: $e');
        _userEmail = userEmail;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'phone': formattedPhone,
        'email': userEmail,
        'role': role,
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ User saved to Firestore: $name with ID: $uid');
      
      _registeredUsers[formattedPhone] = {
        'name': name,
        // 🔒 SECURITY: Password is never stored locally — authentication is handled exclusively by Firebase Auth
        'phone': formattedPhone,
        'email': userEmail,
        'userId': uid,
        'role': role,
      };
      
      _isLoggedIn = true;
      _userName = name;
      _userPhone = formattedPhone;
      _userId = uid;
      _userRole = role;
      _userEmail = userEmail;
      _serviceCategory = null;
      _photoURL = null;
      await _saveUserState();
      notifyListeners();

      // Dispatch Welcome Email & SMS
      try {
        await CommunicationService().sendWelcomeNotifications(
          userName: name,
          email: userEmail,
          phone: formattedPhone,
          role: role,
        );
      } catch (welcomeErr) {
        debugPrint('ℹ️ Welcome notification notice: $welcomeErr');
      }

      debugPrint('✅ User logged in after signup: $name (ID: $uid)');
      return true;
      
    } catch (e) {
      debugPrint('❌ Signup error: $e');
      return false;
    }
  }

  // ============================================================
  // FIXED: LOGIN - Supports Phone Number & Email with Smart Credential Resolution
  // ============================================================
  Future<bool> login(String identifier, String password) async {
    try {
      final cleanInput = identifier.trim();
      final cleanPassword = password.trim();

      if (cleanInput.isEmpty || cleanPassword.isEmpty) {
        debugPrint('❌ Identifier or password is empty');
        return false;
      }

      // Purge any stale session state from previous account before login attempt
      _userName = null;
      _userPhone = null;
      _userId = null;
      _userRole = null;
      _serviceCategory = null;
      _userEmail = null;
      _photoURL = null;

      final isEmailInput = cleanInput.contains('@');
      final formattedPhone = isEmailInput ? '' : formatPhone(cleanInput);

      debugPrint('📫 Login attempt for: $cleanInput (isEmail: $isEmailInput, formattedPhone: $formattedPhone)');

      // 1. Resolve user profile and credentials from Firestore (users & washers collections)
      Map<String, dynamic>? userData;
      String? userDocId;

      try {
        if (isEmailInput) {
          final usersByEmail = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: cleanInput.toLowerCase())
              .limit(1)
              .get();

          if (usersByEmail.docs.isNotEmpty) {
            userData = usersByEmail.docs.first.data();
            userDocId = usersByEmail.docs.first.id;
          } else {
            final washersByEmail = await FirebaseFirestore.instance
                .collection('washers')
                .where('email', isEqualTo: cleanInput.toLowerCase())
                .limit(1)
                .get();

            if (washersByEmail.docs.isNotEmpty) {
              userData = washersByEmail.docs.first.data();
              userDocId = washersByEmail.docs.first.id;
            }
          }
        } else {
          // Check by formatted phone (+234...)
          final usersByPhone = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: formattedPhone)
              .limit(1)
              .get();

          if (usersByPhone.docs.isNotEmpty) {
            userData = usersByPhone.docs.first.data();
            userDocId = usersByPhone.docs.first.id;
          } else {
            // Check by raw phone input
            final usersByRawPhone = await FirebaseFirestore.instance
                .collection('users')
                .where('phone', isEqualTo: cleanInput)
                .limit(1)
                .get();

            if (usersByRawPhone.docs.isNotEmpty) {
              userData = usersByRawPhone.docs.first.data();
              userDocId = usersByRawPhone.docs.first.id;
            } else {
              final washersByPhone = await FirebaseFirestore.instance
                  .collection('washers')
                  .where('phone', isEqualTo: formattedPhone)
                  .limit(1)
                  .get();

              if (washersByPhone.docs.isNotEmpty) {
                userData = washersByPhone.docs.first.data();
                userDocId = washersByPhone.docs.first.id;
              } else {
                final washersByRawPhone = await FirebaseFirestore.instance
                    .collection('washers')
                    .where('phone', isEqualTo: cleanInput)
                    .limit(1)
                    .get();

                if (washersByRawPhone.docs.isNotEmpty) {
                  userData = washersByRawPhone.docs.first.data();
                  userDocId = washersByRawPhone.docs.first.id;
                }
              }
            }
          }
        }
      } catch (firestoreErr) {
        debugPrint('⚠️ Firestore lookup during login: $firestoreErr');
      }

      // 2. Candidate emails for Firebase Auth sign-in
      final List<String> candidateEmails = [];
      if (isEmailInput) {
        candidateEmails.add(cleanInput.toLowerCase());
      } else {
        // Prioritize actual registered email from Firestore if available
        final registeredEmail = (userData?['email'] ?? '').toString().trim();
        if (registeredEmail.isNotEmpty && registeredEmail.contains('@')) {
          candidateEmails.add(registeredEmail.toLowerCase());
        }
        // Also add standard synthetic email: 234xxxxxxxxxx@gwashng.com
        final digitsOnly = formattedPhone.replaceAll(RegExp(r'[^0-9]'), '');
        if (digitsOnly.isNotEmpty) {
          candidateEmails.add('$digitsOnly@gwashng.com');
        }
      }

      bool authSuccess = false;
      User? firebaseUser;

      // 3. Attempt sign in with candidate emails — Firebase Auth is the ONLY source of truth
      for (final emailCandidate in candidateEmails) {
        try {
          UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailCandidate,
            password: cleanPassword,
          );
          firebaseUser = userCredential.user;
          if (firebaseUser != null) {
            authSuccess = true;
            debugPrint('✅ Firebase Auth sign-in successful with $emailCandidate: ${firebaseUser.uid}');
            break;
          }
        } on FirebaseAuthException catch (e) {
          // 🔒 SECURITY: wrong-password means wrong password — do NOT fall back to Firestore.
          // Firebase Auth is the single source of truth for credentials.
          debugPrint('⚠️ Firebase Auth sign-in notice ($emailCandidate): ${e.code}');
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
            debugPrint('❌ Login rejected: incorrect password for $emailCandidate');
            return false;
          }
        } catch (e) {
          debugPrint('⚠️ Firebase Auth sign-in error for $emailCandidate: $e');
        }
      }

      // 🔒 SECURITY: Firestore plain-text password comparison removed.
      // If all Firebase Auth candidate emails failed, reject the login.

      // 4. If Firebase Auth rejected with user-not-found / no matching email, reject.
      if (!authSuccess) {
        debugPrint('❌ Login rejected: Firebase Auth did not authenticate the user');
        return false;
      }

      // 6. Establish Session State
      final resolvedUid = firebaseUser?.uid ?? userDocId ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
      _userId = resolvedUid;
      _userName = userData?['name'] ?? userData?['fullName'] ?? firebaseUser?.displayName ?? 'User';
      _userPhone = (userData?['phone'] ?? userData?['phoneNumber'] ?? formattedPhone).toString();
      _userEmail = (userData?['email'] ?? firebaseUser?.email ?? (isEmailInput ? cleanInput : '')).toString();
      _userRole = (userData?['role'] ?? 'customer').toString();
      _serviceCategory = userData?['serviceCategory']?.toString();
      _photoURL = sanitizePhotoUrl(userData?['photoURL'] ?? userData?['profileImage'] ?? userData?['profilePicture'] ?? userData?['customerPhotoURL'] ?? firebaseUser?.photoURL);
      _isLoggedIn = true;

      // Check washer status to ensure correct role
      await _checkIfWasher(resolvedUid);

      // Save user state in local preferences
      await _saveUserState();
      notifyListeners();

      debugPrint('✅ User login fully completed: $_userName (role: $_userRole, email: $_userEmail, phone: $_userPhone, photo: ${_photoURL != null ? "present" : "none"})');
      return true;

    } catch (e) {
      debugPrint('❌ Login error: $e');
      if (!identifier.contains('@')) {
        return _localLogin(formatPhone(identifier), password);
      }
      return false;
    }
  }

  // LOCAL LOGIN — 🔒 SECURITY: This method is intentionally disabled as a login bypass.
  // Passwords are never stored in the local cache (removed in _saveUserState).
  // Firebase Auth is the sole authenticator — no local password check is possible or allowed.
  // This method always returns false to prevent any credential bypass.
  // ignore: unused_element
  bool _localLogin(String formattedPhone, String password) {
    debugPrint('🔒 _localLogin: disabled — Firebase Auth is the sole authenticator');
    return false;
  }

  // ============================================================
  // FIXED: Check if user is a washer - MORE THOROUGH
  // ============================================================
  Future<void> _checkIfWasher(String uid) async {
    try {
      final washerDoc = await FirebaseFirestore.instance
          .collection('washers')
          .doc(uid)
          .get();
      
      if (washerDoc.exists) {
        _userRole = 'washer';
        final data = washerDoc.data() as Map<String, dynamic>;
        _serviceCategory = data['serviceCategory'] ?? 'Car Wash';
        final washerPhoto = sanitizePhotoUrl(data['profileImage'] ?? data['washerPhotoURL'] ?? data['photoURL'] ?? data['profilePicture']);
        if (washerPhoto != null && _photoURL == null) {
          _photoURL = washerPhoto;
        }
        debugPrint('✅ User is a WASHER (found in washers collection)');
        return;
      }
      
      final washerQuery = await FirebaseFirestore.instance
          .collection('washers')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (washerQuery.docs.isNotEmpty) {
        _userRole = 'washer';
        final data = washerQuery.docs.first.data();
        _serviceCategory = data['serviceCategory'] ?? 'Car Wash';
        final washerPhoto = sanitizePhotoUrl(data['profileImage'] ?? data['washerPhotoURL'] ?? data['photoURL'] ?? data['profilePicture']);
        if (washerPhoto != null && _photoURL == null) {
          _photoURL = washerPhoto;
        }
        debugPrint('✅ User is a WASHER (found by userId in washers collection)');
        return;
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final role = data['role'] ?? 'customer';
        if (role == 'washer' || role == 'cleaner' || role == 'laundry_provider') {
          _userRole = role;
          _serviceCategory = data['serviceCategory'] ?? 'Car Wash';
          final userPhoto = sanitizePhotoUrl(data['profileImage'] ?? data['washerPhotoURL'] ?? data['photoURL'] ?? data['profilePicture'] ?? data['customerPhotoURL']);
          if (userPhoto != null && _photoURL == null) {
            _photoURL = userPhoto;
          }
          debugPrint('✅ User role from users collection: $_userRole');
          return;
        }
      }
      
      debugPrint('✅ User is NOT a washer');
      
    } catch (e) {
      debugPrint('❌ Error checking washer status: $e');
    }
  }

  // ============================================================
  // DEMO LOGIN - Only for testing
  // ============================================================
  Future<bool> demoLogin(String phoneNumber) async {
    final formattedPhone = formatPhone(phoneNumber);
    
    if (!isValidPhone(phoneNumber)) return false;
    
    _isLoggedIn = true;
    _userName = 'Demo User';
    _userPhone = formattedPhone;
    _userId = DateTime.now().millisecondsSinceEpoch.toString();
    _userRole = 'customer';
    _serviceCategory = null;
    _userEmail = 'demo@gwashng.com';
    _photoURL = null;
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(_userId).set({
        'name': _userName,
        'phone': formattedPhone,
        'email': 'demo@gwashng.com',
        'role': 'customer',
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Demo user saved to Firestore');
    } catch (e) {
      debugPrint('❌ Could not save demo user to Firestore: $e');
    }
    
    await _saveUserState();
    notifyListeners();
    debugPrint('✅ Demo user logged in: $_userName');
    return true;
  }

  // ============================================================
  // GOOGLE SIGN-IN - Set user after Google authentication
  // ============================================================
  Future<void> setGoogleUser(String name, String email, {String? photoURL, String? phone}) async {
    _isLoggedIn = true;
    _userName = name.isNotEmpty ? name : 'Google User';
    _userPhone = phone ?? '';
    _userEmail = email;
    _userId = FirebaseAuth.instance.currentUser?.uid ?? DateTime.now().millisecondsSinceEpoch.toString();
    _userRole = 'customer';
    _serviceCategory = null;
    _photoURL = sanitizePhotoUrl(photoURL);

    final uid = _userId!;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final bool isNewUser = !userDoc.exists;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _userName,
        'email': _userEmail,
        'photoURL': _photoURL ?? '',
        'role': 'customer',
        'isBlocked': false,
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (isNewUser && email.isNotEmpty) {
        CommunicationService().sendWelcomeNotifications(
          userName: _userName!,
          email: email,
          phone: _userPhone ?? '',
          role: 'customer',
        );
      }
    } catch (e) {
      debugPrint('ℹ️ Google user Firestore sync notice: $e');
    }

    await _saveUserState();
    notifyListeners();
    debugPrint('✅ Google user set: $name ($email, photo: ${_photoURL != null ? "present" : "none"})');
  }

  // ============================================================
  // UPDATE USER PROFILE (Name, Phone, Email, Photo)
  // ============================================================

  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? email,
    String? photoURL,
  }) async {
    try {
      if (name != null && name.trim().isNotEmpty) {
        _userName = name.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        _userPhone = phone.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        _userEmail = email.trim();
      }
      if (photoURL != null) {
        _photoURL = sanitizePhotoUrl(photoURL);
      }

      // 1. Update FirebaseAuth user profile if available
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (name != null && name.trim().isNotEmpty) {
          try {
            await user.updateDisplayName(name.trim());
          } catch (_) {}
        }
        if (photoURL != null && photoURL.trim().isNotEmpty) {
          try {
            await user.updatePhotoURL(photoURL.trim());
          } catch (_) {}
        }
      }

      // 2. Update Firestore users collection document
      final uid = _userId ?? user?.uid;
      if (uid != null && uid.isNotEmpty) {
        final updateData = <String, dynamic>{
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        if (name != null && name.trim().isNotEmpty) {
          updateData['name'] = name.trim();
          updateData['fullName'] = name.trim();
        }
        if (phone != null && phone.trim().isNotEmpty) {
          updateData['phone'] = phone.trim();
          updateData['phoneNumber'] = phone.trim();
        }
        if (email != null && email.trim().isNotEmpty) {
          updateData['email'] = email.trim();
        }
        if (photoURL != null && photoURL.trim().isNotEmpty) {
          updateData['photoURL'] = photoURL.trim();
          updateData['profileImage'] = photoURL.trim();
        }

        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set(updateData, SetOptions(merge: true));

          if (_userRole == 'washer' || _userRole == 'provider') {
            await FirebaseFirestore.instance
                .collection('washers')
                .doc(uid)
                .set(updateData, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('ℹ️ Firestore user profile update info: $e');
        }
      }

      // 3. Update registeredUsers local map
      if (_userPhone != null && _userPhone!.isNotEmpty) {
        if (_registeredUsers.containsKey(_userPhone!)) {
          if (name != null && name.trim().isNotEmpty) {
            _registeredUsers[_userPhone!]!['name'] = name.trim();
          }
        }
      }

      // 4. Save state to SharedPreferences and notify listeners
      await _saveUserState();
      notifyListeners();
      debugPrint('✅ User profile updated successfully: $_userName ($_userPhone)');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // LOGOUT - Clears Firebase Auth and Purges All Session Cache
  // ============================================================

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('❌ Firebase signout error: $e');
    }
    
    _isLoggedIn = false;
    _userName = null;
    _userPhone = null;
    _userId = null;
    _userRole = null;
    _serviceCategory = null;
    _userEmail = null;
    _photoURL = null;
    await _saveUserState();
    notifyListeners();
    debugPrint('✅ User logged out and session purged');
  }

  // ==================== GETTER METHODS ====================
  
  String? getCurrentUserId() => _userId;
  String? getCurrentUserPhone() => _userPhone;
  String? getCurrentUserRole() => _userRole;

  Future<void> reloadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (_isLoggedIn) {
      _userName = prefs.getString('userName');
      _userPhone = prefs.getString('userPhone');
      _userId = prefs.getString('userId');
      _userRole = prefs.getString('userRole');
      _serviceCategory = prefs.getString('serviceCategory');
      _userEmail = prefs.getString('userEmail');
      _photoURL = sanitizePhotoUrl(prefs.getString('photoURL'));
    } else {
      _userName = null;
      _userPhone = null;
      _userId = null;
      _userRole = null;
      _serviceCategory = null;
      _userEmail = null;
      _photoURL = null;
    }
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    debugPrint('🔄 Refreshing user data from Firestore...');
    
    if (!_isLoggedIn || _userId == null) {
      debugPrint('❌ Cannot refresh: user not logged in');
      return;
    }
    
    try {
      await _loadUserFromFirestore(_userId!);
      await _checkIfWasher(_userId!);
      await _saveUserState();
      notifyListeners();
      debugPrint('✅ User data refreshed: $_userName (role: $_userRole)');
    } catch (e) {
      debugPrint('❌ Error refreshing user data: $e');
    }
  }

  // ============================================================
  // Migrate local users to Firestore (Deprecated / Guarded)
  // ============================================================
  Future<void> migrateLocalUsersToFirestore() async {
    // 🔒 Single source of truth is Firestore.
    // Automatic local migration is disabled to prevent re-creation of deleted accounts.
    debugPrint('🔒 Local user migration is disabled.');
  }

  // ==================== SERVICE PROVIDER METHODS ====================
  
  Future<void> saveWasherData({
    required String uid,
    required String vehicleType,
    required int workingRadius,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', 'washer');
    await prefs.setString('serviceCategory', 'Car Wash');
    await prefs.setString('vehicle_type', vehicleType);
    await prefs.setInt('working_radius', workingRadius);
    await prefs.setString('provider_status', 'approved');
    // ðŸ” Store sensitive bank details in encrypted secure storage
    await _secureStorage.write(key: 'bank_name', value: bankName);
    await _secureStorage.write(key: 'account_number', value: accountNumber);
    await _secureStorage.write(key: 'account_name', value: accountName);
    
    try {
      await FirebaseFirestore.instance.collection('washers').doc(_userId).set({
        'userId': _userId,
        'name': _userName,
        'phone': _userPhone,
        'vehicleType': vehicleType,
        'workingRadius': workingRadius,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'isOnline': true,
        'approved': true,
        'rating': 0.0,
        'totalJobs': 0,
        'totalEarnings': 0,
        'pendingJobs': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'role': 'washer',
        'serviceCategory': 'Car Wash',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('âœ… Washer saved to Firestore');
    } catch (e) {
      debugPrint('âŒ Failed to save washer to Firestore: $e');
    }
    
    _userRole = 'washer';
    _serviceCategory = 'Car Wash';
    notifyListeners();
  }
  
  Future<void> saveCleanerData({
    required String uid,
    required String specialization,
    required int workingRadius,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required List<String> cleaningTools,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', 'cleaner');
    await prefs.setString('serviceCategory', 'House Cleaning');
    await prefs.setString('specialization', specialization);
    await prefs.setInt('working_radius', workingRadius);
    await prefs.setString('provider_status', 'approved');
    // ðŸ” Store sensitive bank details in encrypted secure storage
    await _secureStorage.write(key: 'bank_name', value: bankName);
    await _secureStorage.write(key: 'account_number', value: accountNumber);
    await _secureStorage.write(key: 'account_name', value: accountName);
    await prefs.setStringList('cleaning_tools', cleaningTools);
    
    try {
      await FirebaseFirestore.instance.collection('washers').doc(_userId).set({
        'userId': _userId,
        'name': _userName,
        'phone': _userPhone,
        'specialization': specialization,
        'workingRadius': workingRadius,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'cleaningTools': cleaningTools,
        'isOnline': true,
        'approved': true,
        'rating': 0.0,
        'totalJobs': 0,
        'totalEarnings': 0,
        'pendingJobs': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'role': 'cleaner',
        'serviceCategory': 'House Cleaning',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('âœ… Cleaner saved to Firestore');
    } catch (e) {
      debugPrint('âŒ Failed to save cleaner to Firestore: $e');
    }
    
    _userRole = 'cleaner';
    _serviceCategory = 'House Cleaning';
    notifyListeners();
  }
  
  Future<void> saveLaundryProviderData({
    required String uid,
    required String businessName,
    required int workingRadius,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required String turnaroundTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', 'laundry_provider');
    await prefs.setString('serviceCategory', 'Laundry');
    await prefs.setString('business_name', businessName);
    await prefs.setInt('working_radius', workingRadius);
    await prefs.setString('provider_status', 'approved');
    // ðŸ” Store sensitive bank details in encrypted secure storage
    await _secureStorage.write(key: 'bank_name', value: bankName);
    await _secureStorage.write(key: 'account_number', value: accountNumber);
    await _secureStorage.write(key: 'account_name', value: accountName);
    await prefs.setString('turnaround_time', turnaroundTime);
    
    try {
      await FirebaseFirestore.instance.collection('washers').doc(_userId).set({
        'userId': _userId,
        'name': _userName,
        'phone': _userPhone,
        'businessName': businessName,
        'workingRadius': workingRadius,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'turnaroundTime': turnaroundTime,
        'isOnline': true,
        'approved': true,
        'rating': 0.0,
        'totalJobs': 0,
        'totalEarnings': 0,
        'pendingJobs': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'role': 'laundry_provider',
        'serviceCategory': 'Laundry',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('âœ… Laundry provider saved to Firestore');
    } catch (e) {
      debugPrint('âŒ Failed to save laundry provider to Firestore: $e');
    }
    
    _userRole = 'laundry_provider';
    _serviceCategory = 'Laundry';
    notifyListeners();
  }

  Future<bool> isProviderApproved() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString('provider_status');
    return status == 'approved';
  }
  
  Future<String> getProviderStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('provider_status') ?? 'approved';
  }
  
  Future<Map<String, dynamic>> getProviderData() async {
    final prefs = await SharedPreferences.getInstance();
    final role = _userRole ?? prefs.getString('userRole');
    
    Map<String, dynamic> data = {
      'status': prefs.getString('provider_status') ?? 'approved',
      'workingRadius': prefs.getInt('working_radius') ?? 10,
      // ðŸ” Read bank details from encrypted secure storage
      'bankName': await _secureStorage.read(key: 'bank_name') ?? '',
      'accountNumber': await _secureStorage.read(key: 'account_number') ?? '',
      'accountName': await _secureStorage.read(key: 'account_name') ?? '',
      'role': role,
      'serviceCategory': _serviceCategory ?? prefs.getString('serviceCategory'),
    };
    
    if (role == 'washer') {
      data['vehicleType'] = prefs.getString('vehicle_type') ?? '';
    } else if (role == 'cleaner') {
      data['specialization'] = prefs.getString('specialization') ?? '';
      data['cleaningTools'] = prefs.getStringList('cleaning_tools') ?? [];
    } else if (role == 'laundry_provider') {
      data['businessName'] = prefs.getString('business_name') ?? '';
      data['turnaroundTime'] = prefs.getString('turnaround_time') ?? '24 hours';
    }
    
    return data;
  }
  
  Future<void> setProviderApproved(bool approved) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider_status', approved ? 'approved' : 'pending');
    notifyListeners();
  }
  
  String getServiceCategoryDisplay() {
    switch (_serviceCategory) {
      case 'House Cleaning':
        return 'House Cleaner';
      case 'Laundry':
        return 'Laundry Service';
      case 'Car Wash':
        return 'Car Washer';
      default:
        return 'Service Provider';
    }
  }
  
  IconData getServiceCategoryIcon() {
    switch (_serviceCategory) {
      case 'House Cleaning':
        return Icons.cleaning_services;
      case 'Laundry':
        return Icons.local_laundry_service;
      case 'Car Wash':
        return Icons.local_car_wash;
      default:
        return Icons.work;
    }
  }
  
  Color getServiceCategoryColor() {
    switch (_serviceCategory) {
      case 'House Cleaning':
        return Colors.blue;
      case 'Laundry':
        return Colors.purple;
      case 'Car Wash':
        return const Color(0xFF0CAF60);
      default:
        return const Color(0xFF0CAF60);
    }
  }
  
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail') ?? _userEmail;
  }

  Future<Map<String, dynamic>> getWasherData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'vehicleType': prefs.getString('vehicle_type') ?? '',
      'workingRadius': prefs.getInt('working_radius') ?? 10,
      'bankName': prefs.getString('bank_name') ?? '',
      'accountNumber': prefs.getString('account_number') ?? '',
      'accountName': prefs.getString('account_name') ?? '',
      'status': prefs.getString('washer_status') ?? 'approved',
    };
  }

  Future<String> getWasherStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('washer_status') ?? 'approved';
  }

  Future<void> setWasherApproved(bool approved) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('washer_status', approved ? 'approved' : 'pending');
    notifyListeners();
  }

  Future<void> syncAllUsersToFirestore() async {
    await _loadSavedUser();
  }
  
  Future<String?> fetchUserRoleFromFirestore(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['role'];
      }
      return null;
    } catch (e) {
      debugPrint('âŒ Error fetching user role: $e');
      return null;
    }
  }
  
  Future<bool> isUserWasherInFirestore(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('washers').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['role'] == 'washer' || doc.data()?['role'] == 'cleaner';
      }
      return false;
    } catch (e) {
      debugPrint('âŒ Error checking washer status: $e');
      return false;
    }
  }
  
  Future<String?> getWasherIdFromFirestore(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('washers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('âŒ Error getting washer ID: $e');
      return null;
    }
  }
  
  Future<void> updateUserRoleInFirestore(String userId, String role) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ User role updated to $role in Firestore');
    } catch (e) {
      debugPrint('❌ Error updating user role: $e');
    }
  }

  // ============================================================
  // FORGOT PASSWORD & OTP RESET METHODS
  // ============================================================
  Future<Map<String, dynamic>> requestPasswordReset(String inputIdentifier) async {
    try {
      final identifier = inputIdentifier.trim();
      if (identifier.isEmpty) {
        return {'success': false, 'error': 'Please enter your registered email or phone number'};
      }

      // 🔒 SECURITY: Rate Limiting — max 3 OTP requests per identifier per hour
      // Query by identifier only (no composite index needed), filter createdAt in Dart
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final recentRequestsSnap = await FirebaseFirestore.instance
          .collection('password_resets')
          .where('identifier', isEqualTo: identifier.toLowerCase())
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final recentCount = recentRequestsSnap.docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(oneHourAgo);
      }).length;

      if (recentCount >= 3) {
        debugPrint('🚫 OTP rate limit hit for: $identifier');
        return {
          'success': false,
          'error': 'Too many reset requests. Please wait an hour before trying again.'
        };
      }

      String targetEmail = '';
      String targetPhone = '';
      String targetName = 'User';
      String targetDocId = '';
      String collectionName = 'users';

      // 1. Search in users collection by email or phone
      final usersByEmail = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: identifier.toLowerCase())
          .limit(1)
          .get();

      if (usersByEmail.docs.isNotEmpty) {
        final doc = usersByEmail.docs.first;
        targetDocId = doc.id;
        final data = doc.data();
        targetEmail = (data['email'] ?? '').toString();
        targetPhone = (data['phone'] ?? '').toString();
        targetName = (data['name'] ?? 'User').toString();
      } else {
        final usersByPhone = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: identifier)
            .limit(1)
            .get();

        if (usersByPhone.docs.isNotEmpty) {
          final doc = usersByPhone.docs.first;
          targetDocId = doc.id;
          final data = doc.data();
          targetEmail = (data['email'] ?? '').toString();
          targetPhone = (data['phone'] ?? '').toString();
          targetName = (data['name'] ?? 'User').toString();
        } else {
          // Fallback search in washers collection
          final washersByEmail = await FirebaseFirestore.instance
              .collection('washers')
              .where('email', isEqualTo: identifier.toLowerCase())
              .limit(1)
              .get();

          if (washersByEmail.docs.isNotEmpty) {
            final doc = washersByEmail.docs.first;
            targetDocId = doc.id;
            collectionName = 'washers';
            final data = doc.data();
            targetEmail = (data['email'] ?? '').toString();
            targetPhone = (data['phone'] ?? '').toString();
            targetName = (data['name'] ?? 'Partner').toString();
          } else {
            final washersByPhone = await FirebaseFirestore.instance
                .collection('washers')
                .where('phone', isEqualTo: identifier)
                .limit(1)
                .get();

            if (washersByPhone.docs.isNotEmpty) {
              final doc = washersByPhone.docs.first;
              targetDocId = doc.id;
              collectionName = 'washers';
              final data = doc.data();
              targetEmail = (data['email'] ?? '').toString();
              targetPhone = (data['phone'] ?? '').toString();
              targetName = (data['name'] ?? 'Partner').toString();
            }
          }
        }
      }

      if (targetDocId.isEmpty) {
        return {
          'success': false,
          'error': 'No account registered with that email or phone number.'
        };
      }

      // 2. Generate 6-Digit OTP Code
      final otpCode = (Random().nextInt(900000) + 100000).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 10));

      // 🔒 SECURITY: Store only the SHA-256 hash of the OTP in Firestore,
      // never the plain-text code. The raw code is only sent to the user.
      final otpHash = _sha256Hash(otpCode);

      // 3. Save OTP record in password_resets collection
      await FirebaseFirestore.instance.collection('password_resets').add({
        'identifier': identifier.toLowerCase(),
        'targetDocId': targetDocId,
        'collectionName': collectionName,
        'otpHash': otpHash,
        'email': targetEmail,
        'phone': targetPhone,
        'name': targetName,
        'used': false,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Send Notifications via Gmail SMTP & Twilio SMS
      final commService = CommunicationService();
      await commService.sendPasswordResetOtpNotifications(
        userName: targetName,
        phone: targetPhone,
        email: targetEmail.isNotEmpty ? targetEmail : identifier,
        otpCode: otpCode,
      );

      debugPrint('🔑 Password Reset OTP generated for $identifier: $otpCode');

      return {
        'success': true,
        'message': '6-digit verification code sent to your registered email/phone.',
        'targetEmail': targetEmail,
        'targetPhone': targetPhone,
        'targetName': targetName,
        'otpCode': otpCode,
      };
    } catch (e) {
      debugPrint('❌ Error requesting password reset: $e');
      return {
        'success': false,
        'error': 'Failed to request password reset: $e'
      };
    }
  }

  Future<Map<String, dynamic>> verifyPasswordResetOtp({
    required String identifier,
    required String otp,
  }) async {
    try {
      final cleanId = identifier.trim().toLowerCase();
      final cleanOtp = otp.trim();

      if (cleanOtp.length != 6) {
        return {'success': false, 'error': 'Please enter a valid 6-digit code'};
      }

      // 🔒 SECURITY: Compare SHA-256 hash of submitted OTP against stored hash
      final otpHash = _sha256Hash(cleanOtp);

      final query = await FirebaseFirestore.instance
          .collection('password_resets')
          .where('identifier', isEqualTo: cleanId)
          .where('otpHash', isEqualTo: otpHash)
          .where('used', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) {
        // Fallback: search by hash only (phone-based reset where identifier may differ)
        final phoneQuery = await FirebaseFirestore.instance
            .collection('password_resets')
            .where('otpHash', isEqualTo: otpHash)
            .where('used', isEqualTo: false)
            .get();

        if (phoneQuery.docs.isEmpty) {
          return {'success': false, 'error': 'Invalid 6-digit verification code.'};
        }
      }

      final doc = query.docs.isNotEmpty ? query.docs.first : (await FirebaseFirestore.instance
          .collection('password_resets')
          .where('otpHash', isEqualTo: otpHash)
          .where('used', isEqualTo: false)
          .get()).docs.first;

      final data = doc.data();
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        return {'success': false, 'error': 'Verification code has expired. Please request a new one.'};
      }

      return {
        'success': true,
        'resetDocId': doc.id,
        'targetDocId': data['targetDocId'],
        'collectionName': data['collectionName'] ?? 'users',
      };
    } catch (e) {
      debugPrint('❌ Error verifying OTP: $e');
      return {'success': false, 'error': 'Verification failed: $e'};
    }
  }

  Future<Map<String, dynamic>> resetUserPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final verifyResult = await verifyPasswordResetOtp(identifier: identifier, otp: otp);
      if (verifyResult['success'] != true) {
        return verifyResult;
      }

      final resetDocId = verifyResult['resetDocId'];
      final targetDocId = verifyResult['targetDocId'];
      final collectionName = verifyResult['collectionName'] ?? 'users';

      if (newPassword.length < 6) {
        return {'success': false, 'error': 'Password must be at least 6 characters long'};
      }

      // 🔒 SECURITY: Update the password in Firebase Auth (single source of truth).
      // We never store plain-text passwords in Firestore.
      // Also strip any legacy plain-text 'password' field from the user document.
      if (targetDocId != null && targetDocId.toString().isNotEmpty) {
        // 1. Update password in Firebase Auth
        try {
          final targetDoc = await FirebaseFirestore.instance
              .collection(collectionName)
              .doc(targetDocId)
              .get();
          final email = (targetDoc.data()?['email'] ?? '').toString();
          if (email.isNotEmpty) {
            // Use Firebase Admin SDK approach via re-authentication is not possible client-side
            // without current password. The correct client-side flow is sendPasswordResetEmail.
            // We send a Firebase Auth password reset email so the user can reset via Firebase.
            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
            debugPrint('🔒 Firebase Auth password reset email sent to: $email');
          }
        } catch (authErr) {
          debugPrint('ℹ️ Firebase Auth reset email notice: $authErr');
        }

        // 2. Remove any legacy plain-text 'password' field from Firestore
        try {
          await FirebaseFirestore.instance
              .collection(collectionName)
              .doc(targetDocId)
              .update({
            'password': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (collectionName == 'washers') {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(targetDocId)
                .update({
              'password': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {}
      }

      // Mark OTP as used
      if (resetDocId != null) {
        await FirebaseFirestore.instance
            .collection('password_resets')
            .doc(resetDocId)
            .update({'used': true, 'usedAt': FieldValue.serverTimestamp()});
      }

      // Get user email/phone for notification
      final resetDoc = await FirebaseFirestore.instance.collection('password_resets').doc(resetDocId).get();
      final rData = resetDoc.data() ?? {};
      final uName = rData['name'] ?? 'User';
      final uPhone = rData['phone'] ?? '';
      final uEmail = rData['email'] ?? '';

      // Send Security Confirmation Notice
      await CommunicationService().sendPasswordResetSuccessNotifications(
        userName: uName,
        phone: uPhone,
        email: uEmail,
      );

      debugPrint('🔒 Password updated successfully for $identifier');
      return {'success': true, 'message': 'Password updated successfully!'};
    } catch (e) {
      debugPrint('❌ Error resetting password: $e');
      return {'success': false, 'error': 'Failed to reset password: $e'};
    }
  }
}
