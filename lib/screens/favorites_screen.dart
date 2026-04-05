import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vegetable_price.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/matte_frosted_glass_card.dart';
import '../widgets/vegetable_image.dart';
import '../providers/language_provider.dart';
import 'detail_screen.dart';
import 'auth_wrapper.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoriteItemsProvider);
    final isTamil = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isTamil ? 'விருப்பங்கள்' : 'Favorites & Watchlist',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: favoritesAsync.when(
                data: (favorites) => favorites.isEmpty
                    ? _buildEmptyState(isTamil)
                    : _buildGrid(favorites, isTamil),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, stack) => Center(child: Text('Error loading favorites: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isTamil) {
    final isGuest = Supabase.instance.client.auth.currentUser == null;
    
    if (isGuest) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isTamil ? 'உள்நுழைய வேண்டும்' : 'Login Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              isTamil ? 'உங்களுக்குப் பிடித்தவைகளைப் பார்க்கவும் சேமிக்கவும் உள்நுழையவும்.' : 'Sign in to view and save your favorite items.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Return to login screen
                ref.read(guestModeProvider.notifier).setGuestMode(false);
              },
              child: Text(isTamil ? 'இப்போது உள்நுழைக' : 'Login Now'),
            )
          ],
        ),
      );
    }
  
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            isTamil ? 'உங்களுக்கு பிடித்தவை எதுவும் இல்லை' : 'No favorites yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            isTamil ? 'எந்த காய்கறியிலும் ❤️ என்பதைத் தட்டி இங்கே சேமிக்கவும்' : 'Tap the ❤️ on any vegetable to save it here',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  String _getImagePath(String itemEng) {
    return itemEng
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Widget _buildGrid(List<VegetablePrice> favorites, bool isTamil) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.76,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, i) {
        final item = favorites[i];
        final imagePath = 'assets/images/vegetables/${_getImagePath(item.itemEng)}.png';
        return MatteFrostedGlassCard(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(item: item)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: VegetableImage(
                          assetPath: imagePath,
                          imageUrl: item.imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6, right: 6,
                      child: GestureDetector(
                        onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(item.itemEng),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.favorite, size: 16, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isTamil ? item.itemTamil : item.itemEng,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                isTamil ? item.itemEng : item.itemTamil,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Text('₹${item.avgPrice.toInt()}/kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
        );
      },
    );
  }
}
