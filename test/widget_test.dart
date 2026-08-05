import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as provider;
import 'package:g_wash_ng/services/auth_service.dart';
import 'package:g_wash_ng/services/app_notification_service.dart';
import 'package:g_wash_ng/main.dart';

class MockAuthService extends AuthService {
  MockAuthService() : super();

  void listenToAuthChanges() {}

  Future<void> loadSavedUser() async {}

  @override
  bool get isLoggedIn => false;

  @override
  String? get userName => null;

  @override
  String? get userPhone => null;

  @override
  String? get userId => null;

  @override
  String? get userRole => null;

  @override
  String? get serviceCategory => null;
}

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    // Set realistic mobile screen size to avoid layout overflows under default test viewport (800x600)
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockAuth = MockAuthService();
    final notificationService = AppNotificationService();

    // Build our app wrapped in the required Provider and trigger a frame.
    await tester.pumpWidget(
      provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider<AuthService>(create: (_) => mockAuth),
          provider.ChangeNotifierProvider<AppNotificationService>(create: (_) => notificationService),
        ],
        child: const GWashApp(),
      ),
    );

    // Verify that the welcome screen title is present.
    expect(find.text('G Wash NG'), findsOneWidget);
  });
}
