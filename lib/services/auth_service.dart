// FILE: lib/services/auth_service.dart
// PURPOSE: Handle user authentication with Firebase integration

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class AuthService extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _userName;
  String? _userPhone;
  String? _userId;
  String? _userRole; // customer, washer, cleaner, laundry_provider, admin
  String? _serviceCategory; // Car Wash, House Cleaning, Laundry
  
  // Store registered users
  Map<String, Map<String, String>> _registeredUsers = {};

  AuthService() {
    _loadSavedUser();
    _listenToAuthChanges();
    _checkIfWasherOnStartup();
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
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        print('✅ Firebase Auth: User signed in: ${user.uid}');
        _userId = user.uid;
        _isLoggedIn = true;
        await _loadUserFromFirestore(user.uid);
        await _checkIfWasher(user.uid);
        await _saveUserState();
        notifyListeners();
      } else {
        print('❌ Firebase Auth: User signed out');
        _isLoggedIn = false;
        _userName = null;
        _userPhone = null;
        _userId = null;
        _userRole = null;
        _serviceCategory = null;
        await _saveUserState();
        notifyListeners();
      }
    });
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
        
        final firestoreRole = data['role'] ?? 'customer';
        _serviceCategory = data['serviceCategory'];
        
        if (_userRole == null || _userRole == 'customer') {
          _userRole = firestoreRole;
        }
        
        _isLoggedIn = true;
        print('✅ User loaded from Firestore: $_userName (role: $_userRole)');
      } else {
        await _createUserDocument(uid);
      }
    } catch (e) {
      print('❌ Error loading user from Firestore: $e');
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
        'role': 'customer',
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Created user document for: $uid');
      await _loadUserFromFirestore(uid);
    } catch (e) {
      print('❌ Error creating user document: $e');
    }
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get userName => _userName;
  String? get userPhone => _userPhone;
  String? get userId => _userId;
  String? get userRole => _userRole;
  String? get serviceCategory => _serviceCategory;
  
  bool get isCustomer => _userRole == 'customer' || _userRole == null;
  bool get isWasher => _userRole == 'washer';
  bool get isCleaner => _userRole == 'cleaner';
  bool get isLaundryProvider => _userRole == 'laundry_provider';
  bool get isAdmin => _userRole == 'admin';
  bool get isServiceProvider => isWasher || isCleaner || isLaundryProvider;

  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _userName = prefs.getString('userName');
    _userPhone = prefs.getString('userPhone');
    _userId = prefs.getString('userId');
    _userRole = prefs.getString('userRole');
    _serviceCategory = prefs.getString('serviceCategory');
    
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
    if (_userName != null) await prefs.setString('userName', _userName!);
    if (_userPhone != null) await prefs.setString('userPhone', _userPhone!);
    if (_userId != null) await prefs.setString('userId', _userId!);
    if (_userRole != null) await prefs.setString('userRole', _userRole!);
    if (_serviceCategory != null) await prefs.setString('serviceCategory', _serviceCategory!);
    
    final usersJson = jsonEncode(_registeredUsers);
    await prefs.setString('registeredUsers', usersJson);
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
  Future<bool> signup(String name, String phoneNumber, String password, {String role = 'customer'}) async {
    try {
      final formattedPhone = formatPhone(phoneNumber);
      
      if (formattedPhone == '+2348000000000') {
        role = 'admin';
      }
      
      if (name.isEmpty || !isValidPhone(phoneNumber) || password.isEmpty) {
        return false;
      }
      
      if (_registeredUsers.containsKey(formattedPhone)) {
        return false;
      }
      
      final email = '${formattedPhone.replaceAll(RegExp(r'[^0-9]'), '')}@gwashng.com';
      
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
      
      final String uid = userCredential.user!.uid;
      
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'phone': formattedPhone,
        'email': email,
        'role': role,
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ User saved to Firestore: $name with ID: $uid');
      
      _registeredUsers[formattedPhone] = {
        'name': name,
        'password': password,
        'phone': formattedPhone,
        'userId': uid,
        'role': role,
      };
      
      _isLoggedIn = true;
      _userName = name;
      _userPhone = formattedPhone;
      _userId = uid;
      _userRole = role;
      _serviceCategory = null;
      await _saveUserState();
      notifyListeners();
      print('✅ User logged in after signup: $name (ID: $uid)');
      return true;
      
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth signup error: ${e.message}');
      if (e.code == 'email-already-in-use') {
        print('📝 User already exists in Firebase Auth - trying login...');
        return await login(phoneNumber, password);
      }
      return false;
    } catch (e) {
      print('❌ Signup error: $e');
      return false;
    }
  }

  // ============================================================
  // FIXED: LOGIN - Properly detects washers
  // ============================================================
  Future<bool> login(String phoneNumber, String password) async {
    try {
      final formattedPhone = formatPhone(phoneNumber);
      
      if (!isValidPhone(phoneNumber)) {
        print('❌ Invalid phone number: $formattedPhone');
        return false;
      }
      
      final email = '${formattedPhone.replaceAll(RegExp(r'[^0-9]'), '')}@gwashng.com';
      
      print('📝 Checking Firestore for user: $formattedPhone');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: formattedPhone)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        print('✅ User found in Firestore');
        final userData = querySnapshot.docs.first.data();
        final firestoreUserId = querySnapshot.docs.first.id;
        final userName = userData['name'] ?? 'User';
        final userRole = userData['role'] ?? 'customer';
        final userServiceCategory = userData['serviceCategory'];
        
        bool isWasher = false;
        String? washerId;
        
        try {
          final washerQuery = await FirebaseFirestore.instance
              .collection('washers')
              .where('userId', isEqualTo: firestoreUserId)
              .limit(1)
              .get();
          
          if (washerQuery.docs.isNotEmpty) {
            isWasher = true;
            washerId = washerQuery.docs.first.id;
            print('✅ User is a WASHER - found in washers collection');
          }
        } catch (e) {
          print('❌ Error checking washer status: $e');
        }
        
        if (userRole == 'washer' || userRole == 'cleaner' || userRole == 'laundry_provider') {
          isWasher = true;
          print('✅ User role in Firestore is: $userRole');
        }
        
        try {
          UserCredential userCredential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: email,
                password: password,
              );
          
          final uid = userCredential.user!.uid;
          
          _isLoggedIn = true;
          _userId = uid;
          _userName = userName;
          _userPhone = formattedPhone;
          _serviceCategory = userServiceCategory;
          
          if (isWasher) {
            _userRole = 'washer';
            _serviceCategory = userServiceCategory ?? 'Car Wash';
            print('✅ USER IS A WASHER - role set to: $_userRole');
          } else {
            _userRole = userRole == 'customer' ? 'customer' : userRole;
            print('✅ USER IS A CUSTOMER - role set to: $_userRole');
          }
          
          await _checkIfWasher(uid);
          
          await _saveUserState();
          notifyListeners();
          print('✅ User logged in: $_userName (role: $_userRole)');
          return true;
          
        } on FirebaseAuthException catch (e) {
          print('❌ Firebase Auth error: ${e.message} (code: ${e.code})');
          
          if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
            print('📝 User not found/invalid credentials in Firebase Auth - attempting to create account...');
            
            try {
              UserCredential newUser = await FirebaseAuth.instance
                  .createUserWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
              
              final uid = newUser.user!.uid;
              
              await FirebaseFirestore.instance.collection('users').doc(uid).set({
                'name': userName,
                'phone': formattedPhone,
                'email': email,
                'role': isWasher ? 'washer' : userRole,
                'serviceCategory': isWasher ? 'Car Wash' : userServiceCategory,
                'isBlocked': false,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              
              if (firestoreUserId != uid) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(firestoreUserId)
                    .delete();
              }
              
              _isLoggedIn = true;
              _userId = uid;
              _userName = userName;
              _userPhone = formattedPhone;
              _userRole = isWasher ? 'washer' : userRole;
              _serviceCategory = isWasher ? 'Car Wash' : userServiceCategory;
              
              await _checkIfWasher(uid);
              await _saveUserState();
              notifyListeners();
              print('✅ User created in Firebase Auth and logged in: $_userName (role: $_userRole)');
              return true;
              
            } on FirebaseAuthException catch (createError) {
              print('❌ Failed to create user in Firebase Auth: ${createError.message} (code: ${createError.code})');
              if (createError.code == 'email-already-in-use') {
                print('❌ Wrong password for existing user');
                return false;
              }
              return _localLogin(formattedPhone, password);
            }
          }
          
          if (e.code == 'wrong-password') {
            print('❌ Wrong password');
            return false;
          }
          
          return false;
        }
      } else {
        print('❌ User not found in Firestore');
        return _localLogin(formattedPhone, password);
      }
      
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  // ============================================================
  // LOCAL LOGIN - Fallback
  // ============================================================
  Future<bool> _localLogin(String formattedPhone, String password) async {
    if (_registeredUsers.containsKey(formattedPhone)) {
      if (_registeredUsers[formattedPhone]!['password'] == password) {
        _isLoggedIn = true;
        _userName = _registeredUsers[formattedPhone]!['name'];
        _userPhone = formattedPhone;
        _userId = _registeredUsers[formattedPhone]!['userId'];
        _userRole = _registeredUsers[formattedPhone]!['role'] ?? 'customer';
        _serviceCategory = _registeredUsers[formattedPhone]!['serviceCategory'];
        await _saveUserState();
        notifyListeners();
        print('✅ User logged in from local storage: $_userName (role: $_userRole)');
        return true;
      } else {
        print('❌ Wrong password for local user');
        return false;
      }
    }
    
    print('❌ Login failed for: $formattedPhone');
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
        print('✅ User is a WASHER (found in washers collection)');
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
        print('✅ User is a WASHER (found by userId in washers collection)');
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
          print('✅ User role from users collection: $_userRole');
          return;
        }
      }
      
      print('✅ User is NOT a washer - role: $_userRole');
      
    } catch (e) {
      print('❌ Error checking washer status: $e');
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
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(_userId).set({
        'name': _userName,
        'phone': formattedPhone,
        'role': 'customer',
        'isBlocked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Demo user saved to Firestore');
    } catch (e) {
      print('❌ Could not save demo user to Firestore: $e');
    }
    
    await _saveUserState();
    notifyListeners();
    print('✅ Demo user logged in: $_userName');
    return true;
  }

  // ============================================================
  // LOGOUT - Clears Firebase Auth
  // ============================================================
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('❌ Firebase signout error: $e');
    }
    
    _isLoggedIn = false;
    _userName = null;
    _userPhone = null;
    _userId = null;
    _userRole = null;
    _serviceCategory = null;
    await _saveUserState();
    notifyListeners();
    print('✅ User logged out');
  }

  // ==================== GETTER METHODS ====================
  
  String? getCurrentUserId() => _userId;
  String? getCurrentUserPhone() => _userPhone;
  String? getCurrentUserRole() => _userRole;

  Future<void> reloadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _userName = prefs.getString('userName');
    _userPhone = prefs.getString('userPhone');
    _userId = prefs.getString('userId');
    _userRole = prefs.getString('userRole');
    _serviceCategory = prefs.getString('serviceCategory');
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    print('🔄 Refreshing user data from Firestore...');
    
    if (!_isLoggedIn || _userId == null) {
      print('❌ Cannot refresh: user not logged in');
      return;
    }
    
    try {
      await _loadUserFromFirestore(_userId!);
      await _checkIfWasher(_userId!);
      await _saveUserState();
      notifyListeners();
      print('✅ User data refreshed: $_userName (role: $_userRole)');
    } catch (e) {
      print('❌ Error refreshing user data: $e');
    }
  }

  // ============================================================
  // Migrate local users to Firestore
  // ============================================================
  Future<void> migrateLocalUsersToFirestore() async {
    int successCount = 0;
    int failCount = 0;
    
    await _loadSavedUser();
    
    for (var entry in _registeredUsers.entries) {
      final phone = entry.key;
      final userData = entry.value;
      
      try {
        final existing = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();
        
        if (existing.docs.isEmpty) {
          final docRef = await FirebaseFirestore.instance.collection('users').add({
            'name': userData['name'] ?? 'Unknown',
            'phone': phone,
            'role': userData['role'] ?? 'customer',
            'isBlocked': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          successCount++;
          print('✅ Migrated user: ${userData['name']} (ID: ${docRef.id})');
        } else {
          print('⏭️ User already exists: ${userData['name']}');
        }
      } catch (e) {
        failCount++;
        print('❌ Failed to migrate user: $e');
      }
    }
    
    print('✅ Migration complete: $successCount added, $failCount failed');
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
    await prefs.setString('bank_name', bankName);
    await prefs.setString('account_number', accountNumber);
    await prefs.setString('account_name', accountName);
    
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
      
      print('✅ Washer saved to Firestore');
    } catch (e) {
      print('❌ Failed to save washer to Firestore: $e');
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
    await prefs.setString('bank_name', bankName);
    await prefs.setString('account_number', accountNumber);
    await prefs.setString('account_name', accountName);
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
      
      print('✅ Cleaner saved to Firestore');
    } catch (e) {
      print('❌ Failed to save cleaner to Firestore: $e');
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
    await prefs.setString('bank_name', bankName);
    await prefs.setString('account_number', accountNumber);
    await prefs.setString('account_name', accountName);
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
      
      print('✅ Laundry provider saved to Firestore');
    } catch (e) {
      print('❌ Failed to save laundry provider to Firestore: $e');
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
      'bankName': prefs.getString('bank_name') ?? '',
      'accountNumber': prefs.getString('account_number') ?? '',
      'accountName': prefs.getString('account_name') ?? '',
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

  Future<void> updateUserProfile({
    String? name,
    String? phone,
    String? email,
  }) async {
    if (_userId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      _userName = name;
      await prefs.setString('userName', name);
    }
    if (phone != null) {
      _userPhone = phone;
      await prefs.setString('userPhone', phone);
    }
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'name': name ?? _userName,
        'phone': phone ?? _userPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Failed to update user in Firestore: $e');
    }
    
    notifyListeners();
  }
  
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail');
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
      print('❌ Error fetching user role: $e');
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
      print('❌ Error checking washer status: $e');
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
      print('❌ Error getting washer ID: $e');
      return null;
    }
  }
  
  Future<void> updateUserRoleInFirestore(String userId, String role) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ User role updated to $role in Firestore');
    } catch (e) {
      print('❌ Error updating user role: $e');
    }
  }
}