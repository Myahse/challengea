import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/friends_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import 'profile_screen.dart';

/// Change my name and bio.
void showEditProfile(
  BuildContext context,
  ChatStore store, {
  VoidCallback? onSaved,
}) {
  void snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text, style: tx(14, color: Colors.white)),
      ),
    );

  final online = store.online;
  if (online == null) {
    snack('Sign in to edit your profile (this is the demo)');
    return;
  }
  final me = store.feed.me;
  final name = TextEditingController(text: me.person.name);
  final bio = TextEditingController(text: me.bio);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        20 + MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit profile', style: tx(28, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            style: tx(17),
            textCapitalization: TextCapitalization.words,
            decoration: _field('Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: bio,
            style: tx(17),
            maxLines: 3,
            maxLength: 500,
            decoration: _field('Bio'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () async {
              final newName = name.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await online.api.patch('/me', {
                  'displayName': newName,
                  'bio': bio.text.trim(),
                });
                store.setMyName(newName);
                me.bio = bio.text.trim();
                store.feed.notifyChanged();
                onSaved?.call();
                if (context.mounted) snack('Profile saved');
              } catch (e) {
                if (context.mounted) snack('$e');
              }
            },
            child: Text('Save', style: tx(17, color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

InputDecoration _field(String label) => InputDecoration(
  labelText: label,
  labelStyle: tx(16, color: AppColors.muted),
  filled: true,
  fillColor: AppColors.page,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  ),
);

/// My account: profile, friends, privacy, appearance and signing out.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.store});
  final ChatStore store;

  static Future<void> open(BuildContext context, ChatStore store) =>
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AccountScreen(store: store)));

  Future<void> _signOut(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign out?', style: tx(24, weight: FontWeight.w600)),
        content: Text(
          'Your chats and posts stay saved on your account.',
          style: tx(16, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay', style: tx(16, color: AppColors.link)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: tx(16, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (sure == true && context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      store.onSignOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.page,
      body: ListenableBuilder(
        listenable: Listenable.merge([store, store.feed]),
        builder: (context, _) {
          final me = store.feed.me;
          final online = store.online;
          final requests = online?.incoming.length ?? 0;
          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(12, top + 68, 12, bottom + 32),
                children: [
                  FadeSlideIn(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                      child: Text(
                        'Account',
                        style: tx(44, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: _Group(
                      children: [
                        _Row(
                          height: 88,
                          leading: PersonAvatar(store.me, diameter: 60),
                          title: me.person.name,
                          subtitle: '@${me.handle}',
                          onTap: () => ProfileScreen.open(context, store, me),
                        ),
                        _Row(
                          title: 'Edit profile',
                          onTap: () => showEditProfile(context, store),
                        ),
                      ],
                    ),
                  ),
                  if (online != null)
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: _Group(
                        children: [
                          _Row(
                            title: 'Friends and requests',
                            value: requests > 0 ? '$requests new' : null,
                            onTap: () => showFriendsSheet(context, online),
                          ),
                        ],
                      ),
                    ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: _Group(
                      title: 'Privacy',
                      children: [
                        _Toggle(
                          title: 'Ghost mode',
                          subtitle: 'Friends can’t see where you are',
                          value: store.ghostMode,
                          onChanged: store.setGhostMode,
                        ),
                        _Toggle(
                          title: 'Show offline friends',
                          subtitle: 'With their last known place on the map',
                          value: store.showOffline,
                          onChanged: store.setShowOffline,
                        ),
                      ],
                    ),
                  ),
                  const FadeSlideIn(
                    delay: Duration(milliseconds: 240),
                    child: _Group(
                      title: 'Appearance',
                      children: [_ThemePicker()],
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: _Group(
                      children: [
                        _Row(
                          title: online != null ? 'Sign out' : 'Sign in',
                          color: online != null
                              ? AppColors.danger
                              : AppColors.link,
                          chevron: false,
                          onTap: () => online != null
                              ? _signOut(context)
                              : store.onSignOut?.call(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Challengea 0.1.0',
                      textAlign: TextAlign.center,
                      style: tx(13, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 12,
                top: top + 8,
                child: Glass(
                  radius: 24,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A rounded group of rows, with hairlines between them.
class _Group extends StatelessWidget {
  const _Group({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(title!, style: tx(20, weight: FontWeight.w600)),
            ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 18,
                      color: AppColors.line.withValues(alpha: .6),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.leading,
    this.color,
    this.chevron = true,
    this.height = 56,
  });
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? leading;
  final Color? color;
  final bool chevron;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx(
                          leading != null ? 22 : 17,
                          weight: leading != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: color,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx(15, color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(value!, style: tx(16, color: AppColors.link)),
                  ),
                if (chevron)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tx(17)),
                Text(subtitle, style: tx(14, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            activeTrackColor: AppColors.accent,
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Follow the phone, or always light, or always dark.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  static const _labels = {
    ThemeChoice.system: 'Device',
    ThemeChoice.light: 'Light',
    ThemeChoice.dark: 'Dark',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ValueListenableBuilder(
        valueListenable: FollowDeviceTheme.choice,
        builder: (context, choice, _) => Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.bubble,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (final c in ThemeChoice.values)
                Expanded(
                  child: Pressable(
                    onTap: () => FollowDeviceTheme.choose(c),
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c == choice ? AppColors.card : null,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        _labels[c]!,
                        style: tx(
                          15,
                          weight: c == choice
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
