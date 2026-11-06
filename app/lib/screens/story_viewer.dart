import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../stories.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/motion.dart';

/// Full-screen stories, Snapchat / WhatsApp style.
/// Tap right = next, tap left = back, hold = pause, swipe = next person,
/// swipe down = close. Replies go to that friend's chat.
class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.store,
    required this.stories,
    required this.start,
  });
  final ChatStore store;
  final List<Story> stories;
  final int start;

  static Future<void> open(
    BuildContext context,
    ChatStore store,
    List<Story> stories,
    int start,
  ) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: Motion.normal,
        reverseTransitionDuration: Motion.normal,
        pageBuilder: (_, a, _) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(
              begin: .92,
              end: 1.0,
            ).animate(CurvedAnimation(parent: a, curve: Motion.ease)),
            child: StoryViewer(store: store, stories: stories, start: start),
          ),
        ),
      ),
    );
  }

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late final _pages = PageController(initialPage: widget.start);
  late int _page = widget.start;
  double _drag = 0; // swipe-down distance

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < widget.stories.length - 1) {
      _pages.nextPage(duration: Motion.normal, curve: Motion.ease);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previous() {
    if (_page > 0) {
      _pages.previousPage(duration: Motion.normal, curve: Motion.ease);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = (_drag / 400).clamp(0.0, 1.0);
    return GestureDetector(
      onVerticalDragUpdate: (d) =>
          setState(() => _drag = (_drag + d.delta.dy).clamp(0, 600)),
      onVerticalDragEnd: (d) {
        if (_drag > 120 || (d.primaryVelocity ?? 0) > 600) {
          Navigator.of(context).pop();
        } else {
          setState(() => _drag = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Transform.scale(
          scale: 1 - .15 * t,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28 * t),
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.stories.length,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, i) => _StoryPage(
                key: ValueKey(widget.stories[i]),
                store: widget.store,
                story: widget.stories[i],
                active: i == _page,
                onDone: _next,
                onBack: _previous,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryPage extends StatefulWidget {
  const _StoryPage({
    super.key,
    required this.store,
    required this.story,
    required this.active,
    required this.onDone,
    required this.onBack,
  });
  final ChatStore store;
  final Story story;
  final bool active;
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage>
    with SingleTickerProviderStateMixin {
  late final _timer =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _forward();
        });
  final _reply = TextEditingController();
  final _focus = FocusNode();
  int _index = 0;

  Story get story => widget.story;
  bool get _mine => story.person.id == widget.store.me.id;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => _focus.hasFocus ? _timer.stop() : _resume());
    _sync();
  }

  @override
  void didUpdateWidget(_StoryPage old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && story.items.isNotEmpty) {
      widget.store.markStorySeen(story);
      if (!_timer.isAnimating && !_focus.hasFocus) _timer.forward();
    } else {
      _timer.stop();
    }
  }

  void _resume() {
    if (widget.active && !_focus.hasFocus) _timer.forward();
  }

  void _forward() {
    if (_index < story.items.length - 1) {
      setState(() => _index++);
      _timer.forward(from: 0);
    } else {
      widget.onDone();
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
      _timer.forward(from: 0);
    } else {
      widget.onBack();
    }
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final node = widget.store.nodeFor(story.person);
    widget.store.send(node, '↩️ Replied to your story: $text');
    _reply.clear();
    _focus.unfocus();
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Sent to ${story.person.firstName}',
            style: tx(14, color: Colors.white),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _timer.dispose();
    _reply.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (story.items.isEmpty) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Text('No story yet', style: tx(16, color: Colors.white70)),
      );
    }
    final item = story.items[_index];
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // The slide.
          Positioned.fill(
            child: GestureDetector(
              onTapUp: (d) =>
                  d.localPosition.dx < MediaQuery.sizeOf(context).width / 3
                  ? _back()
                  : _forward(),
              onLongPressStart: (_) => _timer.stop(),
              onLongPressEnd: (_) => _resume(),
              child: AnimatedSwitcher(
                duration: Motion.normal,
                child: KeyedSubtree(key: ValueKey(item), child: _slide(item)),
              ),
            ),
          ),
          // Progress bars + who.
          Positioned(
            left: 10,
            right: 10,
            top: top + 8,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) => Row(
                    children: [
                      for (var i = 0; i < story.items.length; i++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: i < _index
                                  ? 1
                                  : (i == _index ? _timer.value : 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    PersonAvatar(story.person, diameter: 36, border: 1.5),
                    const SizedBox(width: 10),
                    Text(
                      _mine ? 'Your story' : story.person.name,
                      style: tx(
                        15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(item.ago, style: tx(13, color: Colors.white70)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Reply (not on my own story).
          if (!_mine)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final e in const ['😂', '😍', '🔥', '👏', '😮'])
                            Pressable(
                              scale: .7,
                              onTap: () => _send(e),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 30),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reply,
                        focusNode: _focus,
                        onSubmitted: _send,
                        style: tx(15, color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: 'Reply to ${story.person.firstName}…',
                          hintStyle: tx(15, color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white12,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(color: Colors.white38),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(color: Colors.white38),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => _send(_reply.text),
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slide(StoryItem item) {
    if (item.photo != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(item.photo!, fit: BoxFit.cover),
          if (item.text != null) _caption(item.text!),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.colors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.emoji != null)
                FadeSlideIn(
                  scale: .4,
                  offset: Offset.zero,
                  child: Text(
                    item.emoji!,
                    style: const TextStyle(fontSize: 110),
                  ),
                ),
              if (item.text != null) ...[
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Text(
                    item.text!,
                    textAlign: TextAlign.center,
                    style: tx(28, weight: FontWeight.w800, color: Colors.white)
                        .copyWith(
                          shadows: const [
                            Shadow(color: Colors.black26, blurRadius: 12),
                          ],
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _caption(String text) => Align(
    alignment: const Alignment(0, .55),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tx(18, weight: FontWeight.w700, color: Colors.white),
      ),
    ),
  );
}
