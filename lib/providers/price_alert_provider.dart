
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

// ... (existing imports follow)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/vegetable_price.dart';

// POC Notification instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class PriceAlert {
  final String id;
  final String itemId;
  final String itemEng;
  final String itemTamil;
  final double? minPrice;
  final double? maxPrice;
  final bool notifyActive;

  PriceAlert({
    required this.id,
    required this.itemId,
    required this.itemEng,
    required this.itemTamil,
    this.minPrice,
    this.maxPrice,
    this.notifyActive = true,
  });

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      itemEng: json['item_name_eng'] as String,
      itemTamil: json['item_name_tamil'] as String,
      minPrice: json['min_price'] != null ? (json['min_price'] as num).toDouble() : null,
      maxPrice: json['max_price'] != null ? (json['max_price'] as num).toDouble() : null,
      notifyActive: json['notify_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_name_eng': itemEng,
      'item_name_tamil': itemTamil,
      'min_price': minPrice,
      'max_price': maxPrice,
      'notify_active': notifyActive,
    };
  }
}

class PriceAlertNotifier extends AsyncNotifier<List<PriceAlert>> {
  SupabaseClient get supabase => Supabase.instance.client;
  AppLifecycleListener? _lifecycleListener;

  final Completer<void> _initializationCompleter = Completer<void>();

  @override
  Future<List<PriceAlert>> build() async {
    // 1. Keep this provider alive globally
    ref.keepAlive();

    // 2. Poll only on lifecycle events (no 60s timer — saves battery)
    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => checkPendingNotifications(),
    );

    // Initial Setup for Stream & DB
    Future.delayed(const Duration(seconds: 3), () {
      _setupRealtimeStream();
      checkPendingNotifications();
    });

    // Background task is registered in main() to avoid churn

    // 3. Initialize Notifications (Awaited by _showLocalNotification)
    _initNotifications(); 
    _subscribeToAuthChanges();

    ref.onDispose(() {
      _realtimeStreamSub?.cancel();
      _lifecycleListener?.dispose();
    });
    
    return _fetchAlerts();
  }

  StreamSubscription? _realtimeStreamSub;

  void _setupRealtimeStream() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    // Modern Channel-based realtime (replaces deprecated .stream)
    final channel = supabase.channel('public:notifications_queue');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications_queue',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (payload) async {
        final row = payload.newRecord;
        if (row['is_read'] == false) {
          debugPrint('🔔 [CHANNEL] NEW ALERT: ${row['title']}');
          await _showLocalNotification(
            title: (row['title'] as String?) ?? 'Price Alert 🥕',
            body: (row['body'] as String?) ?? 'Market prices have updated.',
            itemId: row['item_id'] as String?,
          );
          
          await supabase.from('notifications_queue').update({'is_read': true}).eq('id', row['id']);
          debugPrint('✅ [CHANNEL] Marked as read: ${row['id']}');
        }
      },
    ).subscribe();
  }

  void _subscribeToAuthChanges() {
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _setupRealtimeStream(); 
        Future.delayed(const Duration(seconds: 2), () => checkPendingNotifications());
      } else if (data.event == AuthChangeEvent.signedOut) {
        _realtimeStreamSub?.cancel();
        Workmanager().cancelAll();
      }
    });
  }

  Future<void> checkPendingNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('notifications_queue')
          .select()
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (response.isNotEmpty) {
        for (var row in response) {
          await _showLocalNotification(
            title: (row['title'] as String?) ?? 'Price Alert 🥕',
            body: (row['body'] as String?) ?? 'Market prices have updated.',
            itemId: row['item_id'] as String?,
          );
          
          await supabase.from('notifications_queue').update({'is_read': true}).eq('id', row['id']);
        }
      }
    } catch (e) {
      debugPrint('❌ [POLL] ERROR: $e');
    }
  }

  Future<void> _initNotifications() async {
    try {
      // Request Android 13+ Notification Permission
      final status = await Permission.notification.request();
      debugPrint('🔔 [INIT] Notification Permission Status: $status');

      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      // Create the notification channel with MAXIMUM importance for "Pop on screen"
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'price_alerts', 
        'Price Alerts', 
        description: 'Notifications for price alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
          
      debugPrint('🔔 [INIT] Notification Plugin Ready!');
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    } catch (e) {
      debugPrint('❌ [INIT] Notification Setup Error: $e');
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete(); // Still complete to avoid hanging
      }
    }
  }

  Future<void> _showLocalNotification({
    required String title, 
    required String body,
    String? itemId,
  }) async {
    // Wait for plugin to be ready
    await _initializationCompleter.future;

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'price_alerts',
      'Price Alerts',
      channelDescription: 'Notifications for price alerts',
      importance: Importance.max,
      priority: Priority.max, // Priority Max for heads-up
      showWhen: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.message,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    // Use a stable ID derived from itemId if available, fallback to timestamp
    final id = itemId != null 
        ? (itemId.hashCode.abs() % 1000000)
        : (DateTime.now().microsecondsSinceEpoch % 1000000).toInt();

    try {
      await flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: itemId,
      );
      debugPrint('🔔 [DISPLAY] Notification sent to system: $title (ID: $id)');
    } catch (e) {
      debugPrint('❌ [DISPLAY] CRITICAL ERROR showing notification: $e');
    }
  }


  Future<List<PriceAlert>> _fetchAlerts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];
    try {
      final response = await supabase
          .from('price_alerts')
          .select()
          .eq('user_id', user.id);
      return (response as List).map((e) => PriceAlert.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching alerts: $e');
      return [];
    }
  }

  Future<void> loadAlerts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchAlerts());
  }

  Future<void> saveAlert({
    required VegetablePrice item,
    required double? minPrice,
    required double? maxPrice,
    required bool notifyActive,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = {
      'user_id': user.id,
      'item_id': item.id,
      'item_name_eng': item.itemEng,
      'item_name_tamil': item.itemTamil,
      'min_price': minPrice,
      'max_price': maxPrice,
      'notify_active': notifyActive,
    };

    await supabase.from('price_alerts').upsert(
          data,
          onConflict: 'user_id,item_id',
        );

    await loadAlerts();
    
    // Test notification locally immediately if it breaches today's price
    _testTriggerLocally(item, minPrice, maxPrice);
  }

  void _testTriggerLocally(VegetablePrice item, double? min, double? max) {
    // Current price check for immediate feedback
    final avgPrice = item.avgPrice;
    if ((min != null && avgPrice < min) || (max != null && avgPrice > max)) {
      _showLocalNotification(
        title: 'Price Alert Set!',
        body: 'Target reached: ${item.itemEng} is currently ₹${item.priceRange}. You will be notified daily if this continues.',
        itemId: item.id,
      );
    }
  }

  bool hasActiveAlert(String itemId) {
    return state.value?.any((a) => a.itemId == itemId && a.notifyActive) ?? false;
  }

  PriceAlert? getAlertFor(String itemId) {
    return state.value?.where((a) => a.itemId == itemId).firstOrNull;
  }
}

final priceAlertProvider =
    AsyncNotifierProvider<PriceAlertNotifier, List<PriceAlert>>(PriceAlertNotifier.new);
