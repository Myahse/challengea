import 'package:flutter/material.dart';

import 'chat_store.dart';
import 'screens/home_shell.dart';
import 'theme.dart';
import 'widgets/call_banner.dart';

void main() => runApp(ChallengeaApp(store: ChatStore()));

class ChallengeaApp extends StatelessWidget {
  ChallengeaApp({super.key, required this.store});
  final ChatStore store;
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Challengea',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: _navigator,
      builder: (context, child) =>
          CallBanner(store: store, navigatorKey: _navigator, child: child!),
      home: HomeShell(store: store),
    );
  }
}
