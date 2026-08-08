// FILE: lib/services/security_service.dart
// PURPOSE: Provide XSS input sanitization and route guard security rules against unauthorized direct URL access

import 'package:flutter/material.dart';

class RouteGuardResult {
  final bool isAllowed;
  final String? redirectRoute;
  final String? reason;

  RouteGuardResult({required this.isAllowed, this.redirectRoute, this.reason});
}

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  /// List of public routes accessible without login
  static const Set<String> publicRoutes = {
    '/',
    '/welcome',
    '/login',
    '/signup',
    '/forgot-password',
    '/otp',
    '/privacy-policy',
    '/terms',
  };

  /// List of protected routes requiring customer role
  static const Set<String> customerProtectedRoutes = {
    '/home',
    '/booking',
    '/matching',
    '/tracking',
    '/payment',
    '/service-selection',
    '/house-cleaning-details',
    '/laundry-details',
    '/ride-booking',
    '/order-history',
    '/profile',
  };

  /// List of protected routes requiring service provider (washer/cleaner/laundry/ride) role
  static const Set<String> providerProtectedRoutes = {
    '/washer-dashboard',
    '/washer-profile',
    '/washer-earnings',
    '/washer-history',
    '/washer-registration',
  };

  /// List of protected routes requiring admin role
  static const Set<String> adminProtectedRoutes = {
    '/admin-dashboard',
    '/admin-users',
    '/admin-jobs',
    '/admin-payouts',
  };

  /// Sanitize user inputs against Cross-Site Scripting (XSS) attacks
  String sanitizeInput(String input) {
    if (input.isEmpty) return '';

    String cleaned = input.trim();

    // 1. Remove complete <script>...</script> and <style>...</style> blocks (including inner content)
    cleaned = cleaned.replaceAll(RegExp(r'<script\b[^<]*>([\s\S]*?)<\/script>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<style\b[^<]*>([\s\S]*?)<\/style>', caseSensitive: false), '');

    // 2. Remove all remaining HTML tags
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>', caseSensitive: false), '');

    // 3. Remove dangerous JavaScript URIs & inline execution handlers
    cleaned = cleaned.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'vbscript:', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'data:text/html', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'on\w+\s*=\s*[^\s>]+', caseSensitive: false), '');

    return cleaned.trim();
  }

  /// Escape special HTML characters to prevent rendering or injection
  String escapeHtml(String text) {
    if (text.isEmpty) return '';

    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Validate whether a user is authorized to access a given route
  RouteGuardResult validateRouteAccess({
    required String? routeName,
    required bool isLoggedIn,
    required String? userRole,
  }) {
    if (routeName == null || routeName.isEmpty || publicRoutes.contains(routeName)) {
      return RouteGuardResult(isAllowed: true);
    }

    // 1. Unauthenticated users trying to access any protected route
    if (!isLoggedIn) {
      debugPrint('ðŸ›¡ï¸ [RouteGuard]: Blocked unauthenticated attempt to access $routeName -> Redirecting to /login');
      return RouteGuardResult(
        isAllowed: false,
        redirectRoute: '/login',
        reason: 'Authentication required. Please log in first.',
      );
    }

    // 2. Role-Based Access Control (RBAC) Checks
    final role = (userRole ?? 'customer').toLowerCase();

    // Admin access
    if (adminProtectedRoutes.contains(routeName)) {
      if (role != 'admin') {
        debugPrint('ðŸ›¡ï¸ [RouteGuard]: Non-admin role ($role) tried accessing $routeName -> Redirecting');
        final targetRoute = _getHomeRouteForRole(role);
        return RouteGuardResult(
          isAllowed: false,
          redirectRoute: targetRoute,
          reason: 'Admin access required.',
        );
      }
      return RouteGuardResult(isAllowed: true);
    }

    // Provider access
    if (providerProtectedRoutes.contains(routeName)) {
      if (role == 'customer') {
        debugPrint('ðŸ›¡ï¸ [RouteGuard]: Customer tried accessing provider route $routeName -> Redirecting to /home');
        return RouteGuardResult(
          isAllowed: false,
          redirectRoute: '/home',
          reason: 'Service provider account required.',
        );
      }
      return RouteGuardResult(isAllowed: true);
    }

    // Customer access
    if (customerProtectedRoutes.contains(routeName)) {
      if (role == 'washer' || role == 'cleaner' || role == 'laundry_provider') {
        debugPrint('ðŸ›¡ï¸ [RouteGuard]: Provider ($role) tried accessing customer route $routeName -> Redirecting to /washer-dashboard');
        return RouteGuardResult(
          isAllowed: false,
          redirectRoute: '/washer-dashboard',
          reason: 'Switched to provider dashboard.',
        );
      }
      return RouteGuardResult(isAllowed: true);
    }

    // Default allow for unlisted dynamic routes
    return RouteGuardResult(isAllowed: true);
  }

  String _getHomeRouteForRole(String role) {
    switch (role) {
      case 'admin':
        return '/admin-dashboard';
      case 'washer':
      case 'cleaner':
      case 'laundry_provider':
        return '/washer-dashboard';
      case 'customer':
      default:
        return '/home';
    }
  }
}
