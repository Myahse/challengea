import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../feed.dart';
import '../models.dart';
import '../screens/profile_screen.dart';
import '../theme.dart';
import 'avatar.dart';
import 'motion.dart';

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text, style: tx(14, color: Colors.white)),
      ),
    );
}

/// Pick friends and send them something in their chat.
Future<void> showSendTo(
  BuildContext context,
  ChatStore store, {
  required String text,
  String title = 'Send to',
}) {
  final friends = store.friends.toList();
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Text(title, style: tx(28, weight: FontWeight.w600)),
          ),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: Text(
                'Add a friend first.',
                style: tx(16, color: AppColors.muted),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < friends.length; i++)
                    FadeSlideIn(
                      delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                      offset: const Offset(24, 0),
                      child: Pressable(
                        onTap: () {
                          final p = friends[i];
                          Navigator.pop(ctx);
                          store.send(store.nodeFor(p), text);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sent to ${p.firstName}',
                                style: tx(14, color: Colors.white),
                              ),
                            ),
                          );
                        },
                        child: SizedBox(
                          width: 80,
                          child: Column(
                            children: [
                              PersonAvatar(friends[i], diameter: 58),
                              const SizedBox(height: 6),
                              Text(
                                friends[i].firstName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tx(13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

/// What the ⋯ of a post offers. Mine: edit and delete. Others': hide, report,
/// follow. The way back from a post that goes away is [onGone].
Future<void> showPostOptions(
  BuildContext context,
  ChatStore store,
  Post post, {
  VoidCallback? onGone,
}) {
  final feed = store.feed;
  final a = post.author;
  Widget row(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback action, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.ink),
      title: Text(label, style: tx(17, color: color)),
      onTap: () {
        Navigator.pop(ctx);
        action();
      },
    );
  }

  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.isMe)
            row(
              ctx,
              Icons.edit_outlined,
              'Edit post',
              () => _editPost(context, feed, post),
            ),
          if (post.caption.isNotEmpty)
            row(ctx, Icons.copy_rounded, 'Copy text', () {
              Clipboard.setData(ClipboardData(text: post.caption));
              _say(context, 'Copied');
            }),
          row(
            ctx,
            Icons.send_outlined,
            'Send to a friend',
            () => showSendTo(
              context,
              store,
              text:
                  '📎 ${a.person.firstName}’s post: ${post.caption.isEmpty ? 'a photo' : post.caption}',
            ),
          ),
          if (!a.isMe) ...[
            row(
              ctx,
              Icons.person_outline_rounded,
              'View ${a.person.firstName}’s profile',
              () => ProfileScreen.open(context, store, a),
            ),
            row(
              ctx,
              a.followed
                  ? Icons.person_remove_outlined
                  : Icons.person_add_alt_1_outlined,
              a.followed
                  ? 'Unfollow ${a.person.firstName}'
                  : 'Follow ${a.person.firstName}',
              () => feed.toggleFollow(a),
            ),
            row(ctx, Icons.visibility_off_outlined, 'Hide this post', () {
              feed.hidePost(post);
              onGone?.call();
              _say(context, 'You won’t see this post again');
            }),
            row(
              ctx,
              Icons.flag_outlined,
              'Report',
              () => _reportPost(context, feed, post, onGone),
              color: AppColors.danger,
            ),
          ],
          if (a.isMe)
            row(
              ctx,
              Icons.delete_outline_rounded,
              'Delete post',
              () => _deletePost(context, feed, post, onGone),
              color: AppColors.danger,
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _editPost(BuildContext context, FeedData feed, Post post) {
  final text = TextEditingController(text: post.caption);
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
          Text('Edit post', style: tx(28, weight: FontWeight.w600)),
          const SizedBox(height: 14),
          TextField(
            controller: text,
            autofocus: true,
            maxLines: 5,
            minLines: 2,
            maxLength: post.textCard ? 120 : 4000,
            style: tx(17),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.page,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () {
              final value = text.text.trim();
              if (value.isEmpty && post.image == null) return;
              Navigator.pop(ctx);
              feed.editPost(post, value);
            },
            child: Text('Save', style: tx(17, color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

Future<void> _deletePost(
  BuildContext context,
  FeedData feed,
  Post post,
  VoidCallback? onGone,
) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete this post?', style: tx(24, weight: FontWeight.w600)),
      content: Text(
        'Its reactions and comments go with it. This can’t be undone.',
        style: tx(16, color: AppColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Keep', style: tx(16, color: AppColors.link)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: tx(16, color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (sure != true) return;
  feed.deletePost(post);
  onGone?.call();
}

void _reportPost(
  BuildContext context,
  FeedData feed,
  Post post,
  VoidCallback? onGone,
) {
  const reasons = {
    'spam': 'Spam',
    'harassment': 'Bullying or harassment',
    'violence': 'Violence or threats',
    'nudity': 'Nudity',
    'other': 'Something else',
  };
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
            child: Text(
              'Why are you reporting this?',
              style: tx(24, weight: FontWeight.w600),
            ),
          ),
          for (final r in reasons.entries)
            ListTile(
              title: Text(r.value, style: tx(17)),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
              onTap: () {
                Navigator.pop(ctx);
                feed.reportPost(post, r.key);
                onGone?.call();
                _say(context, 'Thanks. This post is now hidden for you.');
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// The text someone sends to invite a friend to my profile.
String profileShareText(Person me, String handle) =>
    'Find me on Challengea: @$handle';
