import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/studio_notification_settings.dart';
import 'package:frontend/pages/settings_page.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/notification_settings_provider.dart';
import 'package:frontend/widgets/notification_settings_section.dart';

void main() {
  const token = 'admin-token';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.loadAll();
  });

  Map<String, dynamic> settingsJson({
    bool paymentAlertsEnabled = false,
    String? paymentRemindersActivatedAt,
  }) => {
    'quietHoursStart': '21:00',
    'quietHoursEnd': '09:00',
    'classReminderEnabled': true,
    'reservationAlertsEnabled': true,
    'packageAlertsEnabled': true,
    'paymentAlertsEnabled': paymentAlertsEnabled,
    'inactivityAlertsEnabled': true,
    'paymentRemindersActivatedAt': paymentRemindersActivatedAt,
    'memberReminderMinutes': 120,
    'instructorReminderMinutes': 60,
    'lowLessonsThreshold': 2,
    'packageExpiryDays': 7,
    'inactivityDays': 14,
  };

  group('StudioNotificationSettings model', () {
    test('parses all backend fields', () {
      final s = StudioNotificationSettings.fromJson(
        settingsJson(paymentRemindersActivatedAt: '2026-10-30'),
      );
      expect(s.classReminderEnabled, isTrue);
      expect(s.reservationAlertsEnabled, isTrue);
      expect(s.paymentAlertsEnabled, isFalse);
      expect(s.memberReminderMinutes, 120);
      expect(s.instructorReminderMinutes, 60);
      expect(s.lowLessonsThreshold, 2);
      expect(s.packageExpiryDays, 7);
      expect(s.inactivityDays, 14);
      expect(s.quietHoursStart, '21:00');
      expect(s.quietHoursEnd, '09:00');
      expect(s.paymentRemindersActivatedAt, '2026-10-30');
    });

    test('defensive parsing for missing/invalid values', () {
      final s = StudioNotificationSettings.fromJson({
        'memberReminderMinutes': 'not-a-number',
        'quietHoursStart': '25:99', // invalid
      });
      expect(s.memberReminderMinutes, 120); // default
      expect(s.quietHoursStart, '21:00'); // default
      expect(s.paymentAlertsEnabled, isFalse); // default
      expect(s.reservationAlertsEnabled, isTrue); // default
    });

    test('toJson sends only editable fields, never activation date', () {
      final s = StudioNotificationSettings.fromJson(
        settingsJson(paymentRemindersActivatedAt: '2026-10-30'),
      );
      final json = s.toJson();
      expect(json.containsKey('paymentRemindersActivatedAt'), isFalse);
      expect(json['memberReminderMinutes'], 120);
      expect(json['quietHoursStart'], '21:00');
      expect(json['paymentAlertsEnabled'], isFalse);
    });
  });

  group('NotificationSettingsNotifier', () {
    ProviderContainer createContainer(http.Client client) {
      final container = ProviderContainer(
        overrides: [
          notificationSettingsProvider.overrideWith(
            (ref) => NotificationSettingsNotifier(ref, client: client),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('fetchSettings GETs with Bearer token and parses', () async {
      String? capturedAuth;
      String? capturedPath;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedPath = request.url.path;
        return http.Response(jsonEncode(settingsJson()), 200);
      });
      final container = createContainer(client);
      await container
          .read(notificationSettingsProvider.notifier)
          .fetchSettings(token);

      final state = container.read(notificationSettingsProvider);
      expect(capturedPath, '/settings/notifications/settings');
      expect(capturedAuth, 'Bearer $token');
      expect(state.settings, isNotNull);
      expect(state.settings!.memberReminderMinutes, 120);
      expect(state.hasLoadedOnce, isTrue);
    });

    test('updateSettings PUTs editable fields with Bearer token', () async {
      String? capturedAuth;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(settingsJson(paymentAlertsEnabled: true)),
          200,
        );
      });
      final container = createContainer(client);
      final settings = StudioNotificationSettings.fromJson(
        settingsJson(paymentAlertsEnabled: true),
      );
      final error = await container
          .read(notificationSettingsProvider.notifier)
          .updateSettings(token, settings);

      expect(error, isNull);
      expect(capturedAuth, 'Bearer $token');
      expect(capturedBody?['paymentAlertsEnabled'], isTrue);
      expect(capturedBody?.containsKey('paymentRemindersActivatedAt'), isFalse);
    });

    test(
      'updateSettings returns error and preserves state on failure',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error':
                  'memberReminderMinutes must be an integer between 0 and 1440',
            }),
            400,
          );
        });
        final container = createContainer(client);
        final settings = StudioNotificationSettings.fromJson(settingsJson());
        final error = await container
            .read(notificationSettingsProvider.notifier)
            .updateSettings(token, settings);

        expect(error, isNotNull);
        final state = container.read(notificationSettingsProvider);
        expect(state.isSaving, isFalse);
        expect(state.error, isNotNull);
      },
    );
  });

  group('Admin-only visibility', () {
    test('admin can manage notification settings (billing gate)', () {
      expect(canManageBillingSettings(const AuthState(role: 'admin')), isTrue);
    });

    test('instructor cannot manage notification settings', () {
      expect(
        canManageBillingSettings(const AuthState(role: 'instructor')),
        isFalse,
      );
    });

    test(
      'instructor with settings permission still cannot see notifications tab',
      () {
        expect(
          canManageBillingSettings(
            const AuthState(role: 'instructor', permissions: ['settings']),
          ),
          isFalse,
        );
      },
    );
  });

  group('NotificationSettingsSection UI', () {
    Future<void> scrollToBottom(WidgetTester tester) async {
      // Drag the ListView up repeatedly until the Save button is visible.
      for (var i = 0; i < 12; i++) {
        if (find.text('Save').evaluate().isNotEmpty) return;
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
    }

    Future<void> scrollUntil(WidgetTester tester, Finder finder) async {
      // Drag the ListView up repeatedly until the target is visible.
      for (var i = 0; i < 12; i++) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
    }

    Widget harness(http.Client client, {String role = 'admin'}) {
      return ProviderScope(
        overrides: [
          notificationSettingsProvider.overrideWith(
            (ref) => NotificationSettingsNotifier(ref, client: client),
          ),
          authProvider.overrideWith(
            (ref) => AuthNotifier()
              ..setAuth(
                token: token,
                role: role,
                assignedSalonIds: const [],
                permissions: const [],
              ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en'), Locale('tr')],
          home: const Scaffold(body: NotificationSettingsSection()),
        ),
      );
    }

    testWidgets('loads and renders settings form', (tester) async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode(settingsJson()), 200);
      });
      await tester.pumpWidget(harness(client));
      await tester.pumpAndSettle();

      expect(find.text('Notification Categories'), findsOneWidget);
      expect(find.text('Class Reminders'), findsOneWidget);
      expect(find.text('Reservations'), findsOneWidget);

      // Scroll down to reveal lower sections.
      await scrollUntil(tester, find.text('Timing & Thresholds'));
      expect(find.text('Timing & Thresholds'), findsOneWidget);
      await scrollUntil(tester, find.text('Quiet Hours'));
      expect(find.text('Quiet Hours'), findsOneWidget);
    });

    testWidgets('groups notification types into five backend categories', (
      tester,
    ) async {
      var putBody = <String, dynamic>{};
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          putBody = jsonDecode(request.body) as Map<String, dynamic>;
        }
        return http.Response(jsonEncode(settingsJson()), 200);
      });
      await tester.pumpWidget(harness(client));
      await tester.pumpAndSettle();

      // The five backend-aligned categories, in order.
      for (final title in [
        'Class Reminders',
        'Reservations',
        'Packages',
        'Inactivity',
        'Payments',
      ]) {
        await scrollUntil(tester, find.text(title));
        expect(find.text(title), findsOneWidget, reason: 'category $title');
      }

      // Exactly five toggles — every category has a stored preference now.
      expect(find.text('Always on'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(NotificationSettingsSection),
          matching: find.byType(Switch),
        ),
        findsNWidgets(5),
      );

      // Toggling Reservations persists reservationAlertsEnabled via the
      // existing PUT contract (no new or unknown fields are introduced).
      await scrollUntil(tester, find.text('Reservations'));
      await tester.tap(
        find.ancestor(
          of: find.text('Reservations'),
          matching: find.byType(SwitchListTile),
        ),
      );
      await tester.pumpAndSettle();
      await scrollToBottom(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(putBody['reservationAlertsEnabled'], isFalse);
      expect(putBody['packageAlertsEnabled'], isTrue);
      expect(
        putBody.keys.toSet(),
        StudioNotificationSettings.fromJson(settingsJson()).toJson().keys.toSet(),
      );
    });

    testWidgets('save PUTs updated settings and shows success', (tester) async {
      var putCalled = false;
      Map<String, dynamic>? putBody;
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          putCalled = true;
          putBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(settingsJson()), 200);
        }
        return http.Response(jsonEncode(settingsJson()), 200);
      });
      await tester.pumpWidget(harness(client));
      await tester.pumpAndSettle();

      await scrollToBottom(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(putCalled, isTrue);
      expect(putBody?['memberReminderMinutes'], 120);
      expect(find.text('Notification settings saved.'), findsOneWidget);
    });

    testWidgets(
      'payment reminders toggle is opt-in and shows activation date read-only',
      (tester) async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode(
              settingsJson(
                paymentAlertsEnabled: true,
                paymentRemindersActivatedAt: '2026-10-30',
              ),
            ),
            200,
          );
        });
        await tester.pumpWidget(harness(client));
        await tester.pumpAndSettle();

        // Opt-in hint is shown.
        expect(find.textContaining('opt-in'), findsOneWidget);
        // Activation date shown read-only (no editable field for it).
        expect(find.textContaining('2026-10-30'), findsOneWidget);
      },
    );

    testWidgets('validates numeric range and blocks save', (tester) async {
      var putCalled = false;
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          putCalled = true;
          return http.Response(jsonEncode(settingsJson()), 200);
        }
        return http.Response(jsonEncode(settingsJson()), 200);
      });
      await tester.pumpWidget(harness(client));
      await tester.pumpAndSettle();

      // Scroll to reveal the numeric field, then enter an out-of-range value
      // for lowLessonsThreshold (max 100).
      await scrollUntil(
        tester,
        find.widgetWithText(TextFormField, 'Low lessons threshold'),
      );
      final field = find.widgetWithText(TextFormField, 'Low lessons threshold');
      await tester.enterText(field, '500');
      await scrollToBottom(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(putCalled, isFalse);
      expect(find.textContaining('between 0 and 100'), findsOneWidget);
    });

    testWidgets('shows load error with retry', (tester) async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'boom'}), 500);
      });
      await tester.pumpWidget(harness(client));
      await tester.pumpAndSettle();

      expect(
        find.text('Notification settings could not be loaded.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders on wide (tablet/web) layout', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = MockClient((request) async {
        return http.Response(jsonEncode(settingsJson()), 200);
      });
      await tester.pumpWidget(harness(client));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationSettingsSection), findsOneWidget);
      expect(find.text('Notification Categories'), findsOneWidget);
    });
  });
}
