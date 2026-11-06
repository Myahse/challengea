import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/config.dart';
import 'api/online.dart';
import 'api/session_store.dart';
import 'chat_store.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';
import 'theme.dart';
import 'widgets/call_banner.dart';

void main() => runApp(const AppRoot());

enum _Phase { starting, signIn, home }

/// Decides what to show: demo (no server), sign-in, or the app.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final _baseUrl = apiUrl();
  ChatStore _store = ChatStore();
  _Phase _phase = _Phase.starting;
  String? _startError;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_baseUrl.isEmpty) return _show(_Phase.home); // demo build (web link)
    final token = await SessionStore.load();
    if (token == null) return _show(_Phase.signIn);
    try {
      final sync = await OnlineSync.resume(_store, _baseUrl, token);
      _show(sync == null ? _Phase.signIn : _Phase.home);
    } on ApiError catch (e) {
      _startError = e.message;
      _show(_Phase.signIn);
    }
  }

  void _show(_Phase p) {
    if (!mounted) return;
    _store.onSignOut = _signOut;
    setState(() => _phase = p);
  }

  Future<void> _signOut() async {
    await _store.online?.signOut();
    setState(() {
      _store = ChatStore(); // fresh, empty state for the next account
      _store.onSignOut = _signOut;
      _phase = _Phase.signIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChallengeaApp(
      key: ValueKey(_store),
      store: _store,
      home: switch (_phase) {
        _Phase.starting => const _Splash(),
        _Phase.signIn => SignInScreen(
          store: _store,
          baseUrl: _baseUrl,
          onSignedIn: () => _show(_Phase.home),
          onDemo: () => _show(_Phase.home),
        ),
        _Phase.home => HomeShell(store: _store),
      },
      startError: _startError,
    );
  }
}

class ChallengeaApp extends StatelessWidget {
  ChallengeaApp({super.key, required this.store, Widget? home, this.startError})
    : home = home ?? HomeShell(store: store);
  final ChatStore store;
  final Widget home;
  final String? startError;
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
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        child: KeyedSubtree(key: ValueKey(home.runtimeType), child: home),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Text(
        'Challengea',
        style: tx(36, weight: FontWeight.w800).copyWith(letterSpacing: -1.2),
      ),
    ),
  );
}
