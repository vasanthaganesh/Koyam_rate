import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vegetable_price.dart';
import '../services/price_service.dart';
import '../theme/app_theme.dart';
import '../widgets/matte_frosted_glass_card.dart';
import '../providers/price_alert_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/price_alert_sheet.dart';

class DetailScreen extends ConsumerWidget {
  final VegetablePrice item;
  const DetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch relevant providers
    ref.watch(priceAlertProvider);
    final isFav = ref.watch(favoritesProvider.select(
      (data) => data.value?.contains(item.id) ?? false
    ));
    final hasAlert = ref.read(priceAlertProvider.notifier).hasActiveAlert(item.id);
    
    final service = PriceService();
    final tip = service.getBargainTip(item.category ?? 'vegetables');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back button + Header image + Fav button ──
              Stack(
                children: [
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: Image.asset(
                      'assets/images/vegetables/${item.itemEng.replaceAll(' ', '_')}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 280,
                          color: AppColors.greenLight,
                          child: const Center(child: Icon(Icons.local_florist, size: 60, color: AppColors.green)),
                        );
                      },
                    ),
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, AppColors.backgroundLight],
                        ),
                      ),
                    ),
                  ),
                  // Back button
                  Positioned(
                    top: 8, left: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                      ),
                    ),
                  ),
                  // Favorite button
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () {
                        if (Supabase.instance.client.auth.currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please log in to save favorites'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                          return;
                        }
                        ref.read(favoritesProvider.notifier).toggleFavorite(item.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 8)],
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? AppColors.primary : AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Item Info ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemTamil,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.itemEng,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    // Price card
                    MatteFrostedGlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Today's Range", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                item.priceRange,
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.greenLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'WHOLESALE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green, letterSpacing: 1),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Bargain Tip ──
                    MatteFrostedGlassCard(
                      backgroundColor: AppColors.greenLight.withValues(alpha: 0.3),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.lightbulb_outline, color: AppColors.green, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bargain Tip',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tip,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Price Alert Button ──
                    SizedBox(
                      width: double.infinity,
                      child: MatteFrostedGlassCard(
                        onTap: () {
                          if (Supabase.instance.client.auth.currentUser == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please log in to set price alerts'), backgroundColor: AppColors.primary),
                            );
                            return;
                          }
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            isDismissible: true,
                            builder: (context) => PriceAlertSheet(item: item),
                          );
                        },
                        backgroundColor: const Color(0xFFFF9800).withValues(alpha: 0.9), // Orange accent
                        borderColor: AppColors.green.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text('Set Price Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            if (hasAlert) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Alert Active ✓', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Share Button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Share via WhatsApp placeholder
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sharing coming soon!')),
                          );
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share Price', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Disclaimer
                    Center(
                      child: Text(
                        'Source: CMDA Chennai • Approx wholesale prices – retail varies',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
