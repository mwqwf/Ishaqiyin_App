import 'package:flutter/material.dart';

import '../services/audio_controller.dart';
import '../utils/lesson_display.dart';
import '../theme.dart';

/// وضع القيادة: واجهة أزرار عملاقة للاستماع أثناء التنقّل (تشغيل مستمر).
class CarModeScreen extends StatefulWidget {
  const CarModeScreen({super.key});

  @override
  State<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends State<CarModeScreen> {
  final AudioController _audio = AudioController.instance;

  @override
  void initState() {
    super.initState();
    _audio.autoplay = true;
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _audio,
          builder: (context, _) {
            final l = _audio.currentLesson;
            final playing = _audio.playing;
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 30),
                    tooltip: 'خروج',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.directions_car,
                    color: Colors.white24, size: 54),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    l == null ? 'اختر درساً للتشغيل' : lessonDisplayTitle(l),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<Duration>(
                  stream: _audio.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    return Text(
                      '${_fmt(pos)} / ${_fmt(_audio.duration)}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 22),
                    );
                  },
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _bigBtn(
                        Icons.replay_30, 'رجوع', () => _audio.skipBackward(),
                        size: 64),
                    _playBtn(playing),
                    _bigBtn(
                        Icons.forward_30, 'تقديم', () => _audio.skipForward(),
                        size: 64),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _bigBtn(Icons.skip_previous, 'السابق',
                        () => _audio.playPrevious(),
                        size: 56),
                    _bigBtn(Icons.skip_next, 'التالي', () => _audio.playNext(),
                        size: 56),
                  ],
                ),
                const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _playBtn(bool playing) {
    return Semantics(
      button: true,
      label: playing ? 'إيقاف' : 'تشغيل',
      child: InkWell(
        onTap: () {
          final l = _audio.currentLesson;
          if (l != null) _audio.toggle(l);
        },
        borderRadius: BorderRadius.circular(80),
        child: Container(
          width: 140,
          height: 140,
          decoration: const BoxDecoration(
            color: kGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(playing ? Icons.pause : Icons.play_arrow,
              color: Colors.white, size: 90),
        ),
      ),
    );
  }

  Widget _bigBtn(IconData icon, String label, VoidCallback onTap,
      {double size = 60}) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(60),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}
