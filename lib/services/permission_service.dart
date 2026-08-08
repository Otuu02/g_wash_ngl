import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class PermissionService {
  // ==================== LOCATION PERMISSIONS ====================
  
  /// Request location permission for finding nearby service providers
  static Future<bool> requestLocationPermission(BuildContext context) async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!context.mounted) return false;
    if (!serviceEnabled) {
      _showLocationDialog(
        context, 
        'Location services are disabled. Please enable them to find nearby service providers.',
        onOpenSettings: () async {
          await Geolocator.openLocationSettings();
        },
      );
      return false;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (!context.mounted) return false;
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!context.mounted) return false;
      if (permission == LocationPermission.denied) {
        _showPermissionDialog(
          context,
          'Location Permission Required',
          'Location permission is needed to find nearby washers, cleaners, and laundry services in your area.',
        );
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _showSettingsDialog(
        context,
        'Location Permission Permanently Denied',
        'Please enable location permission in app settings to use location-based services.',
      );
      return false;
    }
    
    return true;
  }

  /// Request background location permission for live tracking
  static Future<bool> requestBackgroundLocationPermission(BuildContext context) async {
    final PermissionStatus status = await Permission.locationAlways.request();
    if (!context.mounted) return false;
    
    if (status == PermissionStatus.granted) {
      return true;
    } else if (status == PermissionStatus.denied) {
      _showPermissionDialog(
        context,
        'Background Location Permission',
        'Background location access is needed for live tracking of your service provider.',
      );
      return false;
    } else if (status == PermissionStatus.permanentlyDenied) {
      _showSettingsDialog(
        context,
        'Background Location Required',
        'Please enable "Allow all the time" location permission in app settings for live tracking.',
      );
      return false;
    }
    
    return false;
  }

  // ==================== CAMERA PERMISSION ====================
  
  /// Request camera permission for taking photos (profile, vehicle, etc.)
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final PermissionStatus status = await Permission.camera.request();
    if (!context.mounted) return false;
    
    if (status == PermissionStatus.granted) {
      return true;
    } else if (status == PermissionStatus.denied) {
      _showPermissionDialog(
        context,
        'Camera Permission Required',
        'Camera access is needed to take profile photos and upload vehicle images.',
      );
      return false;
    } else if (status == PermissionStatus.permanentlyDenied) {
      _showSettingsDialog(
        context,
        'Camera Permission Required',
        'Please enable camera permission in app settings to use this feature.',
      );
      return false;
    }
    
    return false;
  }

  // ==================== STORAGE PERMISSIONS ====================
  
  /// Request photo library permission for uploading images
  static Future<bool> requestStoragePermission(BuildContext context) async {
    PermissionStatus status;
    
    // For Android 13+ (API 33+), use photos permission
    if (await _isAndroid13OrAbove()) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.storage.request();
    }
    if (!context.mounted) return false;
    
    if (status == PermissionStatus.granted) {
      return true;
    } else if (status == PermissionStatus.denied) {
      _showPermissionDialog(
        context,
        'Storage Permission Required',
        'Storage access is needed to upload profile photos and vehicle images.',
      );
      return false;
    } else if (status == PermissionStatus.permanentlyDenied) {
      _showSettingsDialog(
        context,
        'Storage Permission Required',
        'Please enable storage permission in app settings to upload images.',
      );
      return false;
    }
    
    return false;
  }

  // ==================== NOTIFICATION PERMISSIONS ====================
  
  /// Request notification permission for push notifications (Android 13+)
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    // Only needed for Android 13+
    if (await _isAndroid13OrAbove()) {
      final PermissionStatus status = await Permission.notification.request();
      if (!context.mounted) return false;
      
      if (status == PermissionStatus.granted) {
        return true;
      } else if (status == PermissionStatus.denied) {
        // Notifications are optional, don't show dialog
        return false;
      } else if (status == PermissionStatus.permanentlyDenied) {
        // User can still get notifications through Firebase
        return false;
      }
    }
    
    return true; // Notifications are optional
  }

  // ==================== CONTACT PERMISSION ====================
  
  /// Request contact permission for sharing and referrals
  static Future<bool> requestContactPermission(BuildContext context) async {
    final PermissionStatus status = await Permission.contacts.request();
    if (!context.mounted) return false;
    
    if (status == PermissionStatus.granted) {
      return true;
    } else if (status == PermissionStatus.denied) {
      // Contacts are optional for referrals
      return false;
    } else if (status == PermissionStatus.permanentlyDenied) {
      return false;
    }
    
    return false;
  }

  // ==================== MICROPHONE PERMISSION ====================
  
  /// Request microphone permission for voice notes and calls
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    final PermissionStatus status = await Permission.microphone.request();
    if (!context.mounted) return false;
    
    if (status == PermissionStatus.granted) {
      return true;
    } else if (status == PermissionStatus.denied) {
      _showPermissionDialog(
        context,
        'Microphone Permission',
        'Microphone access is needed for voice notes and customer support calls.',
        showCancelButton: true,
      );
      return false;
    } else if (status == PermissionStatus.permanentlyDenied) {
      _showSettingsDialog(
        context,
        'Microphone Permission Required',
        'Please enable microphone permission in app settings for voice features.',
      );
      return false;
    }
    
    return false;
  }

  // ==================== PHONE PERMISSION ====================
  
  /// Request phone permission for making calls to service providers
  static Future<bool> requestPhonePermission(BuildContext context) async {
    final PermissionStatus status = await Permission.phone.request();
    
    if (status == PermissionStatus.granted) {
      return true;
    } else if (status == PermissionStatus.denied) {
      // Phone calls can be made without permission
      return false;
    } else if (status == PermissionStatus.permanentlyDenied) {
      return false;
    }
    
    return false;
  }

  // ==================== ALL PERMISSIONS AT ONCE ====================
  
  /// Request all required permissions at once
  static Future<Map<String, bool>> requestAllPermissions(BuildContext context) async {
    final results = <String, bool>{};
    
    // Request location
    results['location'] = await requestLocationPermission(context);
    if (!context.mounted) return results;
    
    // Request camera
    results['camera'] = await requestCameraPermission(context);
    if (!context.mounted) return results;
    
    // Request storage
    results['storage'] = await requestStoragePermission(context);
    if (!context.mounted) return results;
    
    // Request notifications (optional)
    results['notifications'] = await requestNotificationPermission(context);
    
    return results;
  }

  /// Request permissions for service providers (washers, cleaners, etc.)
  static Future<Map<String, bool>> requestProviderPermissions(BuildContext context) async {
    final results = <String, bool>{};
    
    // Location is required
    results['location'] = await requestLocationPermission(context);
    if (!context.mounted) return results;
    
    // Background location for providers
    results['backgroundLocation'] = await requestBackgroundLocationPermission(context);
    if (!context.mounted) return results;
    
    // Camera for vehicle/service photos
    results['camera'] = await requestCameraPermission(context);
    if (!context.mounted) return results;
    
    // Storage for uploading documents
    results['storage'] = await requestStoragePermission(context);
    if (!context.mounted) return results;
    
    // Notifications for job alerts
    results['notifications'] = await requestNotificationPermission(context);
    
    return results;
  }

  // ==================== PERMISSION CHECKERS ====================
  
  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final PermissionStatus status = await Permission.location.status;
    return status == PermissionStatus.granted;
  }
  
  /// Check if background location permission is granted
  static Future<bool> isBackgroundLocationPermissionGranted() async {
    final PermissionStatus status = await Permission.locationAlways.status;
    return status == PermissionStatus.granted;
  }
  
  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    final PermissionStatus status = await Permission.camera.status;
    return status == PermissionStatus.granted;
  }
  
  /// Check if storage permission is granted
  static Future<bool> isStoragePermissionGranted() async {
    if (await _isAndroid13OrAbove()) {
      final PermissionStatus status = await Permission.photos.status;
      return status == PermissionStatus.granted;
    } else {
      final PermissionStatus status = await Permission.storage.status;
      return status == PermissionStatus.granted;
    }
  }
  
  /// Check if notification permission is granted
  static Future<bool> isNotificationPermissionGranted() async {
    if (await _isAndroid13OrAbove()) {
      final PermissionStatus status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    }
    return true;
  }
  
  /// Check if location services are enabled
  static Future<bool> areLocationServicesEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // ==================== BULK PERMISSION CHECK ====================
  
  /// Check all required permissions at once
  static Future<Map<String, bool>> checkAllPermissions() async {
    final results = <String, bool>{};
    
    results['location'] = await isLocationPermissionGranted();
    results['camera'] = await isCameraPermissionGranted();
    results['storage'] = await isStoragePermissionGranted();
    results['notifications'] = await isNotificationPermissionGranted();
    results['locationServices'] = await areLocationServicesEnabled();
    
    return results;
  }

  // ==================== HELPER METHODS ====================
  
  /// Check if device is running Android 13 or above
  static Future<bool> _isAndroid13OrAbove() async {
    if (Platform.isAndroid) {
      try {
        final versionStr = Platform.operatingSystemVersion.toLowerCase();
        
        // Check for API level (e.g. "api 33", "sdk 33")
        final apiMatch = RegExp(r'(api|sdk)\s*(\d+)').firstMatch(versionStr);
        if (apiMatch != null) {
          final sdkInt = int.parse(apiMatch.group(2)!);
          return sdkInt >= 33;
        }
        
        // Check for Android version (e.g. "android 13")
        final androidMatch = RegExp(r'android\s*(\d+)').firstMatch(versionStr);
        if (androidMatch != null) {
          final ver = int.parse(androidMatch.group(1)!);
          return ver >= 13;
        }
        
        // Fallback: look for any number >= 33
        final numberMatches = RegExp(r'\d+').allMatches(versionStr);
        for (var match in numberMatches) {
          final num = int.tryParse(match.group(0)!);
          if (num != null && num >= 33 && num < 100) {
            return true;
          }
        }
      } catch (e) {
        debugPrint('Error parsing OS version: $e');
      }
    }
    return false;
  }
  
  /// Show permission dialog
  static void _showPermissionDialog(
    BuildContext context,
    String title,
    String message, {
    bool showCancelButton = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          if (showCancelButton)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0CAF60),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
  
  /// Show settings dialog when permission is permanently denied
  static void _showSettingsDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0CAF60),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  /// Show location dialog
  static void _showLocationDialog(
    BuildContext context,
    String message, {
    VoidCallback? onOpenSettings,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Location Services Required',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOpenSettings != null) {
                onOpenSettings();
              } else {
                openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0CAF60),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
  }
  
  /// Show permission denied snackbar
  static void showPermissionDeniedSnackBar(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName requires permission. Please grant it in settings.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            openAppSettings();
          },
        ),
      ),
    );
  }
}