import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vegetable_price.dart';
import 'dummy_data.dart';

/// Service layer for price data — now powered by Supabase.
class PriceService {
  String get _favoritesKey {
    final userId = _client.auth.currentUser?.id;
    return userId != null ? 'favorite_ids_$userId' : 'favorite_ids_guest';
  }
  static const String _languageKey = 'language';

  SupabaseClient get _client => Supabase.instance.client;

  // ── Prices (Supabase) ──

  /// Fetches the latest prices, falling back to the most recent previous date if today is empty.
  Future<(List<VegetablePrice>, DateTime?)> fetchPrices({String? category}) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      var query = _client.from('prices_latest').select().eq('date', today);

      if (category != null && category != 'all') {
        query = query.eq('category', category);
      }

      final List<dynamic> response = await query.order('item_eng', ascending: true);

      List<VegetablePrice> results;
      DateTime? dataDate;

      if (response.isEmpty) {
        final maxDateRes = await _client
            .from('price_history')
            .select('date')
            .order('date', ascending: false)
            .limit(1);

        if (maxDateRes.isEmpty) {
          return ([], null);
        }

        final fallbackDateStr = maxDateRes[0]['date'] as String;
        dataDate = DateTime.tryParse(fallbackDateStr);

        var fallbackQuery = _client
            .from('prices_latest')
            .select()
            .eq('date', fallbackDateStr);
        // REMOVED: magic number limit(32)

        if (category != null && category != 'all') {
          fallbackQuery = fallbackQuery.eq('category', category);
        }

        final fallback = await fallbackQuery.order('item_eng', ascending: true);
        results = fallback.map((row) => VegetablePrice.fromJson(row as Map<String, dynamic>)).toList();
      } else {
        results = response
            .map((row) => VegetablePrice.fromJson(row as Map<String, dynamic>))
            .toList();
        dataDate = DateTime.tryParse(today);
      }
      
      await _cachePrices(results, dataDate);
      return (results, dataDate);
    } catch (e) {
      debugPrint('PriceService.fetchPrices error: $e');
      rethrow;
    }
  }

  /// Caches the given list of prices along with a timestamp and the data's specific date.
  Future<void> _cachePrices(List<VegetablePrice> prices, DateTime? dataDate) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prices.map((p) => p.toJson()).toList();
    await prefs.setString('cached_prices', jsonEncode(jsonList));
    if (dataDate != null) {
      await prefs.setString('cached_data_date', dataDate.toIso8601String());
    } else {
      await prefs.remove('cached_data_date');
    }
    await prefs.setString('cached_prices_timestamp', DateTime.now().toIso8601String());
  }

  /// Loads cached prices and returns a record of (prices list, cache timestamp, data date).
  Future<(List<VegetablePrice>, String, DateTime?)?> loadCachedPrices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('cached_prices');
      final String? timestamp = prefs.getString('cached_prices_timestamp');
      if (jsonStr == null || timestamp == null) return null;
      
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final prices = jsonList.map((e) => VegetablePrice.fromJson(e as Map<String, dynamic>)).toList();
      
      final String? dataDateStr = prefs.getString('cached_data_date');
      DateTime? dataDate = dataDateStr != null ? DateTime.tryParse(dataDateStr) : null;

      return (prices, timestamp, dataDate);
    } catch (e) {
      debugPrint('PriceService.loadCachedPrices error: $e');
      return null;
    }
  }

  Future<List<VegetablePrice>> searchPrices(String queryText) async {
    try {
      final q = queryText.toLowerCase();
      final (all, _) = await fetchPrices();
      return all
          .where((p) =>
              p.itemEng.toLowerCase().contains(q) ||
              p.itemTamil.contains(queryText))
          .toList();
    } catch (e) {
      debugPrint('PriceService.searchPrices error: $e');
      rethrow;
    }
  }

  List<double> getTrend(String itemId) => DummyData.getTrend(itemId);

  String getBargainTip(String category) => DummyData.getBargainTip(category);

  // ── Favorites ──

  Future<List<String>> getFavoriteIds() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Guest: use local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_favoritesKey) ?? [];
    }

    try {
      // Logged-in: fetch from Supabase
      final List<dynamic> response = await _client
          .from('favorites')
          .select('item_id')
          .eq('user_id', user.id);
      
      return response.map((row) => row['item_id'] as String).toList();
    } on PostgrestException catch (e) {
      // Handle the case where the table doesn't exist yet
      if (e.code == 'PGRST204' || e.code == 'PGRST205') {
        debugPrint('PriceService.getFavoriteIds: favorites table not found. Returning empty list.');
        return [];
      }
      debugPrint('PriceService.getFavoriteIds database error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('PriceService.getFavoriteIds generic error: $e');
      return [];
    }
  }

  Future<bool> toggleFavorite(String itemId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Local fallback for guests
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_favoritesKey) ?? [];
      
      if (ids.contains(itemId)) {
        ids.remove(itemId);
        await prefs.setStringList(_favoritesKey, ids);
        return false;
      } else {
        ids.add(itemId);
        await prefs.setStringList(_favoritesKey, ids);
        return true;
      }
    }

    // Supabase logic for logged-in users
    try {
      final ids = await getFavoriteIds();
      if (ids.contains(itemId)) {
        await _client.from('favorites')
            .delete()
            .match({'user_id': user.id, 'item_id': itemId});
        return false;
      } else {
        await _client.from('favorites').insert({
          'user_id': user.id,
          'item_id': itemId,
        });
        return true;
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.code == 'PGRST205') {
        throw 'Database error: The favorites table is missing. Please run the setup SQL.';
      }
      debugPrint('PriceService.toggleFavorite database error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('PriceService.toggleFavorite error: $e');
      rethrow;
    }
  }

  Future<List<VegetablePrice>> getFavorites() async {
    final ids = await getFavoriteIds();
    if (ids.isEmpty) return [];
    
    // Optimized: filter by specific IDs
    // Using .in() with a list of IDs is cleaner and safer
    final response = await _client
        .from('prices_latest')
        .select()
        .filter('id', 'in', ids);
        
    return (response as List).map((row) => VegetablePrice.fromJson(row as Map<String, dynamic>)).toList();
  }

  // ── Settings ──

  Future<bool> isTamil() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) == 'ta';
  }

  Future<void> setLanguage(bool isTamil) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, isTamil ? 'ta' : 'en');
  }

}
