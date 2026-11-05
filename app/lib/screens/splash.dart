import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import 'onboarding.dart';

/// Figma: LOGIN frame 82:290 (logo + "Powered by Djogana group").
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.store});
  final ChatStore store;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, a, _) => FadeTransition(
            opacity: a,
            child: OnboardingScreen(store: widget.store),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: Tween(begin: .85, end: 1.0).animate(
                      CurvedAnimation(parent: _fade, curve: Curves.easeOutBack),
                    ),
                    child: const NteriLogo(size: 48),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Powered by Djogana group',
                style: tx(13, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
