import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../api/online.dart';
import '../chat_store.dart';
import '../theme.dart';

enum _Step { phone, code, name, email }

/// Sign in with a phone number (+225, SMS code) or an email.
/// Animated floating bubbles behind, each step slides in smoothly.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.store,
    required this.baseUrl,
    required this.onSignedIn,
    required this.onDemo,
  });
  final ChatStore store;
  final String baseUrl;
  final VoidCallback onSignedIn;
  final VoidCallback onDemo;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  late final _bg = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();
  late final ApiClient _api = ApiClient(widget.baseUrl);
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Step _step = _Step.phone;
  bool _register = false;
  bool _busy = false;
  String? _error;
  String? _devCode;

  @override
  void dispose() {
    _bg.dispose();
    for (final c in [_phone, _code, _name, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_Step s) => setState(() {
    _step = s;
    _error = null;
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiError catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCode() => _run(() async {
    final res = await _api.post('/auth/otp/request', {'phone': _phone.text});
    _devCode = (res as Map)['devCode'] as String?;
    _code.clear();
    _go(_Step.code);
  });

  Future<void> _verify() => _run(() async {
    try {
      final session = await _api.post('/auth/otp/verify', {
        'phone': _phone.text,
        'code': _code.text,
        if (_name.text.trim().isNotEmpty) 'displayName': _name.text.trim(),
      });
      await _signedIn(session as Map<String, dynamic>);
    } on ApiError catch (e) {
      if (e.code == 'name_required') {
        _go(_Step.name); // new account: ask the name, the code stays valid
        return;
      }
      rethrow;
    }
  });

  Future<void> _emailSignIn() => _run(() async {
    final session = _register
        ? await _api.post('/auth/register', {
            'email': _email.text.trim(),
            'password': _password.text,
            'displayName': _name.text.trim(),
          })
        : await _api.post('/auth/login', {
            'email': _email.text.trim(),
            'password': _password.text,
          });
    await _signedIn(session as Map<String, dynamic>);
  });

  Future<void> _signedIn(Map<String, dynamic> session) async {
    HapticFeedback.mediumImpact();
    await OnlineSync.fromSession(widget.store, widget.baseUrl, session);
    if (mounted) widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _bg,
                builder: (_, _) =>
                    CustomPaint(painter: _BubblesPainter(_bg.value)),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(height: 40),
                        _title(),
                        const SizedBox(height: 28),
                        _card(),
                        TextButton(
                          onPressed: widget.onDemo,
                          child: Text(
                            'Just looking? Try the demo',
                            style: tx(14, weight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - t)),
          child: child,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Challengea',
            style: tx(
              44,
              weight: FontWeight.w800,
            ).copyWith(letterSpacing: -1.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Chat, merge your bubbles, challenge your friends.',
            textAlign: TextAlign.center,
            style: tx(15, color: const Color(0xFF555555)),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(.08, 0),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey('$_step$_register'),
                child: _stepContent(),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox(height: 0, width: double.infinity)
                  : Padding(
                      key: ValueKey(_error),
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: tx(13, color: const Color(0xFFE5484D)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case _Step.phone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your phone number', style: tx(20, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'We’ll text you a 6-digit code.',
              style: tx(14, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _field(
              _phone,
              '07 00 00 00 00',
              prefix: '+225',
              keyboard: TextInputType.phone,
              autofocus: true,
              onSubmit: _requestCode,
              formatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
              ],
            ),
            const SizedBox(height: 14),
            _primary('Get my code', _requestCode),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _go(_Step.email),
              child: Text('Use an email instead', style: tx(14)),
            ),
          ],
        );
      case _Step.code:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _go(_Step.phone),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    'Enter the code',
                    style: tx(20, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Text(
              'Sent to ${_phone.text}',
              style: tx(14, color: AppColors.muted),
            ),
            if (_devCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () {
                    _code.text = _devCode!;
                    _verify();
                  },
                  child: Text(
                    'Test server: your code is $_devCode (tap to fill)',
                    style: tx(
                      12,
                      weight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _CodeInput(controller: _code, onComplete: _verify),
            const SizedBox(height: 14),
            _primary('Continue', _verify),
            TextButton(
              onPressed: _requestCode,
              child: Text('Send a new code', style: tx(14)),
            ),
          ],
        );
      case _Step.name:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome! What’s your name?',
              style: tx(20, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Your friends will see it on your bubble.',
              style: tx(14, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _field(_name, 'Your name', autofocus: true, onSubmit: _verify),
            const SizedBox(height: 14),
            _primary('Create my account', _verify),
          ],
        );
      case _Step.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _go(_Step.phone),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    _register ? 'Create an account' : 'Sign in with email',
                    style: tx(20, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_register) ...[
              _field(_name, 'Your name'),
              const SizedBox(height: 10),
            ],
            _field(_email, 'Email', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _field(
              _password,
              'Password (6+ characters)',
              obscure: true,
              onSubmit: _emailSignIn,
            ),
            const SizedBox(height: 14),
            _primary(_register ? 'Create my account' : 'Sign in', _emailSignIn),
            TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(
                _register
                    ? 'I already have an account'
                    : 'New here? Create an account',
                style: tx(14),
              ),
            ),
          ],
        );
    }
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    String? prefix,
    TextInputType? keyboard,
    bool obscure = false,
    bool autofocus = false,
    VoidCallback? onSubmit,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      obscureText: obscure,
      autofocus: autofocus,
      inputFormatters: formatters,
      onSubmitted: (_) => onSubmit?.call(),
      style: tx(17),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: tx(17, color: AppColors.muted),
        filled: true,
        fillColor: const Color(0xFFF3F3F3),
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Center(
                  widthFactor: 1,
                  child: Text(prefix, style: tx(17, weight: FontWeight.w700)),
                ),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
    );
  }

  Widget _primary(String label, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: _busy ? null : onTap,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _busy
              ? const SizedBox(
                  key: ValueKey('busy'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  key: ValueKey(label),
                  style: tx(16, weight: FontWeight.w700, color: Colors.white),
                ),
        ),
      ),
    );
  }
}

/// Six boxes for the SMS code; sends automatically when complete.
class _CodeInput extends StatefulWidget {
  const _CodeInput({required this.controller, required this.onComplete});
  final TextEditingController controller;
  final VoidCallback onComplete;

  @override
  State<_CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<_CodeInput> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (v) {
                setState(() {});
                HapticFeedback.selectionClick();
                if (v.length == 6) widget.onComplete();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 6; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 46,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < code.length
                        ? AppColors.ink
                        : const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: i == code.length
                          ? AppColors.ink
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: AnimatedScale(
                    scale: i < code.length ? 1 : .4,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Text(
                      i < code.length ? code[i] : '',
                      style: tx(
                        24,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft colored bubbles drifting behind the sign-in card.
class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.t);
  final double t;

  static const _colors = [
    Color(0xFFFF8A3D),
    Color(0xFFF06BA8),
    Color(0xFF4FB3F6),
    Color(0xFF5CC98A),
    Color(0xFF8B6CF6),
    Color(0xFFFFC53D),
    Color(0xFFB07A4F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(3);
    for (var i = 0; i < 14; i++) {
      final speed = .5 + rnd.nextDouble();
      final a = 2 * pi * (t * speed + rnd.nextDouble());
      final base = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height * .62,
      );
      final c = base + Offset(cos(a) * 22, sin(a * 1.3) * 26);
      final r = 22 + rnd.nextDouble() * 46;
      final color = _colors[i % _colors.length];
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .55),
              color.withValues(alpha: .18),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => old.t != t;
}
