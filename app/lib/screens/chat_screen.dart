import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'call_screen.dart';

/// Figma: conversation frame (node 7:21). Works for 1-to-1 and group chats.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.store, required this.node});
  final ChatStore store;
  final BubbleNode node;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  BubbleNode get node => widget.node;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.store.send(node, text);
    _input.clear();
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$what: coming in the next step',
            style: tx(14, color: Colors.white),
          ),
        ),
      );
  }

  void _startCall({bool video = false}) {
    final call = widget.store.startCall(
      node.members,
      groupName: node.isGroup ? node.displayName : null,
      video: video,
    );
    CallScreen.open(context, widget.store, call);
  }

  String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')}${t.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => Row(
            children: [
              node.isGroup
                  ? GroupAvatar(node.members, diameter: 38)
                  : PersonAvatar(node.members.first, diameter: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.displayName,
                      style: tx(16, weight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      node.isGroup
                          ? '${node.members.length} members · ${node.members.map((m) => m.firstName).join(', ')}'
                          : (node.members.first.online ? 'online' : 'offline'),
                      style: tx(11, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _startCall(video: true),
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(
            onPressed: () => _startCall(),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) {
                final msgs = node.messages.reversed.toList();
                if (msgs.isEmpty) {
                  return Center(
                    child: Text(
                      node.isGroup
                          ? 'New group! Say hi to everyone'
                          : 'Say hi to ${node.displayName}',
                      style: tx(14, color: AppColors.muted),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) => _bubble(msgs[i]),
                );
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _bubble(Message m) {
    final mine = m.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .72,
          minWidth: 120,
        ),
        margin: EdgeInsets.only(
          bottom: 10,
          left: mine ? 40 : 0,
          right: mine ? 0 : 40,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.sent : AppColors.received,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (node.isGroup && !mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  m.sender!.name,
                  style: tx(
                    12,
                    weight: FontWeight.w700,
                    color: m.sender!.color,
                  ),
                ),
              ),
            Text(m.text, style: tx(14)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_time(m.time), style: tx(10, color: AppColors.muted)),
                  if (mine) ...[
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.done_all,
                      size: 13,
                      color: AppColors.online,
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

  Widget _composer() {
    final hasText = _input.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _soon('Stickers'),
              icon: const Icon(Icons.sticky_note_2_outlined),
            ),
            Expanded(
              child: TextField(
                controller: _input,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: tx(15),
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: tx(15, color: AppColors.muted),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (hasText)
              IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send_rounded, color: AppColors.accent),
              )
            else ...[
              IconButton(
                onPressed: () => _soon('Files'),
                icon: const Icon(Icons.attach_file),
              ),
              IconButton(
                onPressed: () => _soon('Camera'),
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                onPressed: () => _soon('Voice note'),
                icon: const Icon(Icons.mic_none_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
