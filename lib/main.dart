import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/onboarding_screen.dart';
import 'services/rating_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/price_alert_provider.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint("Native called background task: \$task");
      
      // Initialize supabase for background isolate
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint("Background check aborted: No user logged in.");
        return Future.value(true);
      }

      final response = await supabase
          .from('notifications_queue')
          .select()
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (response.isNotEmpty) {
        // Initialize local notifications for background isolate
        final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
        const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);
        await localNotif.initialize(settings: initSettings);
        
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'price_alerts', 
          'Price Alerts', 
          description: 'Notifications for price alerts', 
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

        for (var row in response) {
          const AndroidNotificationDetails androidSpec = AndroidNotificationDetails(
            'price_alerts', 
            'Price Alerts', 
            importance: Importance.max, 
            priority: Priority.max,
            showWhen: true,
            enableVibration: true,
            playSound: true,
          );
          const NotificationDetails platformSpec = NotificationDetails(android: androidSpec);

          final notifId = (DateTime.now().microsecondsSinceEpoch % 1000000).toInt();

          await localNotif.show(
            id: notifId,
            title: (row['title'] as String?) ?? 'Price Alert',
            body: (row['body'] as String?) ?? 'Check the latest prices.',
            notificationDetails: platformSpec,
          );
          
          await supabase.from('notifications_queue').update({'is_read': true}).eq('id', row['id']);
        }
      }
      return Future.value(true);
    } catch (err) {
      debugPrint("Background task error: \$err");
      return Future.value(false); // Retries depending on policy
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone for scheduled notifications
  tz.initializeTimeZones();
  
  // Initialize Background WorkManager
  Workmanager().initialize(
    callbackDispatcher, 
    isInDebugMode: false, // Set to false for production
  );

  // Register the core price alert task once
  Workmanager().registerPeriodicTask(
    "price_alert_worker",
    "priceAlertTask",
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );

  // Initialize Supabase
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Initialize AdMob SDK
  await MobileAds.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    const ProviderScope(
      child: KoyamRateApp(),
    ),
  );
}

class KoyamRateApp extends StatelessWidget {
  const KoyamRateApp({super.key});

  /// Check if onboarding has been completed.
  /// Also increments app_open_count for the rating prompt (only after onboarding).
  Future<bool> _isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_complete') ?? false;
    if (done) {
      // Increment open count for rating trigger (never on first launch)
      await RatingService.incrementOpenCount();
    }
    return done;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KoyamRate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<bool>(
        future: _isOnboardingComplete(),
        builder: (context, snapshot) {
          // Splash screen while loading SharedPreferences
          if (snapshot.connectionState != ConnectionState.done) {
            return const _SplashScreen();
          }
          final onboardingDone = snapshot.data ?? false;
          return onboardingDone
              ? const AuthWrapper()
              : const OnboardingScreen();
        },
      ),
    );
  }
}

/// Minimal splash screen shown while SharedPreferences loads.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon.png',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'KoyamRate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main app shell with bottom navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Initialize the notifier globally to catch background price alerts
        ref.watch(priceAlertProvider);

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home, Icons.home_outlined, 'HOME'),
                    _buildNavItem(1, Icons.favorite, Icons.favorite_border, 'FAVORITES'),
                    _buildNavItem(2, Icons.person, Icons.person_outline, 'PROFILE'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Icon(
              isActive ? activeIcon : inactiveIcon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
