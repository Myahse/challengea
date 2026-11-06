import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the sign-in token on the phone so you stay signed in.
class SessionStore {
  static const _key = 'challengea.token';

  static Future<String?> load() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token == null
          ? await prefs.remove(_key)
          : await prefs.setString(_key, token);
    } catch (_) {}
  }
}
