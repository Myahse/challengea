import 'dart:math';

import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import '../widgets/support_sheet.dart';
import 'auth.dart';

/// Figma: LOGIN frames 83:286, 86:386, 86:484, 86:533 (4 onboarding slides).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store});
  final ChatStore store;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide(
    this.title,
    this.subtitle,
    this.icon,
    this.colors, {
    this.withLogo = false,
  });
  final String title;
  final String subtitle;
  final IconData
  icon; // placeholder illustration until the Figma images are final
  final List<Color> colors;
  final bool withLogo;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // 4th slide repeats slide 2 in Figma; it uses the app's chat + games pitch for now.
  static const _slides = [
    _Slide(
      'Bienvenue sur',
      'Découvrez votre nouvelle application\ntout en un',
      Icons.waving_hand_rounded,
      [Color(0xFFDFF7E6), Color(0xFFB8EBC8)],
      withLogo: true,
    ),
    _Slide(
      'Accédez à des services exclusifs en un seul clic !',
      'Des services conçus rien que pour vous !',
      Icons.auto_awesome_rounded,
      [Color(0xFFE8E4FF), Color(0xFFC9C0FF)],
    ),
    _Slide(
      'Effectuez vos paiements instantanément',
      'Votre wallet, c’est votre application.',
      Icons.account_balance_wallet_rounded,
      [Color(0xFFFFF1D6), Color(0xFFFFD99A)],
    ),
    _Slide(
      'Discutez et jouez avec vos amis',
      'Messages, notes vocales, stickers et défis en duel.',
      Icons.sports_esports_rounded,
      [Color(0xFFFFE1EC), Color(0xFFFFB8D1)],
    ),
  ];

  final _pages = PageController(viewportFraction: .58);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int get _index => _page.round().clamp(0, _slides.length - 1);

  void _go(int delta) {
    final i = (_index + delta).clamp(0, _slides.length - 1);
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _openAuth(AuthMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthScreen(store: widget.store, mode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Contact support',
                onPressed: () => showSupportSheet(context),
                icon: const Icon(Icons.help_outline_rounded, size: 26),
              ),
            ),
            Expanded(
              flex: 6,
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  // Side cards tilt away and shrink, like the Figma carousel.
                  final d = (i - _page).clamp(-1.5, 1.5);
                  return Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..rotateZ(d * 0.17)
                        ..scaleByDouble(
                          1 - d.abs() * .12,
                          1 - d.abs() * .12,
                          1,
                          1,
                        ),
                      child: AspectRatio(
                        aspectRatio: 240 / 320,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: _slides[i].colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Opacity(
                            opacity: max(0, 1 - d.abs() * .6),
                            child: Icon(
                              _slides[i].icon,
                              size: 72,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Padding(
                  key: ValueKey(_index),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: tx(
                          30,
                          weight: FontWeight.w800,
                        ).copyWith(height: 1.05),
                      ),
                      if (slide.withLogo) const NteriLogo(size: 56),
                      const SizedBox(height: 6),
                      Text(
                        slide.subtitle,
                        textAlign: TextAlign.center,
                        style: tx(14, weight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: i == _index ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _index ? AppColors.ink : AppColors.bubble,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _index == 0 ? null : () => _go(-1),
                    icon: Icon(
                      Icons.chevron_left,
                      size: 30,
                      color: _index == 0 ? Colors.transparent : AppColors.ink,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 190,
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.ink),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _openAuth(AuthMode.signUp),
                          child: Text(
                            'S’inscrire',
                            style: tx(
                              16,
                              weight: FontWeight.w700,
                            ).copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _index == _slides.length - 1
                        ? null
                        : () => _go(1),
                    icon: Icon(
                      Icons.chevron_right,
                      size: 30,
                      color: _index == _slides.length - 1
                          ? Colors.transparent
                          : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openAuth(AuthMode.login),
              child: Text(
                'Déjà inscrit ? Se connecter',
                style: tx(
                  14,
                  weight: FontWeight.w700,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
