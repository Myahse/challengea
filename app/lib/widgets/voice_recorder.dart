import 'dart:async';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../theme.dart';

/// A finished recording, ready to send.
class Recording {
  Recording(
    this.path,
    this.bytes,
    this.contentType,
    this.duration,
    this.waveform,
  );
  final String path; // file path (phone) or blob URL (web), playable locally
  final Uint8List bytes;
  final String contentType;
  final Duration duration;
  final List<double> waveform;
}

/// Records voice notes and reports live loudness (for the bars).
class VoiceRecorder extends ChangeNotifier {
  final _rec = AudioRecorder();
  StreamSubscription<Amplitude>? _amp;
  DateTime? _start;
  final List<double> levels = [];
  bool recording = false;
  String _type = 'audio/mp4';

  Duration get elapsed =>
      _start == null ? Duration.zero : DateTime.now().difference(_start!);

  /// Returns an error message, or null when recording started.
  Future<String?> start() async {
    try {
      if (!await _rec.hasPermission()) {
        return 'Allow the microphone to record voice notes';
      }
      // AAC (m4a) on phones; Opus (webm) in browsers.
      final aac = !kIsWeb && await _rec.isEncoderSupported(AudioEncoder.aacLc);
      final encoder = aac ? AudioEncoder.aacLc : AudioEncoder.opus;
      _type = aac ? 'audio/mp4' : 'audio/webm';
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/voice_${DateTime.now().millisecondsSinceEpoch}.${aac ? 'm4a' : 'webm'}';
      await _rec.start(
        RecordConfig(encoder: encoder, numChannels: 1, bitRate: 48000),
        path: path,
      );
      levels.clear();
      _start = DateTime.now();
      recording = true;
      _amp = _rec.onAmplitudeChanged(const Duration(milliseconds: 80)).listen((
        a,
      ) {
        // dBFS (-60..0) -> 0..1
        levels.add(((a.current + 60) / 60).clamp(0.05, 1.0));
        notifyListeners();
      });
      HapticFeedback.mediumImpact();
      notifyListeners();
      return null;
    } catch (e) {
      recording = false;
      notifyListeners();
      return 'Microphone not available here';
    }
  }

  Future<Recording?> stop() async {
    if (!recording) return null;
    final duration = elapsed;
    recording = false;
    await _amp?.cancel();
    notifyListeners();
    final path = await _rec.stop();
    // Too short: ignore.
    if (path == null || duration < const Duration(milliseconds: 600)) {
      return null;
    }
    final bytes = await XFile(path).readAsBytes();
    return Recording(path, bytes, _type, duration, _bars(levels, 40));
  }

  Future<void> cancel() async {
    if (!recording) return;
    recording = false;
    await _amp?.cancel();
    await _rec.cancel();
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// Squeezes the live levels into [n] bars.
  static List<double> _bars(List<double> levels, int n) {
    if (levels.isEmpty) return List.filled(n, .2);
    return [
      for (var i = 0; i < n; i++)
        levels
            .sublist(
              (i * levels.length / n).floor(),
              max(
                (i * levels.length / n).floor() + 1,
                ((i + 1) * levels.length / n).floor(),
              ),
            )
            .reduce(max),
    ];
  }

  @override
  void dispose() {
    _amp?.cancel();
    _rec.dispose();
    super.dispose();
  }
}

/// Shown in place of the message box while recording.
class RecordingBar extends StatelessWidget {
  const RecordingBar({
    super.key,
    required this.recorder,
    required this.cancelling,
  });
  final VoiceRecorder recorder;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final e = recorder.elapsed;
        final last = recorder.levels.length > 28
            ? recorder.levels.sublist(recorder.levels.length - 28)
            : recorder.levels;
        return Row(
          children: [
            const SizedBox(width: 10),
            _Blink(color: cancelling ? AppColors.muted : AppColors.danger),
            const SizedBox(width: 8),
            Text(
              '${e.inMinutes}:${(e.inSeconds % 60).toString().padLeft(2, '0')}',
              style: tx(
                15,
                weight: FontWeight.w700,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 30,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final l in last)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 3,
                        height: 4 + 26 * l,
                        margin: const EdgeInsets.symmetric(horizontal: 1.2),
                        decoration: BoxDecoration(
                          color: cancelling
                              ? AppColors.muted
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                cancelling ? 'Release to cancel' : '‹ Slide to cancel',
                key: ValueKey(cancelling),
                style: tx(
                  12,
                  color: cancelling ? AppColors.danger : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}

class _Blink extends StatefulWidget {
  const _Blink({required this.color});
  final Color color;

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: .25, end: 1.0).animate(_c),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
    ),
  );
}
