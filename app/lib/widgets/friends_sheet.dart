import 'dart:async';

import 'package:flutter/material.dart';

import '../api/online.dart';
import '../models.dart';
import '../theme.dart';
import 'avatar.dart';

/// Find people by @handle or name, send requests, accept incoming ones.
Future<void> showFriendsSheet(BuildContext context, OnlineSync online) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _FriendsSheet(online: online),
  );
}

class _FriendsSheet extends StatefulWidget {
  const _FriendsSheet({required this.online});
  final OnlineSync online;

  @override
  State<_FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<_FriendsSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<({Person person, String handle})> _results = [];
  final Map<String, String> _sent = {}; // person id -> status after tapping
  bool _searching = false;

  OnlineSync get online => widget.online;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (q.trim().length < 2) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final r = await online.search(q.trim());
      if (mounted) {
        setState(() {
          _results = r;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final friendIds = online.friends.map((p) => p.id).toSet();
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Friends',
              textAlign: TextAlign.center,
              style: tx(18, weight: FontWeight.w700),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _query,
                onChanged: _onQuery,
                autofocus: online.incoming.isEmpty,
                style: tx(15),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  hintText: 'Search @handle or name',
                  hintStyle: tx(15, color: AppColors.muted),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (online.incoming.isNotEmpty && _results.isEmpty) ...[
                    _label('Requests'),
                    for (final p in online.incoming)
                      ListTile(
                        leading: PersonAvatar(p, diameter: 40),
                        title: Text(
                          p.name,
                          style: tx(15, weight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Wants to be your friend',
                          style: tx(12, color: AppColors.muted),
                        ),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                          ),
                          onPressed: () async {
                            await online.acceptFriend(p);
                            if (mounted) setState(() {});
                          },
                          child: const Text('Accept'),
                        ),
                      ),
                  ],
                  if (_results.isNotEmpty) _label('People'),
                  for (final r in _results)
                    ListTile(
                      leading: PersonAvatar(r.person, diameter: 40),
                      title: Text(
                        r.person.name,
                        style: tx(15, weight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '@${r.handle}',
                        style: tx(12, color: AppColors.muted),
                      ),
                      trailing: friendIds.contains(r.person.id)
                          ? Text(
                              'Friends',
                              style: tx(13, color: AppColors.muted),
                            )
                          : _sent.containsKey(r.person.id)
                          ? Text(
                              _sent[r.person.id] == 'friends'
                                  ? 'Friends'
                                  : 'Requested',
                              style: tx(13, color: AppColors.muted),
                            )
                          : OutlinedButton(
                              onPressed: () async {
                                final status = await online.requestFriend(
                                  r.person,
                                );
                                if (mounted) {
                                  setState(
                                    () => _sent[r.person.id] =
                                        status ?? 'requested',
                                  );
                                }
                              },
                              child: const Text('Add'),
                            ),
                    ),
                  if (_results.isEmpty && online.incoming.isEmpty) ...[
                    _label('Your friends (${online.friends.length})'),
                    if (online.friends.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Search for your friends to start chatting and playing',
                          textAlign: TextAlign.center,
                          style: tx(14, color: AppColors.muted),
                        ),
                      ),
                    for (final p in online.friends)
                      ListTile(
                        leading: PersonAvatar(p, diameter: 40),
                        title: Text(
                          p.name,
                          style: tx(15, weight: FontWeight.w500),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Text(
      text,
      style: tx(12, weight: FontWeight.w700, color: AppColors.muted),
    ),
  );
}
