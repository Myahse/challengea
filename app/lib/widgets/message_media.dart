import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models.dart';
import '../theme.dart';
import 'motion.dart';

// ------------------------------------------------------------------ photos
/// A photo in the chat. Tap to open it full screen (pinch to zoom).
class ImageBubble extends StatelessWidget {
  const ImageBubble({super.key, required this.message, required this.mine});
  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * .64;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Pressable(
        scale: .97,
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black,
            transitionDuration: Motion.normal,
            reverseTransitionDuration: Motion.normal,
            pageBuilder: (_, a, _) => FadeTransition(
              opacity: a,
              child: _Viewer(message: message),
            ),
          ),
        ),
        child: Hero(
          tag: message,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            constraints: BoxConstraints(
              maxWidth: maxW,
              maxHeight: maxW * 1.3,
              minWidth: 120,
              minHeight: 90,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.bubble,
              border: Border.all(
                color: mine ? AppColors.sent : Colors.white,
                width: 3,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                messageImage(message, fit: BoxFit.cover),
                if (message.serverId == null &&
                    message.mediaUrl == null &&
                    message.localBytes != null &&
                    message.sender == null)
                  const Positioned(right: 8, bottom: 8, child: _Sending()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The picture of a message: the local bytes first (no flicker), else the URL.
Widget messageImage(Message m, {BoxFit fit = BoxFit.cover}) {
  if (m.localBytes != null) {
    return Image.memory(m.localBytes!, fit: fit, gaplessPlayback: true);
  }
  if (m.mediaUrl != null) {
    return Image.network(
      m.mediaUrl!,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
        opacity: frame == null && !sync ? 0 : 1,
        duration: Motion.normal,
        child: child,
      ),
      errorBuilder: (_, _, _) => Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
      ),
    );
  }
  return const SizedBox.shrink();
}

class _Sending extends StatelessWidget {
  const _Sending();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: const BoxDecoration(
      color: Colors.black45,
      shape: BoxShape.circle,
    ),
    child: const SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    ),
  );
}

class _Viewer extends StatelessWidget {
  const _Viewer({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragEnd: (d) {
                // Flick up or down to close.
                if ((d.primaryVelocity ?? 0).abs() > 300) {
                  Navigator.pop(context);
                }
              },
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: message,
                    child: messageImage(message, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- voice notes
/// One player for the whole app: starting a voice note stops the previous one.
class VoicePlayer extends ChangeNotifier {
  VoicePlayer._() {
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _player.stop();
        _player.seek(Duration.zero);
        current = null;
      }
      notifyListeners();
    });
    _player.positionStream.listen((_) => notifyListeners());
  }
  static final instance = VoicePlayer._();

  final _player = AudioPlayer();
  Message? current;

  bool isPlaying(Message m) => identical(current, m) && _player.playing;
  double progress(Message m) {
    if (!identical(current, m)) return 0;
    final total = _player.duration ?? m.duration ?? Duration.zero;
    if (total.inMilliseconds == 0) return 0;
    return (_player.position.inMilliseconds / total.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  Future<void> toggle(Message m) async {
    if (identical(current, m)) {
      _player.playing ? await _player.pause() : unawaited(_player.play());
      return;
    }
    final source = m.localPath ?? m.mediaUrl;
    if (source == null) return;
    current = m;
    notifyListeners();
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(source)));
      unawaited(_player.play());
    } catch (e) {
      debugPrint('voice note: $e');
      current = null;
      notifyListeners();
    }
  }
}

class VoiceBubble extends StatelessWidget {
  const VoiceBubble({super.key, required this.message, required this.mine});
  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bars =
        message.waveform ??
        List.generate(32, (i) => .3 + .5 * ((i * 37) % 11) / 10);
    final d = message.duration ?? Duration.zero;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 10,
          left: mine ? 40 : 0,
          right: mine ? 0 : 40,
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.sent : AppColors.received,
          borderRadius: BorderRadius.circular(26),
        ),
        child: ListenableBuilder(
          listenable: VoicePlayer.instance,
          builder: (context, _) {
            final player = VoicePlayer.instance;
            final playing = player.isPlaying(message);
            final p = player.progress(message);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pressable(
                  onTap: () => player.toggle(message),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mine ? AppColors.onSent : AppColors.ink,
                    ),
                    child: AnimatedSwitcher(
                      duration: Motion.fast,
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(playing),
                        color: mine ? AppColors.accent : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 150,
                  height: 34,
                  child: CustomPaint(
                    painter: _WavePainter(
                      bars,
                      p,
                      mine ? AppColors.onSent : AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _fmt(playing || p > 0 ? d * p : d),
                  style: tx(
                    12,
                    weight: FontWeight.w600,
                    color: mine ? AppColors.onSent : AppColors.muted,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.bars, this.progress, this.color);
  final List<double> bars;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final w = size.width / bars.length;
    for (var i = 0; i < bars.length; i++) {
      final h = (bars[i].clamp(.08, 1.0)) * size.height;
      final played = (i + .5) / bars.length <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(i * w + w / 2, size.height / 2),
            width: w * .55,
            height: h,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = played ? color : color.withValues(alpha: .28),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.bars != bars;
}

// ----------------------------------------------------------------- stickers
const stickers = [
  '🔥',
  '😂',
  '😍',
  '🥳',
  '😎',
  '🤯',
  '😭',
  '👏',
  '💯',
  '🎮',
  '🏆',
  '👀',
  '🙏',
  '❤️',
  '🤝',
  '⚡',
  '🍀',
  '😤',
];

/// A sticker in the chat: big, no bubble, lands with a bounce.
class StickerBubble extends StatelessWidget {
  const StickerBubble({super.key, required this.message, required this.mine});
  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TweenAnimationBuilder<double>(
          key: ObjectKey(message),
          tween: Tween(
            begin: DateTime.now().difference(message.time).inSeconds < 4
                ? 0
                : 1,
            end: 1,
          ),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Text(
            message.text,
            style: const TextStyle(fontSize: 84, height: 1.1),
          ),
        ),
      ),
    );
  }
}

/// Grid of stickers that slides up under the message box.
class StickerPicker extends StatelessWidget {
  const StickerPicker({super.key, required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      color: Colors.white,
      child: GridView.count(
        crossAxisCount: 6,
        padding: const EdgeInsets.all(10),
        children: [
          for (var i = 0; i < stickers.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 18 * i),
              scale: .5,
              offset: Offset.zero,
              duration: const Duration(milliseconds: 380),
              child: Pressable(
                scale: .8,
                onTap: () => onPick(stickers[i]),
                child: Center(
                  child: Text(
                    stickers[i],
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Whether the platform can record (web needs a secure page and a microphone).
bool get canTryRecording => true;

/// Safe wrapper used by the composer on web, where some environments block the mic.
bool get isWeb => kIsWeb;
