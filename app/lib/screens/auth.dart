import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import 'chat_home.dart';

enum AuthMode { signUp, login }

enum _Step { choose, phone, otp, email }

/// Figma: LOGIN frame 84:321 ("S'inscrire" sheet with phone / email).
/// The phone, code and email steps follow the same sheet style.
/// Demo only: any 6-digit code works; the backend will send real SMS codes.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store, required this.mode});
  final ChatStore store;
  final AuthMode mode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _Step _step = _Step.choose;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  bool get _signUp => widget.mode == AuthMode.signUp;
  String get _title => _signUp ? 'S’inscrire' : 'Se connecter';

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _phone, _code, _email, _password]) {
      c.addListener(() => setState(() => _error = null));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _code, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (_step == _Step.choose) {
      Navigator.pop(context);
    } else {
      setState(() => _step = _step == _Step.otp ? _Step.phone : _Step.choose);
    }
  }

  void _continue() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_step == _Step.phone) {
      setState(() => _step = _Step.otp);
    } else if (_step != _Step.choose) {
      _finish();
    }
  }

  String? _validate() {
    final needsName = _signUp && (_step == _Step.phone || _step == _Step.email);
    if (needsName && _name.text.trim().length < 2) return 'Entrez votre nom';
    return switch (_step) {
      _Step.phone when _phone.text.length != 10 =>
        'Le numéro doit avoir 10 chiffres',
      _Step.otp when _code.text.length != 6 =>
        'Entrez les 6 chiffres reçus par SMS',
      _Step.email
          when !RegExp(
            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
          ).hasMatch(_email.text.trim()) =>
        'Adresse email invalide',
      _Step.email when _password.text.length < 6 => 'Au moins 6 caractères',
      _ => null,
    };
  }

  void _finish() {
    if (_signUp) widget.store.setMyName(_name.text);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => ChatHome(store: widget.store)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: _back,
                icon: const Icon(Icons.chevron_left, size: 30),
              ),
            ),
            const Expanded(child: Center(child: NteriLogo(size: 44))),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: tx(28, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 24),
                    ..._stepContent(),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: tx(13, color: Colors.redAccent),
                      ),
                    ],
                    if (_step != _Step.choose) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _continue,
                          child: Text(
                            _step == _Step.phone
                                ? 'Recevoir le code'
                                : 'Continuer',
                            style: tx(
                              16,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stepContent() {
    switch (_step) {
      case _Step.choose:
        return [
          _choice(
            'Numéro de téléphone',
            Icons.phone_iphone_rounded,
            () => setState(() => _step = _Step.phone),
          ),
          const SizedBox(height: 12),
          _choice(
            'Adresse Email',
            Icons.alternate_email_rounded,
            () => setState(() => _step = _Step.email),
          ),
          const SizedBox(height: 24),
        ];
      case _Step.phone:
        return [
          if (_signUp) ...[
            _field(_name, 'Votre nom', Icons.person_outline),
            const SizedBox(height: 12),
          ],
          _field(
            _phone,
            '07 00 00 00 00',
            null,
            prefix: '+225',
            keyboard: TextInputType.phone,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
        ];
      case _Step.otp:
        return [
          Text(
            'Code envoyé au +225 ${_phone.text}',
            textAlign: TextAlign.center,
            style: tx(14),
          ),
          const SizedBox(height: 4),
          Text(
            'Démo : tapez n’importe quels 6 chiffres',
            textAlign: TextAlign.center,
            style: tx(12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          _CodeBoxes(controller: _code, onDone: _continue),
        ];
      case _Step.email:
        return [
          if (_signUp) ...[
            _field(_name, 'Votre nom', Icons.person_outline),
            const SizedBox(height: 12),
          ],
          _field(
            _email,
            'Adresse email',
            Icons.alternate_email_rounded,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _field(_password, 'Mot de passe', Icons.lock_outline, obscure: true),
        ];
    }
  }

  Widget _choice(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: tx(
                    17,
                    weight: FontWeight.w700,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    IconData? icon, {
    String? prefix,
    bool obscure = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      inputFormatters: formatters,
      onSubmitted: (_) => _continue(),
      style: tx(16),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: tx(16, color: AppColors.muted),
        prefixIcon: prefix != null
            ? Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Center(
                  widthFactor: 1,
                  child: Text(prefix, style: tx(16, weight: FontWeight.w700)),
                ),
              )
            : (icon != null ? Icon(icon) : null),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Six boxes backed by one hidden text field.
class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes({required this.controller, required this.onDone});
  final TextEditingController controller;
  final VoidCallback onDone;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
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
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (v) {
                setState(() {});
                if (v.length == 6) widget.onDone();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  width: 46,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i == code.length
                          ? AppColors.ink
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    i < code.length ? code[i] : '',
                    style: tx(22, weight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
