import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'online.dart';

/// Push notifications (Firebase Cloud Messaging) for when the app is closed.
/// Does nothing until Firebase is configured (see lib/firebase_options.dart).
class PushService {
  PushService._();
  static String? _token;
  static StreamSubscription<String>? _refresh;

  static Future<void> start(OnlineSync sync) async {
    // Web push needs extra setup (VAPID key, service worker).
    if (kIsWeb) return;
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options == null) return; // Firebase not set up yet
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
      final messaging = FirebaseMessaging.instance;
      final perm = await messaging.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      Future<void> register(String token) async {
        _token = token;
        await sync.api.put('/devices', {'token': token, 'platform': platform});
      }

      // The classic FCM token (what firebase-admin sends to). The newer
      // register()/onRegistered API returns an installation id instead.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await register(token);
      await _refresh?.cancel();
      // ignore: deprecated_member_use
      _refresh = messaging.onTokenRefresh.listen(register);

      // Tapped a notification: open what it is about.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => sync.openFromNotification(m.data),
      );
      final initial = await messaging.getInitialMessage();
      if (initial != null) sync.openFromNotification(initial.data);
    } catch (e) {
      debugPrint('Push notifications disabled: $e');
    }
  }

  /// On sign-out: this phone stops receiving the account's notifications.
  static Future<void> stop(OnlineSync sync) async {
    final token = _token;
    await _refresh?.cancel();
    if (token == null) return;
    try {
      await sync.api.post('/devices/unregister', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });
    } catch (_) {}
  }
}
