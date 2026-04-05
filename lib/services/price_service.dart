import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vegetable_price.dart';

/// A single day's price record from the price_history table.
class PricePoint {
  final DateTime date;
  final double minPrice;
  final double maxPrice;

  const PricePoint({
    required this.date,
    required this.minPrice,
    required this.maxPrice,
  });

  double get avgPrice => (minPrice + maxPrice) / 2;

  factory PricePoint.fromJson(Map<String, dynamic> json) {
    return PricePoint(
      date: DateTime.parse(json['date'] as String),
      minPrice: (json['min_price'] as num).toDouble(),
      maxPrice: (json['max_price'] as num).toDouble(),
    );
  }
}

/// Service layer for price data — now powered by Supabase.
class PriceService {
  String get _favoritesKey {
    final userId = _client.auth.currentUser?.id;
    return userId != null ? 'favorite_ids_$userId' : 'favorite_ids_guest';
  }
  static const String _languageKey = 'language';

  SupabaseClient get _client => Supabase.instance.client;

  /// In-memory cache for image URLs to avoid repeated queries within one session.
  Map<String, String>? _imageUrlCache;

  /// Fetches all image URLs from the vegetable_images lookup table.
  /// Returns a Map of item_eng -> image_url. Cached after first call.
  Future<Map<String, String>> fetchImageUrls() async {
    if (_imageUrlCache != null) return _imageUrlCache!;
    try {
      final response = await _client
          .from('vegetable_images')
          .select('item_eng, image_url');
      _imageUrlCache = {
        for (final row in (response as List))
          (row['item_eng'] as String): (row['image_url'] as String),
      };
      return _imageUrlCache!;
    } catch (e) {
      debugPrint('PriceService.fetchImageUrls error: $e');
      return {};
    }
  }

  /// Merges image URLs from the lookup table into a list of VegetablePrice objects.
  Future<List<VegetablePrice>> _mergeImageUrls(List<VegetablePrice> prices) async {
    final imageMap = await fetchImageUrls();
    if (imageMap.isEmpty) return prices;
    return prices.map((p) {
      final url = imageMap[p.itemEng];
      return (url != null && p.imageUrl == null) ? p.copyWith(imageUrl: url) : p;
    }).toList();
  }

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
          return (<VegetablePrice>[], null);
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
      // Merge image URLs from the dedicated vegetable_images table
      results = await _mergeImageUrls(results);

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

  /// Fetches historical price data for a given item from the price_history table.
  /// Returns an empty list on any error — never throws.
  Future<List<PricePoint>> fetchPriceHistory(String itemEng, {int days = 7}) async {
    try {
      final response = await _client
          .from('price_history')
          .select('date, min_price, max_price')
          .eq('item_eng', itemEng)
          .order('date', ascending: true)
          .limit(days);

      return (response as List)
          .map((row) => PricePoint.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PriceService.fetchPriceHistory error: $e');
      return [];
    }
  }

  /// Generates a human-readable bargain tip from real price history.
  String generateTip(List<PricePoint> history) {
    if (history.isEmpty) return 'No price history yet — check back tomorrow.';
    if (history.length == 1) return 'Only 1 day of data — trend analysis needs more time.';

    final latest = history.last;
    final first = history.first;
    final latestAvg = latest.avgPrice;
    final firstAvg = first.avgPrice;

    // Calculate 7-day average
    final totalAvg = history.map((p) => p.avgPrice).reduce((a, b) => a + b) / history.length;
    final diff = ((latestAvg - totalAvg) / totalAvg * 100);

    if (diff < -5) {
      return 'Prices are ${diff.abs().toStringAsFixed(0)}% below the ${history.length}-day average — good time to buy!';
    } else if (diff > 5) {
      return 'Prices are ${diff.toStringAsFixed(0)}% above the ${history.length}-day average — consider waiting.';
    } else {
      return 'Prices are stable around ₹${totalAvg.toStringAsFixed(0)}/kg over the past ${history.length} days.';
    }
  }

  // ── Favorites ──

  Future<List<String>> getFavoriteItemEngs() async {
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
          .select('item_eng')
          .eq('user_id', user.id);
      
      return response.map((row) => row['item_eng'] as String).toList();
    } on PostgrestException catch (e) {
      // Handle the case where the table doesn't exist yet
      if (e.code == 'PGRST204' || e.code == 'PGRST205') {
        debugPrint('PriceService.getFavoriteItemEngs: favorites table not found. Returning empty list.');
        return [];
      }
      debugPrint('PriceService.getFavoriteItemEngs database error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('PriceService.getFavoriteItemEngs generic error: $e');
      return [];
    }
  }

  Future<bool> toggleFavorite(String itemEng) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Local fallback for guests
      final prefs = await SharedPreferences.getInstance();
      final engs = prefs.getStringList(_favoritesKey) ?? [];
      
      if (engs.contains(itemEng)) {
        engs.remove(itemEng);
        await prefs.setStringList(_favoritesKey, engs);
        return false;
      } else {
        engs.add(itemEng);
        await prefs.setStringList(_favoritesKey, engs);
        return true;
      }
    }

    // Supabase logic for logged-in users
    try {
      final engs = await getFavoriteItemEngs();
      if (engs.contains(itemEng)) {
        await _client.from('favorites')
            .delete()
            .match({'user_id': user.id, 'item_eng': itemEng});
        return false;
      } else {
        await _client.from('favorites').insert({
          'user_id': user.id,
          'item_eng': itemEng,
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
    final engs = await getFavoriteItemEngs();
    if (engs.isEmpty) return [];
    
    // Optimized: filter by specific IDs
    // Using .in() with a list of IDs is cleaner and safer
    final response = await _client
        .from('prices_latest')
        .select()
        .filter('item_eng', 'in', engs);
        
    return await _mergeImageUrls(
      (response as List).map((row) => VegetablePrice.fromJson(row as Map<String, dynamic>)).toList(),
    );
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
