import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';
import '../services/firebase_repo.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Settings presented as a slide-up sheet (opened from the Home ⋮ menu),
/// keeping all features except the removed social channels.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _bulkDownloading = false;
  int _bulkDone = 0;
  int _bulkTotal = 0;

  Future<void> _downloadRecentForOffline() async {
    if (_bulkDownloading) return;
    final lessons = await FirebaseRepo.fetchRecentLessons(limit: 50);
    final pending = lessons
        .where((l) =>
            l.audioUrl.isNotEmpty && !DownloadService.isAudioDownloaded(l.id))
        .toList();
    if (pending.isEmpty) {
      _snack('كل أحدث الصوتيات محمّلة بالفعل.');
      return;
    }
    setState(() {
      _bulkDownloading = true;
      _bulkDone = 0;
      _bulkTotal = pending.length;
    });
    for (final l in pending) {
      try {
        await DownloadService.downloadAudio(l.id, l.audioUrl);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _bulkDone++);
    }
    if (mounted) {
      setState(() => _bulkDownloading = false);
      _snack('تم تحميل $_bulkTotal صوتية للاستماع دون إنترنت.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pct = (state.fontScale * 100).round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('الإعدادات',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            const Text('حجم الخط',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.remove),
                  onPressed: () => state.setFontScale(state.fontScale - 0.1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$pct%', style: const TextStyle(fontSize: 18)),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  onPressed: () => state.setFontScale(state.fontScale + 0.1),
                ),
              ],
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الوضع الليلي'),
              secondary: const Icon(Icons.dark_mode, color: kTeal),
              value: state.themeMode == ThemeMode.dark,
              onChanged: (v) => state.setDark(v),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_download, color: kTeal),
              title: const Text('تحميل أحدث الصوتيات للاستماع دون إنترنت'),
              subtitle: _bulkDownloading
                  ? Text('جارٍ التحميل: $_bulkDone / $_bulkTotal')
                  : const Text('يحفظ أحدث 50 صوتية على جهازك'),
              trailing: _bulkDownloading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_left),
              onTap: _bulkDownloading ? null : _downloadRecentForOffline,
            ),
            const SizedBox(height: 16),
            const Center(
              child:
                  Text('تطبيق الإسحاقيين', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
