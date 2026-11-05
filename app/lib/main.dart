import 'package:flutter/material.dart';

import 'chat_store.dart';
import 'screens/splash.dart';
import 'theme.dart';

void main() => runApp(NteriApp(store: ChatStore()));

class NteriApp extends StatelessWidget {
  const NteriApp({super.key, required this.store});
  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nteri',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: SplashScreen(store: store),
    );
  }
}
