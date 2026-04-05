import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/vegetable_price.dart';
import '../services/price_service.dart';
import '../theme/app_theme.dart';
import '../widgets/matte_frosted_glass_card.dart';
import '../providers/price_alert_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/price_alert_sheet.dart';
import '../widgets/vegetable_image.dart';
import '../widgets/price_trend_chart.dart';

class DetailScreen extends ConsumerWidget {
  final VegetablePrice item;
  const DetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch relevant providers
    ref.watch(priceAlertProvider);
    final isFav = ref.watch(favoritesProvider.select(
      (data) => data.value?.contains(item.itemEng) ?? false
    ));
    final hasAlert = ref.read(priceAlertProvider.notifier).hasActiveAlert(item.id);
    
    final service = PriceService();

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
                    child: VegetableImage(
                      assetPath: 'assets/images/vegetables/${item.itemEng.replaceAll(' ', '_')}.png',
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
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
                        ref.read(favoritesProvider.notifier).toggleFavorite(item.itemEng);
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

                    // ── 7-Day Price Trend Chart ──
                    FutureBuilder<List<PricePoint>>(
                      future: service.fetchPriceHistory(item.itemEng),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)),
                          );
                        }
                        if (snapshot.hasError) {
                          return SizedBox(
                            height: 180,
                            child: Center(
                              child: Text(
                                'Could not load trend',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            ),
                          );
                        }

                        final history = snapshot.data ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chart header with legend
                            Row(
                              children: [
                                const Text(
                                  '7-Day Price Trend',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const Spacer(),
                                // Legend
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 12, height: 3, decoration: BoxDecoration(color: const Color(0xFF42A5F5), borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 4),
                                    Text('Min', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                    const SizedBox(width: 10),
                                    Container(width: 12, height: 3, decoration: BoxDecoration(color: const Color(0xFFFFA726), borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 4),
                                    Text('Max', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Chart
                            PriceTrendChart(history: history),
                            const SizedBox(height: 12),
                            // Summary row
                            if (history.length >= 2) _buildSummaryRow(history),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── Bargain Tip (now data-driven) ──
                    FutureBuilder<List<PricePoint>>(
                      future: service.fetchPriceHistory(item.itemEng),
                      builder: (context, snapshot) {
                        final history = snapshot.data ?? [];
                        final tip = service.generateTip(history);
                        return MatteFrostedGlassCard(
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
                        );
                      },
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
                        onPressed: () async {
                          try {
                            final history = await service.fetchPriceHistory(item.itemEng);
                            final allMin = history.isEmpty ? item.minPrice : history.map((p) => p.minPrice).reduce((a, b) => a < b ? a : b);
                            final allMax = history.isEmpty ? item.maxPrice : history.map((p) => p.maxPrice).reduce((a, b) => a > b ? a : b);
                            
                            double pctChange = 0.0;
                            if (history.isNotEmpty) {
                              final firstAvg = history.first.avgPrice;
                              final lastAvg = history.last.avgPrice;
                              pctChange = firstAvg > 0 ? ((lastAvg - firstAvg) / firstAvg * 100) : 0.0;
                            }

                            String trendLabel;
                            if (pctChange > 5) {
                              trendLabel = '↑ Rising';
                            } else if (pctChange < -5) {
                              trendLabel = '↓ Falling';
                            } else {
                              trendLabel = '→ Stable';
                            }

                            final tip = service.generateTip(history);

                            String emoji = '🥬';
                            final lowerEng = item.itemEng.toLowerCase();
                            if (lowerEng.contains('tomato')) emoji = '🍅';
                            else if (lowerEng.contains('onion')) emoji = '🧅';
                            else if (lowerEng.contains('potato')) emoji = '🥔';
                            else if (lowerEng.contains('carrot')) emoji = '🥕';
                            else if (lowerEng.contains('beans')) emoji = '🫘';
                            else if (lowerEng.contains('lemon')) emoji = '🍋';
                            else if (lowerEng.contains('cabbage')) emoji = '🥦';
                            else if (lowerEng.contains('ginger') || lowerEng.contains('beetroot')) emoji = '🫚';
                            else if (lowerEng.contains('drumstick')) emoji = '🌿';

                            final text = '''$emoji ${item.itemTamil}
${item.itemEng}

Today's Price (Koyambedu):
₹${item.minPrice.toInt()}–${item.maxPrice.toInt()} /kg  •  Wholesale

7-Day Trend:
Low ₹${allMin.toInt()}  •  High ₹${allMax.toInt()}  •  $trendLabel

$tip

Source: CMDA Chennai via KoyamRate app''';

                            await Share.share(
                              text,
                              subject: '${item.itemEng} price today — KoyamRate',
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open share sheet')),
                              );
                            }
                          }
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

  /// Builds the 7-day summary row: Low | High | Trend arrow
  Widget _buildSummaryRow(List<PricePoint> history) {
    final allMin = history.map((p) => p.minPrice).reduce((a, b) => a < b ? a : b);
    final allMax = history.map((p) => p.maxPrice).reduce((a, b) => a > b ? a : b);
    final firstAvg = history.first.avgPrice;
    final lastAvg = history.last.avgPrice;
    final pctChange = firstAvg > 0 ? ((lastAvg - firstAvg) / firstAvg * 100) : 0.0;

    String arrow;
    Color arrowColor;
    if (pctChange > 5) {
      arrow = '↑ ${pctChange.toStringAsFixed(0)}%';
      arrowColor = Colors.red.shade600;
    } else if (pctChange < -5) {
      arrow = '↓ ${pctChange.abs().toStringAsFixed(0)}%';
      arrowColor = Colors.green.shade600;
    } else {
      arrow = '→ stable';
      arrowColor = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _summaryItem('7d Low', '₹${allMin.toInt()}', const Color(0xFF42A5F5)),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          _summaryItem('7d High', '₹${allMax.toInt()}', const Color(0xFFFFA726)),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          _summaryItem('Trend', arrow, arrowColor),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor)),
      ],
    );
  }
}
