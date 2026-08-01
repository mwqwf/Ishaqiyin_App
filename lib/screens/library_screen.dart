import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'playlists_screen.dart';

/// صفحة «قوائمي» السفلية: تجمع «قوائم التشغيل» و«السجل» في صفحة واحدة
/// بتبويبين، بدلاً من كونهما داخل الإعدادات — دون تكثير التبويبات السفلية.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قوائمي'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.queue_music), text: 'قوائم التشغيل'),
              Tab(icon: Icon(Icons.history), text: 'السجل'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PlaylistsScreen(embedded: true),
            HistoryScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
