import 'package:flutter/material.dart';

import '../feed.dart';
import '../theme.dart';
import 'avatar.dart';

Future<void> showComments(BuildContext context, FeedData feed, Post post) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentsSheet(feed: feed, post: post),
  );
}

/// The same conversation as a whole page, under a [header].
class CommentsPage extends StatelessWidget {
  const CommentsPage({
    super.key,
    required this.feed,
    required this.post,
    required this.header,
    required this.top,
  });
  final FeedData feed;
  final Post post;
  final Widget header;
  final double top;

  @override
  Widget build(BuildContext context) =>
      _CommentsSheet(feed: feed, post: post, header: header, top: top);
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.feed,
    required this.post,
    this.header,
    this.top = 0,
  });
  final FeedData feed;
  final Post post;
  final Widget? header;
  final double top;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final Set<Comment> _translated = {};
  final Set<Comment> _expanded = {};
  Comment? _replyTo;

  @override
  void initState() {
    super.initState();
    widget.feed.loadComments(widget.post);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.feed.addComment(widget.post, text, replyTo: _replyTo);
    if (_replyTo != null) _expanded.add(_replyTo!);
    _input.clear();
    setState(() => _replyTo = null);
  }

  void _reply(Comment c) {
    setState(() => _replyTo = c);
    _focus.requestFocus();
  }

  Widget _pageBody() => ListenableBuilder(
    listenable: widget.feed,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, widget.top, 0, 12),
            children: [
              widget.header!,
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
                child: Text(
                  widget.post.comments.isEmpty
                      ? 'No comments yet.'
                      : 'Comments',
                  style: tx(22, weight: FontWeight.w600),
                ),
              ),
              for (final c in widget.post.comments) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _comment(c),
                ),
                if (c.moreReplies > 0 || c.replies.isNotEmpty)
                  _repliesToggle(c),
                if (_expanded.contains(c))
                  for (final r in c.replies)
                    Padding(
                      padding: const EdgeInsets.only(left: 72, right: 10),
                      child: _comment(r),
                    ),
              ],
            ],
          ),
        ),
        ColoredBox(
          color: AppColors.card,
          child: SafeArea(top: false, child: _composer()),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.header != null) return _pageBody();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: .66,
        minChildSize: .3,
        maxChildSize: .92,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: ListenableBuilder(
            listenable: widget.feed,
            builder: (context, _) => Column(
              children: [
                const SizedBox(height: 14),
                Text('Comments', style: tx(15, weight: FontWeight.w700)),
                Text(
                  '${compact(widget.post.commentCount)} comments',
                  style: tx(11, color: AppColors.muted),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    children: [
                      for (final c in widget.post.comments) ...[
                        _comment(c),
                        if (c.moreReplies > 0 || c.replies.isNotEmpty)
                          _repliesToggle(c),
                        if (_expanded.contains(c))
                          for (final r in c.replies)
                            Padding(
                              padding: const EdgeInsets.only(left: 62),
                              child: _comment(r),
                            ),
                      ],
                    ],
                  ),
                ),
                _composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _repliesToggle(Comment c) {
    final open = _expanded.contains(c);
    final n = c.replies.length + c.moreReplies;
    return Padding(
      padding: const EdgeInsets.only(left: 88, bottom: 10),
      child: GestureDetector(
        onTap: () =>
            setState(() => open ? _expanded.remove(c) : _expanded.add(c)),
        child: Text(
          open
              ? 'Hide replies'
              : 'View $n more ${n == 1 ? 'reply' : 'replies'}',
          style: tx(11, weight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _comment(Comment c) {
    final translated = _translated.contains(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bubble,
            ),
            child: PersonAvatar(c.author, diameter: 44),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: c.author.name,
                        style: tx(15, weight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  ${c.ago}',
                        style: tx(13, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (c.hasImage)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          c.author.color.withValues(alpha: .4),
                          c.author.color,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: Colors.white,
                    ),
                  ),
                Text(
                  translated && c.translation != null ? c.translation! : c.text,
                  style: tx(15),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _reply(c),
                      child: Text(
                        'Reply',
                        style: tx(13, color: AppColors.link),
                      ),
                    ),
                    if (c.translation != null) ...[
                      const SizedBox(width: 30),
                      GestureDetector(
                        onTap: () => setState(
                          () => translated
                              ? _translated.remove(c)
                              : _translated.add(c),
                        ),
                        child: Text(
                          translated ? 'See original' : 'See translation',
                          style: tx(13, color: AppColors.link),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => widget.feed.toggleCommentLike(c),
            child: Row(
              children: [
                Icon(
                  c.liked ? Icons.favorite : Icons.favorite_border,
                  size: 22,
                  color: c.liked ? AppColors.danger : AppColors.ink,
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 36,
                  child: Text(compact(c.likes), style: tx(10)),
                ),
              ],
            ),
          ),
          const Icon(Icons.send_outlined, size: 22),
          const SizedBox(width: 10),
          const Icon(Icons.repeat_rounded, size: 22),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      'Replying to ${_replyTo!.author.firstName}',
                      style: tx(12, color: AppColors.muted),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _replyTo = null),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: tx(14),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.page,
                      hintText: 'Add a comment…',
                      hintStyle: tx(14, color: AppColors.muted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _send,
                  icon: Icon(Icons.send_rounded, color: AppColors.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
