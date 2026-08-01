import 'package:flutter/material.dart';

import '../services/local_store.dart';
import '../services/submission_service.dart';
import '../theme.dart';

/// 🗂️ «مساهماتي» — حالة كل مساهمة أرسلها المستمع للمراجعة.
class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  @override
  void initState() {
    super.initState();
    // فتح الشاشة يُطفئ نقطة «جديد» على زرّ مساهماتي في الرئيسية.
    LocalStore.setMySubsSeenMs(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مساهماتي')),
      body: SafeArea(
        child: StreamBuilder<List<LessonSubmission>>(
          stream: SubmissionService.watchMine(),
          builder: (ctx, snap) {
            final items = snap.data ?? const <LessonSubmission>[];
            if (snap.connectionState == ConnectionState.waiting &&
                items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_edu_outlined,
                          size: 56,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      const Text(
                        'لم ترسل أي مساهمة بعد.\nمن «شارك درساً» يمكنك '
                        'اقتراح دروس صوتية تُنشر بعد موافقة المشرفين.',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.6),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _SubmissionTile(submission: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final LessonSubmission submission;
  const _SubmissionTile({required this.submission});

  (Color, IconData, String) _statusMeta(BuildContext context) {
    switch (submission.status) {
      case 'approved':
        return (kGreen, Icons.check_circle_outline, 'نُشرت كما هي');
      case 'approved_edited':
        return (kTeal, Icons.published_with_changes, 'نُشرت بعد تعديل');
      case 'rejected':
        return (
          Theme.of(context).colorScheme.error,
          Icons.cancel_outlined,
          'لم تُنشر'
        );
      default:
        return (kOrange, Icons.hourglass_top_rounded, 'قيد المراجعة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _statusMeta(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    submission.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${submission.categoryName} ← ${submission.subcategoryName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (submission.status == 'rejected' &&
                submission.rejectReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'السبب: ${submission.rejectReason}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (submission.status == 'pending') ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('سحب المساهمة؟'),
                        content:
                            const Text('سيُحذف الطلب قبل أن يراجعه المشرفون.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('سحب'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await SubmissionService.deletePending(submission);
                    }
                  },
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('سحب الطلب'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
