// FILE: test/services/security_service_test.dart
// PURPOSE: Automated unit tests for SecurityService XSS input sanitization and RouteGuard access control rules

import 'package:flutter_test/flutter_test.dart';
import 'package:g_wash_ng/services/security_service.dart';

void main() {
  final security = SecurityService();

  group('XSS Input Sanitization Tests', () {
    test('Should strip HTML tags and script injections', () {
      final input1 = '<script>alert("XSS")</script>John Doe';
      expect(security.sanitizeInput(input1), equals('John Doe'));

      final input2 = 'Hello <iframe src="evil.com"></iframe> World';
      expect(security.sanitizeInput(input2), equals('Hello  World'));

      final input3 = '<a href="javascript:alert(1)">Click Me</a>';
      expect(security.sanitizeInput(input3), equals('Click Me'));
    });

    test('Should remove javascript: URIs and inline event handlers', () {
      final input1 = 'javascript:void(0)';
      expect(security.sanitizeInput(input1), equals('void(0)'));

      final input2 = 'onerror=alert(1) Image';
      expect(security.sanitizeInput(input2), equals('Image'));
    });

    test('Should escape HTML special characters', () {
      final text = '<b style="color:red">Test & "Quotes"</b>';
      final escaped = security.escapeHtml(text);
      expect(escaped, contains('&lt;b'));
      expect(escaped, contains('&amp;'));
      expect(escaped, contains('&quot;'));
    });
  });

  group('RouteGuard Direct Access & Authentication Tests', () {
    test('Should allow public routes without authentication', () {
      final res1 = security.validateRouteAccess(routeName: '/login', isLoggedIn: false, userRole: null);
      expect(res1.isAllowed, isTrue);

      final res2 = security.validateRouteAccess(routeName: '/welcome', isLoggedIn: false, userRole: null);
      expect(res2.isAllowed, isTrue);

      final res3 = security.validateRouteAccess(routeName: '/signup', isLoggedIn: false, userRole: null);
      expect(res3.isAllowed, isTrue);
    });

    test('Should block unauthenticated direct access to protected routes', () {
      final res1 = security.validateRouteAccess(routeName: '/home', isLoggedIn: false, userRole: null);
      expect(res1.isAllowed, isFalse);
      expect(res1.redirectRoute, equals('/login'));

      final res2 = security.validateRouteAccess(routeName: '/washer-dashboard', isLoggedIn: false, userRole: null);
      expect(res2.isAllowed, isFalse);
      expect(res2.redirectRoute, equals('/login'));

      final res3 = security.validateRouteAccess(routeName: '/admin-dashboard', isLoggedIn: false, userRole: null);
      expect(res3.isAllowed, isFalse);
      expect(res3.redirectRoute, equals('/login'));
    });

    test('Should enforce role-based access control (RBAC)', () {
      // Customer trying to access washer dashboard
      final res1 = security.validateRouteAccess(routeName: '/washer-dashboard', isLoggedIn: true, userRole: 'customer');
      expect(res1.isAllowed, isFalse);
      expect(res1.redirectRoute, equals('/home'));

      // Non-admin customer trying to access admin dashboard
      final res2 = security.validateRouteAccess(routeName: '/admin-dashboard', isLoggedIn: true, userRole: 'customer');
      expect(res2.isAllowed, isFalse);
      expect(res2.redirectRoute, equals('/home'));

      // Admin accessing admin dashboard
      final res3 = security.validateRouteAccess(routeName: '/admin-dashboard', isLoggedIn: true, userRole: 'admin');
      expect(res3.isAllowed, isTrue);

      // Washer accessing washer dashboard
      final res4 = security.validateRouteAccess(routeName: '/washer-dashboard', isLoggedIn: true, userRole: 'washer');
      expect(res4.isAllowed, isTrue);
    });
  });
}
