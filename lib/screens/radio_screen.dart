import 'package:flutter/material.dart';

import '../models.dart';
import '../services/audio_controller.dart';
import '../services/content_repository.dart';
import '../services/firebase_repo.dart';
import '../theme.dart';
import 'player_screen.dart';

/// «إذاعة منبر» — محطات صوتية تبني طابوراً طويلاً يُشغَّل بلا توقف.
class RadioScreen extends StatelessWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final all = ContentRepository.instance.lessons;
    final stations = <_Station>[
      _Station('محطتك المخصّصة', 'مختارة حسب استماعك', Icons.auto_awesome,
          kTeal, () => FirebaseRepo.stationForYou(all)),
      _Station('جديد المنبر', 'أحدث الدروس أولاً', Icons.fiber_new, kBlue,
          () => FirebaseRepo.stationNewest(all)),
      _Station('الأكثر استماعاً', 'ما يستمع إليه الناس', Icons.trending_up,
          kOrange, () => FirebaseRepo.mostListened(all, limit: 100)),
      _Station('القصيرة', 'دروس أقل من ١٠ دقائق', Icons.timer_outlined, kGreen,
          () => FirebaseRepo.stationShort(all)),
      _Station('عشوائية', 'اكتشف من كل الأقسام', Icons.shuffle, kGold,
          () => FirebaseRepo.stationRandom(all)),
      _Station('قبل النوم', 'استماع هادئ مع مؤقّت ٣٠ دقيقة', Icons.bedtime,
          kSlate, () => FirebaseRepo.stationRandom(all),
          sleepMinutes: 30),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('إذاعة منبر')),
      body: all.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child:
                    Text('لا يوجد محتوى بعد.', style: TextStyle(fontSize: 17)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: stations.map((s) => _stationCard(context, s)).toList(),
            ),
    );
  }

  Widget _stationCard(BuildContext context, _Station s) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: s.color,
          child: Icon(s.icon, color: Colors.white, size: 26),
        ),
        title: Text(s.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        subtitle: Text(s.subtitle),
        trailing: const Icon(Icons.play_circle_fill, color: kTeal, size: 34),
        onTap: () => _play(context, s),
      ),
    );
  }

  void _play(BuildContext context, _Station s) {
    final queue = s.build();
    if (queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد دروس كافية لهذه المحطة بعد.')),
      );
      return;
    }
    final audio = AudioController.instance;
    audio.autoplay = true;
    audio.setPlaylist(queue);
    if (s.sleepMinutes != null) {
      audio.setSleepTimer(Duration(minutes: s.sleepMinutes!));
    }
    final Lesson first = queue.first;
    audio.playLesson(first);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(lesson: first, playlist: queue),
      ),
    );
  }
}

class _Station {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Lesson> Function() build;
  final int? sleepMinutes;
  _Station(this.title, this.subtitle, this.icon, this.color, this.build,
      {this.sleepMinutes});
}
