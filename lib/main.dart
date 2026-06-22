import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'firebase_options.dart';
import 'services/local_store.dart';
import 'services/firebase_repo.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'screens/root_tabs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ali.ishaqiyin_app.audio',
      androidNotificationChannelName: 'تشغيل الدروس',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    // Background audio is optional; never let it block app startup.
    debugPrint('JustAudioBackground init failed: $e');
  }

  await LocalStore.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  final appState = AppState()..load();

  // Warm the local cache in the background (non-blocking).
  // ignore: discarded_futures
  FirebaseRepo.syncAll();

  runApp(MyApp(appState: appState));
}

class MyApp extends StatelessWidget {
  final AppState appState;
  const MyApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'تطبيق الإسحاقيين',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: state.themeMode,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(state.fontScale),
                  ),
                  child: child!,
                ),
              );
            },
            home: const RootTabs(),
          );
        },
      ),
    );
  }
}
