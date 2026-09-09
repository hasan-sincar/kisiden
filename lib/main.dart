import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:appim/utils/local_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/phone_setup_screen.dart';
import 'services/database_service.dart';
import 'services/guest_session_service.dart';
import 'screens/notifications_screen.dart';
import 'screens/listing_detail_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/add_listing_screen.dart';
import 'screens/responsive_layout.dart';
import 'widgets/app_update_gate.dart';
import 'package:meta_seo/meta_seo.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'utils/translations.dart';
import 'utils/theme_colors.dart';
import 'utils/auth_gate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('tr'));

Uri? pendingDeepLink;
bool isAppReady = false;
const String _webRecaptchaSiteKey = String.fromEnvironment(
  'FIREBASE_APPCHECK_WEB_RECAPTCHA_KEY',
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Background Firebase Init Error: $e');
  }
}

void main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      bool firebaseInitialized = false;

      // Web URL temizliği
      usePathUrlStrategy();

      // Firebase başlat
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseInitialized = true;
      } catch (e) {
        debugPrint('Firebase Initialize Error: $e');
      }

      // SEO sadece web
      if (firebaseInitialized && kIsWeb) {
        try {
          MetaSEO().config();
        } catch (e) {
          debugPrint('Meta SEO Error: $e');
        }
      }

      // APP CHECK
      if (firebaseInitialized) {
        try {
          if (kIsWeb) {
            if (_webRecaptchaSiteKey.isNotEmpty) {
              await FirebaseAppCheck.instance.activate(
                webProvider: ReCaptchaV3Provider(_webRecaptchaSiteKey),
              );
            } else {
              debugPrint(
                'App Check Web is disabled: FIREBASE_APPCHECK_WEB_RECAPTCHA_KEY not provided.',
              );
            }
          } else {
            await FirebaseAppCheck.instance.activate(
              androidProvider: kDebugMode
                  ? AndroidProvider.debug
                  : AndroidProvider.playIntegrity,
              appleProvider: kDebugMode
                  ? AppleProvider.debug
                  : AppleProvider.deviceCheck,
            );
          }
        } catch (e) {
          debugPrint('App Check Error: $e');
        }
      }

      if (firebaseInitialized && !kIsWeb) {
        try {
          await MobileAds.instance.initialize();
        } catch (e) {
          debugPrint('MobileAds initialize error: $e');
        }
      }

      // Dil sistemi
      try {
        final prefs = await SharedPreferences.getInstance();

        String? savedLang = prefs.getString('language_code');

        if (savedLang != null) {
          appLocale.value = Locale(savedLang);
        } else {
          String sysLang = PlatformDispatcher.instance.locale.languageCode;

          if (sysLang == 'en' || sysLang == 'ar') {
            appLocale.value = Locale(sysLang);
          } else {
            appLocale.value = const Locale('tr');
          }
        }
      } catch (e) {
        debugPrint('Language Init Error: $e');
      }

      if (firebaseInitialized) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Pass all uncaught "fatal" errors from the framework to Crashlytics
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      runApp(const KisidenApp());
    },
    (error, stack) => Firebase.apps.isNotEmpty
        ? FirebaseCrashlytics.instance.recordError(error, stack, fatal: true)
        : debugPrint('Unhandled startup error before Firebase init: $error'),
  );
}

Future<void> requestNotificationPermission() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
  } catch (e) {
    debugPrint('Notification Permission Error: $e');
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class KisidenApp extends StatefulWidget {
  const KisidenApp({super.key});

  @override
  State<KisidenApp> createState() => _KisidenAppState();
}

class _KisidenAppState extends State<KisidenApp> {
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();

    _setupPushNotificationHandlers();
    _setupDeepLinks();
  }

  void _setupDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        pendingDeepLink = initialUri;
      }
    } catch (e) {
      debugPrint('Initial DeepLink Error: $e');
    }

    _appLinks.uriLinkStream.listen(
      (uri) {
        try {
          if (isAppReady) {
            _handleIncomingLink(uri);
          } else {
            pendingDeepLink = uri;
          }
        } catch (e) {
          debugPrint('DeepLink Stream Error: $e');
        }
      },
      onError: (e) {
        debugPrint('DeepLink Listen Error: $e');
      },
    );
  }

  void _handleIncomingLink(Uri uri) async {
    try {
      final navState = navigatorKey.currentState;
      final navContext = navigatorKey.currentContext;
      if (navState == null || navContext == null) {
        pendingDeepLink = uri;
        return;
      }

      final path = uri.path.toLowerCase();

      if (path.contains('/favoriler')) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) {
          pendingDeepLink = uri;
          return;
        }
        if (!await AuthGate.requireRegisteredUser(
          ctx,
          message: 'Favori ilanlarinizi gormek icin giris yapmalisiniz.',
        )) {
          return;
        }
        if (navigatorKey.currentState == null) {
          pendingDeepLink = uri;
          return;
        }
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const FavoritesScreen()),
        );
        return;
      }

      if (path.contains('/ilan-ver')) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) {
          pendingDeepLink = uri;
          return;
        }
        if (!await AuthGate.requireRegisteredUser(
          ctx,
          message: 'Ilan verebilmek icin giris yapmalisiniz.',
        )) {
          return;
        }
        if (navigatorKey.currentState == null) {
          pendingDeepLink = uri;
          return;
        }
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const AddListingScreen()),
        );
        return;
      }

      if (path.contains('/ilanlar')) {
        if (navigatorKey.currentState == null) return;
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
      }

      if (path.contains('/bildirimler')) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) {
          pendingDeepLink = uri;
          return;
        }
        if (!await AuthGate.requireRegisteredUser(
          ctx,
          message: 'Bildirimlerinizi gormek icin giris yapmalisiniz.',
        )) {
          return;
        }
        if (navigatorKey.currentState == null) {
          pendingDeepLink = uri;
          return;
        }
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        return;
      }

      // URL'de /ilan geçiyorsa veya direkt id parametresi varsa yakala
      if (uri.path.contains('/ilan') || uri.queryParameters.containsKey('id')) {
        String? listingId = uri.queryParameters['id'];

        if (listingId != null) {
          var doc = await FirebaseFirestore.instance
              .collection('listings')
              .doc(listingId)
              .get();

          if (doc.exists && navigatorKey.currentContext != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => ListingDetailScreen(
                  data: doc.data()!,
                  listingId: listingId,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Handle DeepLink Error: $e');
    }
  }

  void _setupPushNotificationHandlers() async {
    try {
      await requestNotificationPermission();

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          if (message.notification != null &&
              navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              SnackBar(
                content: Text(
                  '${message.notification!.title}\n${message.notification!.body}',
                ),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint('Foreground Notification Error: $e');
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      });

      FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
      ) {
        if (message != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          });
        }
      });
    } catch (e) {
      debugPrint('Push Notification Setup Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,

          debugShowCheckedModeBanner: false,

          title: tr('app_name'),

          locale: locale,

          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // TEST İÇİN SPLASH DEVRE DIŞI
          home: const SplashScreen(),

          onGenerateRoute: (settings) {
            // Web ortamında tanımlanmamış bir URL (örn: /ilan) girildiğinde
            // Flutter'ın "Route Not Found" hatası verip çökmesini önler.
            // Yönlendirme işlemi zaten app_links tarafından yapılıyor.
            return MaterialPageRoute(
              builder: (context) => const SplashScreen(),
              settings: settings,
            );
          },

          scrollBehavior: AppScrollBehavior(),

          builder: (context, child) {
            if (child == null) {
              return const SizedBox();
            }

            return ResponsiveLayout(
              child: child,
              tabletMaxWidth: 800,
              desktopMaxWidth: 1000,
              outerBackgroundColor: const Color(0xFFEEEEEE),
              borderRadius: 16,
            );
          },

          themeMode: ThemeMode.light,

          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              surface: Colors.white,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF7F8FB),
            textTheme: LocalFonts.poppinsTextTheme(Theme.of(context).textTheme),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              scrolledUnderElevation: 0,
              elevation: 0,
              centerTitle: false,
              iconTheme: IconThemeData(color: Colors.black87),
              titleTextStyle: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0x14000000)),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF3F5FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0x26000000)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0x26000000)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              height: 72,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0x1A0040D9),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return LocalFonts.poppins(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : const Color(0xFF616161),
                );
              }),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0x1A000000),
              thickness: 1,
            ),
          ),
        );
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool _isReady = false;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final isGuest = await GuestSessionService.restore();
    // Önceki sürümlerin Anonymous Auth oturumunu temizler. Yeni misafir
    // akışında Firebase'e hiçbir kullanıcı kaydı yazılmaz.
    if (FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      await FirebaseAuth.instance.signOut();
    }
    if (mounted) {
      setState(() {
        _isGuest = isGuest;
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        Widget target;

        if (snapshot.hasData && !snapshot.data!.isAnonymous) {
          target = AuthChecker(user: snapshot.data!);
        } else if (_isGuest) {
          target = const HomeScreen();
        } else {
          target = const LoginScreen();
        }

        return AppUpdateGate(child: target);
      },
    );
  }
}

class AuthChecker extends StatefulWidget {
  final User user;

  const AuthChecker({super.key, required this.user});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = true;
  bool _isProfileComplete = false;

  @override
  void initState() {
    super.initState();

    _checkUserData();
  }

  Future<void> _checkUserData() async {
    try {
      await GuestSessionService.end();

      await _dbService.saveUserToFirestore(widget.user);

      bool isComplete = await _dbService.isProfileComplete(widget.user.uid);

      if (mounted) {
        setState(() {
          _isProfileComplete = isComplete;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('User Data Error: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                tr('preparing_profile'),
                style: LocalFonts.poppins(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_isProfileComplete) {
      return const HomeScreen();
    } else {
      return const PhoneSetupScreen(isFirstTimeSetup: true);
    }
  }
}
