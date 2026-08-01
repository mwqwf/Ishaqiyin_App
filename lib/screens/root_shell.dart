import 'package:flutter/material.dart';

import '../services/content_repository.dart';
import '../services/notification_service.dart';
import '../widgets/mini_player.dart';
import 'contribute_screen.dart';
import 'home_screen.dart';
import 'downloads_screen.dart';
import 'favorites_screen.dart';
import 'library_screen.dart';

/// الهيكل الرئيسي بتبويبات سفلية (نمط نبراس): الرئيسية / قوائمي / تنزيلاتي / المفضّلة.
/// «قوائمي» صفحة واحدة تجمع قوائم التشغيل والسجل بتبويبين.
/// المشغّل المصغّر مشترك فوق شريط التبويبات في كل التبويبات.
/// يجلب المحتوى بالقوة عند عودة التطبيق للمقدّمة لتظهر تعديلات الإدارة فوراً.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _index = 0;

  // تُبنى مرة واحدة وتبقى حيّة (IndexedStack) للحفاظ على الحالة عند التنقّل.
  final List<Widget> _tabs = const [
    HomeScreen(showMiniPlayer: false),
    LibraryScreen(),
    DownloadsScreen(),
    FavoritesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // عند عودة التطبيق للمقدّمة: اجلب أحدث محتوى من الخادم فوراً.
    if (state == AppLifecycleState.resumed) {
      // ignore: discarded_futures
      ContentRepository.instance.refresh(force: true).then((_) {
        NotificationService.maybeDeliverDailyWard();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      // 📤 «شارك درساً»: مساهمة المستمعين تُنشر بعد موافقة المشرفين
      // (قرار المالك — عكس نبراس المفتوح). يظهر في تبويب الرئيسية فقط.
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              heroTag: 'contribute_fab',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContributeScreen()),
              ),
              icon: const Icon(Icons.mic_external_on_rounded),
              label: const Text('شارك درساً'),
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: 'قوائمي',
              ),
              NavigationDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: 'تنزيلاتي',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'المفضّلة',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
