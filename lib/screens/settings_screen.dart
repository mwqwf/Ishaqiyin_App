import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'history_screen.dart';
import 'playlists_screen.dart';

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
  void _nav(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final streak = LocalStore.getStreakDays();
    final notifOn = LocalStore.getNotificationsEnabled();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('الإعدادات',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            if (streak > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Chip(
                  avatar:
                      const Icon(Icons.local_fire_department, color: kOrange),
                  label: Text(
                      'سلسلة استماع: $streak ${streak == 1 ? 'يوم' : 'أيام'}'),
                ),
              ),
            ],
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.queue_music, color: kTeal),
              title: const Text('قوائم التشغيل'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _nav(const PlaylistsScreen()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, color: kBlue),
              title: const Text('السجل'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _nav(const HistoryScreen()),
            ),
            const Divider(height: 24),
            // الوضع الليلي (نمط نبراس: مفتاح بسيط).
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الوضع الليلي'),
              secondary: Icon(
                  state.themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: kTeal),
              value: state.themeMode == ThemeMode.dark,
              onChanged: (v) => state.setDark(v),
            ),
            const Divider(height: 24),
            // الإشعارات: مفتاح حقيقي يشترك/يلغي الاشتراك في موضوع الدفع.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الإشعارات'),
              subtitle: Text(notifOn
                  ? 'تصلك إشعارات المحتوى الجديد'
                  : 'الإشعارات موقوفة'),
              secondary: Icon(
                  notifOn
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: kTeal),
              value: notifOn,
              onChanged: (v) async {
                await NotificationService.setEnabled(v);
                if (mounted) setState(() {});
              },
            ),
            if (notifOn)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تذكير «تابع الاستماع»'),
                subtitle: const Text('إشعار محلي بلطف بدرس لم تكمله'),
                secondary:
                    const Icon(Icons.history_toggle_off, color: kTeal),
                value: LocalStore.getContinueReminderEnabled(),
                onChanged: (v) async {
                  await LocalStore.setContinueReminderEnabled(v);
                  setState(() {});
                },
              ),
            const SizedBox(height: 16),
            const Center(
              child: Text('منبر ادكصهك — دروس صوتية',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
