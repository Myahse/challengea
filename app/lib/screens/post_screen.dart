import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../feed.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/glass.dart';
import 'home_feed.dart';

/// One post with its whole conversation under it.
class PostScreen extends StatelessWidget {
  const PostScreen({super.key, required this.store, required this.post});
  final ChatStore store;
  final Post post;

  static Future<void> open(BuildContext context, ChatStore store, Post post) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostScreen(store: store, post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: CommentsPage(
              feed: store.feed,
              post: post,
              top: top + 64,
              header: ListenableBuilder(
                listenable: store.feed,
                builder: (context, _) => PostCard(
                  store: store,
                  post: post,
                  inScreen: true,
                  onGone: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: top + 8,
            child: Glass(
              radius: 24,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
