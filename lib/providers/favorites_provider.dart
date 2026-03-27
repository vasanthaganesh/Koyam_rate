import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vegetable_price.dart';
import '../services/price_service.dart';

class FavoritesNotifier extends AsyncNotifier<List<String>> {
  final PriceService _service = PriceService();

  @override
  Future<List<String>> build() async {
    // Fetch initial favorites from Supabase/Local
    return _service.getFavoriteIds();
  }

  Future<void> toggleFavorite(String itemId) async {
    final previousState = state.value ?? [];
    final isCurrentlyFavorite = previousState.contains(itemId);

    // 1. OPTIMISTIC UPDATE: Update UI immediately
    final updatedList = List<String>.from(previousState);
    if (isCurrentlyFavorite) {
      updatedList.remove(itemId);
    } else {
      updatedList.add(itemId);
    }
    state = AsyncValue.data(updatedList);

    try {
      // 2. BACKGROUND SYNC: Perform the actual DB/Local operation
      final wasAdded = await _service.toggleFavorite(itemId);
      
      // Double check consistency if needed, but usually Supabase response is the truth
      // In a more complex app, we might want to refresh from the server here
    } catch (e) {
      debugPrint('FavoritesNotifier.toggleFavorite error: $e');
      // 3. REVERT ON FAILURE: Bring back the previous state if sync failed
      state = AsyncValue.data(previousState);
    }
  }

  bool isFavorite(String itemId) {
    return state.value?.contains(itemId) ?? false;
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<String>>(FavoritesNotifier.new);

// Helper provider to get the actual vegetable details for favorites
final favoriteItemsProvider = FutureProvider<List<VegetablePrice>>((ref) async {
  final ids = ref.watch(favoritesProvider).value ?? [];
  if (ids.isEmpty) return [];
  
  final service = PriceService();
  final all = await service.fetchPrices();
  return all.where((p) => ids.contains(p.id)).toList();
});
