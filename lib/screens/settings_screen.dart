import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../services/auto_download_service.dart';
import '../services/download_service.dart';
import '../services/submission_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'my_submissions_screen.dart';

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
  static final Uri _privacyPolicyUri =
      Uri.parse('https://minbar-adkassahk.vercel.app/privacy');

  Future<void> _openPrivacyPolicy() async {
    try {
      final opened = await launchUrl(
        _privacyPolicyUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح سياسة الخصوصية.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر فتح سياسة الخصوصية.')),
        );
      }
    }
  }

  String _wardTimeLabel() {
    final h = LocalStore.getWardHour();
    final m = LocalStore.getWardMinute();
    if (h < 0) return '—';
    final t = TimeOfDay(hour: h, minute: m);
    return t.format(context);
  }

  Future<void> _pickWardTime() async {
    final cur = LocalStore.getWardEnabled()
        ? TimeOfDay(
            hour: LocalStore.getWardHour(), minute: LocalStore.getWardMinute())
        : const TimeOfDay(hour: 6, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: cur);
    if (picked != null) {
      await LocalStore.setWardTime(picked.hour, picked.minute);
    }
  }

  Future<void> _pickWeeklyGoal() async {
    const options = [0, 30, 60, 120, 180, 300];
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('الهدف الأسبوعي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final o in options)
              ListTile(
                title: Text(o == 0 ? 'بلا هدف' : '$o دقيقة أسبوعياً'),
                trailing: LocalStore.getWeeklyGoalMinutes() == o
                    ? const Icon(Icons.check, color: kTeal)
                    : null,
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await LocalStore.setWeeklyGoalMinutes(chosen);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteMyData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف بياناتي'),
        content: const Text(
          'سيُحذف سجل مساهماتك وملفاتها من السحابة، ثم تُمسح المفضلة '
          'والقوائم والسجل والتنزيلات من هذا الجهاز. لا يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SubmissionService.deleteMyData();
      for (final entry in DownloadService.allDownloads()) {
        await DownloadService.deleteDownload(entry.key);
      }
      await LocalStore.clearPersonalData();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حُذفت بياناتك بنجاح.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذّر حذف البيانات. تحقق من الاتصال وحاول مجدداً.'),
        ));
      }
    }
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
            // المظهر: ثلاثة خيارات — فاتح / داكن / اتّباع النظام.
            const Row(
              children: [
                Icon(Icons.brightness_6, color: kTeal),
                SizedBox(width: 12),
                Text('المظهر',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
                ButtonSegment(value: ThemeMode.dark, label: Text('داكن')),
                ButtonSegment(value: ThemeMode.system, label: Text('النظام')),
              ],
              selected: {state.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => state.setThemeMode(s.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.text_fields, color: kTeal),
                const SizedBox(width: 12),
                const Expanded(child: Text('حجم النص')),
                Text('${(state.fontScale * 100).round()}%'),
              ],
            ),
            Slider(
              min: 0.8,
              max: 1.4,
              divisions: 6,
              value: state.fontScale.clamp(0.8, 1.4),
              label: '${(state.fontScale * 100).round()}%',
              onChanged: state.setFontScale,
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('التنزيل التلقائي'),
              subtitle: const Text('يحفظ أحدث الدروس للاستماع دون إنترنت'),
              secondary:
                  const Icon(Icons.download_for_offline_outlined, color: kTeal),
              value: state.autoDownloadEnabled,
              onChanged: (v) async {
                await state.setAutoDownloadEnabled(v);
                if (v) {
                  await state.setAutoDownloadTarget('recent');
                  await AutoDownloadService.runIfEnabled();
                }
              },
            ),
            if (state.autoDownloadEnabled) ...[
              DropdownButtonFormField<String>(
                initialValue: state.autoDownloadTarget ?? 'recent',
                decoration: const InputDecoration(
                  labelText: 'ما الذي يُنزّل؟',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'recent', child: Text('أحدث الدروس')),
                  DropdownMenuItem(
                      value: 'main', child: Text('خلاصتك المقترحة')),
                ],
                onChanged: (v) async {
                  await state.setAutoDownloadTarget(v);
                  await AutoDownloadService.runIfEnabled();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('عبر Wi‑Fi فقط'),
                value: LocalStore.getAutoDownloadWifiOnly(),
                onChanged: (v) async {
                  await LocalStore.setAutoDownloadWifiOnly(v);
                  if (mounted) setState(() {});
                  await AutoDownloadService.runIfEnabled();
                },
              ),
            ],
            const Divider(height: 24),
            // الإشعارات: مفتاح حقيقي يشترك/يلغي الاشتراك في موضوع الدفع.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الإشعارات'),
              subtitle: Text(
                  notifOn ? 'تصلك إشعارات المحتوى الجديد' : 'الإشعارات موقوفة'),
              secondary: Icon(
                  notifOn
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: kTeal),
              value: notifOn,
              onChanged: (v) async {
                try {
                  await NotificationService.setEnabled(v);
                  await SubmissionService.refreshPendingToken();
                  if (mounted) setState(() {});
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('تعذّر تحديث الإشعارات. حاول مجدداً.'),
                  ));
                }
              },
            ),
            if (notifOn)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تذكير «تابع الاستماع»'),
                subtitle: const Text('إشعار محلي بلطف بدرس لم تكمله'),
                secondary: const Icon(Icons.history_toggle_off, color: kTeal),
                value: LocalStore.getContinueReminderEnabled(),
                onChanged: (v) async {
                  await LocalStore.setContinueReminderEnabled(v);
                  await NotificationService.scheduleContinueReminder();
                  setState(() {});
                },
              ),
            const Divider(height: 24),
            // الوِرد اليومي: درس مقترح يصلك كل يوم في وقت تختاره.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الوِرد اليومي'),
              subtitle: Text(LocalStore.getWardEnabled()
                  ? 'درس اليوم في ${_wardTimeLabel()}'
                  : 'درس مقترح كل يوم في وقت تختاره'),
              secondary: const Icon(Icons.wb_sunny_outlined, color: kTeal),
              value: LocalStore.getWardEnabled(),
              onChanged: (v) async {
                if (v) {
                  await _pickWardTime();
                } else {
                  await LocalStore.disableWard();
                }
                await NotificationService.scheduleDailyWard();
                if (mounted) setState(() {});
              },
            ),
            if (LocalStore.getWardEnabled())
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: kTeal),
                title: const Text('وقت الوِرد'),
                trailing: Text(_wardTimeLabel(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () async {
                  await _pickWardTime();
                  await NotificationService.scheduleDailyWard();
                  if (mounted) setState(() {});
                },
              ),
            const Divider(height: 24),
            // الهدف الأسبوعي (بالدقائق).
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, color: kOrange),
              title: const Text('الهدف الأسبوعي للاستماع'),
              subtitle: Text(LocalStore.getWeeklyGoalMinutes() > 0
                  ? '${LocalStore.getWeeklyGoalMinutes()} دقيقة أسبوعياً'
                  : 'غير محدَّد'),
              trailing: const Icon(Icons.chevron_left),
              onTap: _pickWeeklyGoal,
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined, color: kTeal),
              title: const Text('سياسة الخصوصية'),
              subtitle: const Text('تفتح مباشرة في موقع منبر'),
              trailing: const Icon(Icons.open_in_new),
              onTap: _openPrivacyPolicy,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined, color: kTeal),
              title: const Text('مساهماتي'),
              subtitle: const Text('تابع قرار المشرفين وسبب النتيجة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.delete_forever_outlined, color: Colors.red),
              title: const Text('حذف بياناتي'),
              subtitle: const Text('حذف المساهمات والبيانات الشخصية نهائياً'),
              trailing: const Icon(Icons.chevron_left),
              onTap: _deleteMyData,
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
