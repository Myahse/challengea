import 'package:flutter/foundation.dart';

/// Where the backend runs. Override with --dart-define=API_URL=http://192.168.1.20:8080
/// (your computer's address on the Wi-Fi) when running on a real phone.
/// An empty value means demo mode (no backend), used by the web prototype link.
String apiUrl() {
  const fromBuild = String.fromEnvironment('API_URL', defaultValue: '-');
  if (fromBuild != '-') return fromBuild;
  if (kIsWeb) return ''; // the shared web link runs as a demo
  // Android emulator reaches the computer at 10.0.2.2; iOS simulator at localhost.
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';
}
