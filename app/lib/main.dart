import 'package:flutter/material.dart';

import 'chat_store.dart';
import 'screens/chat_home.dart';
import 'theme.dart';

void main() => runApp(ChallengeaApp(store: ChatStore()));

class ChallengeaApp extends StatelessWidget {
  const ChallengeaApp({super.key, required this.store});
  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Challengea',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ChatHome(store: store),
    );
  }
}
