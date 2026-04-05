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
    return _service.getFavoriteItemEngs();
  }

  Future<void> toggleFavorite(String itemEng) async {
    final previousState = state.value ?? [];
    final isCurrentlyFavorite = previousState.contains(itemEng);

    // 1. OPTIMISTIC UPDATE: Update UI immediately
    final updatedList = List<String>.from(previousState);
    if (isCurrentlyFavorite) {
      updatedList.remove(itemEng);
    } else {
      updatedList.add(itemEng);
    }
    state = AsyncValue.data(updatedList);

    try {
      // 2. BACKGROUND SYNC: Perform the actual DB/Local operation
      final wasAdded = await _service.toggleFavorite(itemEng);
      
      // Double check consistency if needed, but usually Supabase response is the truth
      // In a more complex app, we might want to refresh from the server here
    } catch (e) {
      debugPrint('FavoritesNotifier.toggleFavorite error: $e');
      // 3. REVERT ON FAILURE: Bring back the previous state if sync failed
      state = AsyncValue.data(previousState);
    }
  }

  bool isFavorite(String itemEng) {
    return state.value?.contains(itemEng) ?? false;
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, List<String>>(FavoritesNotifier.new);

// Helper provider to get the actual vegetable details for favorites
final favoriteItemsProvider = FutureProvider<List<VegetablePrice>>((ref) async {
  final engs = ref.watch(favoritesProvider).value ?? [];
  if (engs.isEmpty) return [];
  
  final service = PriceService();
  final (all, _) = await service.fetchPrices();
  return all.where((p) => engs.contains(p.itemEng)).toList();
});
