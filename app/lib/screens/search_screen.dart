import 'dart:async';

import 'package:flutter/material.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../feed.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import '../widgets/moments.dart';
import '../widgets/motion.dart';
import 'post_screen.dart';
import 'profile_screen.dart';

/// Find people and posts.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.store});
  final ChatStore store;

  static Future<void> open(BuildContext context, ChatStore store) =>
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SearchScreen(store: store)));

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _input = TextEditingController();
  Timer? _wait;
  bool _busy = false;
  String _done = ''; // the query the results below belong to
  List<({Person person, String handle})> _people = [];
  List<Post> _posts = [];
  final Set<String> _requested = {};

  ChatStore get store => widget.store;

  @override
  void dispose() {
    _wait?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _wait?.cancel();
    setState(() {});
    _wait = Timer(const Duration(milliseconds: 300), () => _run(q.trim()));
  }

  Future<void> _run(String q) async {
    if (q.isEmpty) {
      setState(() {
        _done = '';
        _people = [];
        _posts = [];
      });
      return;
    }
    setState(() => _busy = true);
    final online = store.online;
    final List<({Person person, String handle})> people;
    final List<Post> posts;
    if (online != null) {
      people = await online.search(q);
      posts = await online.searchPosts(q);
    } else {
      final low = q.toLowerCase();
      people = [
        for (final p in store.friends)
          if (p.name.toLowerCase().contains(low))
            (person: p, handle: store.feed.creatorFor(p).handle),
      ];
      posts = store.feed.home
          .where((p) => p.caption.toLowerCase().contains(low))
          .toList();
    }
    // A slower, older search must not replace a newer one.
    if (!mounted || q != _input.text.trim()) return;
    setState(() {
      _busy = false;
      _done = q;
      _people = people;
      _posts = posts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final empty = _done.isNotEmpty && _people.isEmpty && _posts.isEmpty;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 8, 12, 8),
            child: Row(
              children: [
                Glass(
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
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _input,
                    autofocus: true,
                    onChanged: _changed,
                    textInputAction: TextInputAction.search,
                    style: tx(17),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'People and posts',
                      hintStyle: tx(17, color: AppColors.muted),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.muted,
                      ),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: _busy ? 1 : 0,
            duration: Motion.fast,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.accent,
              backgroundColor: Colors.transparent,
            ),
          ),
          Expanded(
            child: _input.text.trim().isEmpty
                ? _hint('Search for a name, a @handle or words in a post.')
                : empty
                ? _hint('Nothing for “$_done”.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (_people.isNotEmpty) ...[
                        _title('People'),
                        for (var i = 0; i < _people.length; i++)
                          FadeSlideIn(
                            key: ValueKey(_people[i].person.id),
                            delay: Duration(milliseconds: 30 * i),
                            child: _person(_people[i]),
                          ),
                      ],
                      if (_posts.isNotEmpty) ...[
                        _title('Posts'),
                        for (var i = 0; i < _posts.length; i++)
                          FadeSlideIn(
                            key: ValueKey(_posts[i].id),
                            delay: Duration(milliseconds: 30 * i),
                            child: _post(_posts[i]),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _hint(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tx(17, color: AppColors.muted),
      ),
    ),
  );

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
    child: Text(text, style: tx(20, weight: FontWeight.w600)),
  );

  Widget _person(({Person person, String handle}) r) {
    final online = store.online;
    final isFriend = store.friends.any((f) => f.id == r.person.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Pressable(
        scale: .98,
        onTap: () =>
            ProfileScreen.open(context, store, store.feed.creatorFor(r.person)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              PersonAvatar(r.person, diameter: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx(17, weight: FontWeight.w600),
                    ),
                    Text(
                      '@${r.handle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx(15, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (online != null && !isFriend)
                MorphButton(
                  key: ValueKey('add-${r.person.id}'),
                  label: 'Add',
                  doneLabel: 'Requested',
                  width: 76,
                  startDone: _requested.contains(r.person.id),
                  onPressed: () async {
                    final ok = await _request(online, r.person);
                    if (ok) _requested.add(r.person.id);
                    return ok;
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _request(OnlineSync online, Person p) async =>
      await online.requestFriend(p) != null;

  Widget _post(Post p) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Pressable(
      scale: .98,
      onTap: () => PostScreen.open(context, store, p),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            PersonAvatar(p.author.person, diameter: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.author.person.name} · ${p.ago}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx(14, color: AppColors.muted),
                  ),
                  Text(
                    p.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tx(16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
