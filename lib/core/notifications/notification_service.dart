import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/notification_promo_sheet.dart';
import '../api/api_client.dart';

// ---------------------------------------------------------------------------
// Background message handler — must be a top-level function
// ---------------------------------------------------------------------------

/// Handles messages received when the app is in the background / terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] background message: ${message.messageId}');
}

// ---------------------------------------------------------------------------
// Notification channel constants
// ---------------------------------------------------------------------------

const _kChannelId = 'kayfit_channel';
const _kChannelName = 'Kayfit';
const _kChannelDescription = 'Kayfit notifications';
const _kPermRequestedKey = 'notif_perm_requested';

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

/// Centralised push-notification service.
///
/// Call [NotificationService.init] once from [main] after
/// [WidgetsFlutterBinding.ensureInitialized]. Permissions are NOT requested
/// automatically — use [showPromoAndRequest] to show the explanation sheet
/// first, then request permissions on user consent.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Navigation callback — set by the app shell when the router is ready.
  static void Function(String route)? _onNavigate;

  /// Register a callback that the service uses to navigate when the user taps
  /// a notification.
  static void setNavigationCallback(void Function(String route) cb) {
    _onNavigate = cb;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Initialises Firebase, registers handlers, but does NOT request permissions.
  ///
  /// Permissions are deferred to [showPromoAndRequest].
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      await initAfterFirebase();
    } catch (e) {
      // Firebase not configured (missing config files) — continue without push.
      debugPrint('[FCM] init skipped (Firebase not configured): $e');
    }
  }

  /// Like [init] but assumes Firebase.initializeApp() was already called.
  /// Use this when Firebase is initialised in main() before parallel inits.
  static Future<void> initAfterFirebase() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      await _initLocalNotifications();
      // NOTE: _requestPermissions() is intentionally NOT called here.
      _setupForegroundHandler();
      _setupNotificationTapHandler();
      _setupTokenRefresh();

      debugPrint('[FCM] NotificationService initialised (permissions deferred)');
    } catch (e) {
      debugPrint('[FCM] initAfterFirebase error (ignored): $e');
    }
  }

  /// Shows the explanation promo sheet, and when the user taps "Allow",
  /// requests the actual OS notification permission.
  ///
  /// Marks the permission as requested in [SharedPreferences] so the sheet
  /// is only shown once.
  static Future<void> showPromoAndRequest(BuildContext context) async {
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => NotificationPromoSheet(
        onAllow: () async {
          await _markPermissionRequested();
          await _requestPermissions();
          await _registerToken();
        },
        onDismiss: () async {
          await _markPermissionRequested();
        },
      ),
    );
  }

  /// Returns true if the notification permission dialog has already been
  /// shown to the user (regardless of whether they allowed or denied).
  static Future<bool> wasPermissionRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kPermRequestedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Registers the FCM token with the backend.
  /// Call this after a successful login when the auth token is already stored.
  static Future<void> registerTokenAfterLogin() async {
    try {
      await _registerToken();
    } catch (e) {
      debugPrint('[FCM] registerTokenAfterLogin error (ignored): $e');
    }
  }

  /// Shows a local notification when background photo recognition completes.
  static Future<void> showMealRecognized({
    required String dishName,
    required double kcal,
    required bool isRu,
  }) async {
    try {
      final title = isRu ? 'Блюдо распознано' : 'Meal recognized';
      final body = isRu
          ? '$dishName — ${kcal.round()} ккал'
          : '$dishName — ${kcal.round()} kcal';
      await _showLocalNotification(
        title: title,
        body: body,
        // Each meal_recognized notification replaces the previous one (same ID
        // via hashCode). Acceptable for back-to-back scans.
        data: const {'type': 'meal_recognized'},
      );
    } catch (e) {
      debugPrint('[FCM] showMealRecognized error (ignored): $e');
    }
  }

  /// Unregisters the FCM token from the backend and deletes it locally.
  static Future<void> unregisterToken() async {
    try {
      await apiDio.delete('/api/devices/token');
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[FCM] token unregistered');
    } catch (e) {
      debugPrint('[FCM] unregisterToken error (ignored): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static Future<void> _markPermissionRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPermRequestedKey, true);
    } catch (_) {}
  }

  static Future<void> _requestPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] permission status: ${settings.authorizationStatus}');

      // Android 13+ (API 33) POST_NOTIFICATIONS runtime permission.
      if (Platform.isAndroid) {
        await _localNotif
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[FCM] _requestPermissions error (ignored): $e');
    }
  }

  static Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] _registerToken error (ignored): $e');
    }
  }

  static void _setupTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen(
      _sendTokenToBackend,
      onError: (e) => debugPrint('[FCM] onTokenRefresh error: $e'),
    );
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      await apiDio.post('/api/devices/register', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      debugPrint('[FCM] token registered with backend');
    } catch (e) {
      debugPrint('[FCM] token registration failed (ignored): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Local notifications setup
  // ---------------------------------------------------------------------------

  static Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    const channel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDescription,
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ---------------------------------------------------------------------------
  // Message handlers
  // ---------------------------------------------------------------------------

  static void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _showLocalNotification(
        title: notification.title ?? '',
        body: notification.body ?? '',
        data: message.data,
      );
    });
  }

  static void _setupNotificationTapHandler() {
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    final type = response.payload;
    _handleNotificationTap({'type': type ?? ''});
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final route = switch (type) {
      'daily_reminder' => '/',
      'streak' => '/',
      'weekly_summary' => '/journal',
      'meal_recognized' => '/chat-v2',
      _ => '/',
    };
    _onNavigate?.call(route);
  }

  // ---------------------------------------------------------------------------
  // Show local notification (foreground)
  // ---------------------------------------------------------------------------

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotif.show(
      data['type'].hashCode,
      title,
      body,
      details,
      payload: data['type'] as String?,
    );
  }
}
