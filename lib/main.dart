import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'firebase_options.dart';
import 'services/auto_download_service.dart';
import 'services/content_repository.dart';
import 'services/deep_link_service.dart';
import 'services/local_store.dart';
import 'services/notification_service.dart';
import 'services/submission_service.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'screens/root_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ali.menbaradkshk.audio',
      androidNotificationChannelName: 'تشغيل الدروس',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('JustAudioBackground init failed: $e');
  }

  await LocalStore.init();
  await NotificationService.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
    } catch (e) {
      debugPrint('Firebase App Check init failed: $e');
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // ignore: discarded_futures
    NotificationService.initPush();
    // مراقب نتائج «شارك درساً»: يعمل فقط لمن سبق أن ساهم (لديه هوية).
    if (SubmissionService.hasIdentity) {
      SubmissionService.startDecisionWatcher();
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  final appState = AppState()..load();
  ContentRepository.instance.loadFromCache();
  // ignore: discarded_futures
  ContentRepository.instance.refresh(force: true).then((_) {
    AutoDownloadService.runIfEnabled();
    NotificationService.scheduleContinueReminder();
    NotificationService.maybeDeliverDailyWard();
    NotificationService.syncFollowedSubs();
  });

  runApp(MyApp(appState: appState));
}

class MyApp extends StatefulWidget {
  final AppState appState;
  const MyApp({super.key, required this.appState});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    DeepLinkService.init(rootNavigatorKey);
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: widget.appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'منبر ادكصهك',
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
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(state.fontScale),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              );
            },
            home: const RootShell(),
          );
        },
      ),
    );
  }
}
