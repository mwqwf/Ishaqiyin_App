import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../theme.dart';

/// «حصادك» — ملخّص استماع شخصي (محلي بالكامل) قابل للمشاركة.
class WrappedScreen extends StatelessWidget {
  const WrappedScreen({super.key});

  static String _fmtSeconds(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '$h س $m د';
    return '$m دقيقة';
  }

  String _topCategoryName() {
    final visits = LocalStore.getCategoryVisits();
    if (visits.isEmpty) return '—';
    final top = visits.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final cat = ContentRepository.instance.categoryById(top.key);
    return cat?.name ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final total = LocalStore.getTotalSeconds();
    final week = LocalStore.getWeekSeconds();
    final completed = LocalStore.getTotalCompletedCount();
    final streak = LocalStore.getStreakDays();
    final played = LocalStore.getPlayCounts().length;
    final topCat = _topCategoryName();
    final goalMin = LocalStore.getWeeklyGoalMinutes();

    return Scaffold(
      appBar: AppBar(title: const Text('حصادك')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kTeal, kSlate],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.insights, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                const Text('حصاد استماعك',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('إجمالي ${_fmtSeconds(total)} من الاستماع',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _grid([
            _Stat(
                'هذا الأسبوع', _fmtSeconds(week), Icons.calendar_today, kBlue),
            _Stat('دروس أكملتها', '$completed', Icons.verified, kGreen),
            _Stat('سلسلة الأيام', '$streak', Icons.local_fire_department,
                kOrange),
            _Stat('دروس استمعت لها', '$played', Icons.headphones, kTeal),
          ]),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.category, color: kTeal),
              title: const Text('أكثر قسم تابعته'),
              trailing: Text(topCat,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (goalMin > 0) _goalCard(week, goalMin),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('شارك حصادك'),
            onPressed: () => Share.share(
              '📿 حصاد استماعي في «منبر ادكصهك»:\n'
              '• إجمالي: ${_fmtSeconds(total)}\n'
              '• هذا الأسبوع: ${_fmtSeconds(week)}\n'
              '• دروس أكملتها: $completed\n'
              '• سلسلة استماع: $streak يوماً\n'
              'انضمّ إليّ في الاستماع 🎧',
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(int weekSeconds, int goalMin) {
    final done = (weekSeconds / 60).round();
    final ratio = (done / goalMin).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flag, color: kOrange),
                const SizedBox(width: 8),
                Text('هدفك الأسبوعي: $goalMin دقيقة',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Colors.grey.shade300,
                color: ratio >= 1 ? kGreen : kOrange,
              ),
            ),
            const SizedBox(height: 6),
            Text(
                ratio >= 1
                    ? 'أحسنت! بلغت هدفك 🎉 ($done/$goalMin د)'
                    : '$done من $goalMin دقيقة',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<_Stat> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: s.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(s.icon, color: s.color, size: 26),
              const SizedBox(height: 6),
              Text(s.value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: s.color)),
              Text(s.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}
