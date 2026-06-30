import 'package:flutter/material.dart';

import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'downloads_screen.dart';
import 'favorites_screen.dart';

/// الهيكل الرئيسي بتبويبات سفلية (نمط نبراس): الرئيسية / تنزيلاتي / المفضّلة.
/// المشغّل المصغّر مشترك فوق شريط التبويبات في كل التبويبات.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // تُبنى مرة واحدة وتبقى حيّة (IndexedStack) للحفاظ على الحالة عند التنقّل.
  final List<Widget> _tabs = const [
    HomeScreen(showMiniPlayer: false),
    DownloadsScreen(),
    FavoritesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
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
