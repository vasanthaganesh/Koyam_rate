import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Handles the smart app-rating prompt with a two-step flow.
///
/// Step A: Custom dialog with star rating.
/// Step B: If >= 4 stars → trigger Play Store in-app review.
///         If <= 3 stars → dismiss silently (protect ranking).
class RatingService {
  RatingService._();

  static const String _keyOpenCount = 'app_open_count';
  static const String _keyRatingDone = 'rating_done';
  static const int _minOpensRequired = 5;

  // ───────────────────────────────────────────────────────────
  //  PUBLIC: Call once per cold launch in main.dart
  // ───────────────────────────────────────────────────────────

  /// Increments the app open counter in SharedPreferences.
  static Future<void> incrementOpenCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyOpenCount) ?? 0;
    await prefs.setInt(_keyOpenCount, current + 1);
  }

  // ───────────────────────────────────────────────────────────
  //  PUBLIC: Call from HomeScreen after data loads
  // ───────────────────────────────────────────────────────────

  /// Checks whether the rating dialog should be shown, then shows it.
  /// Returns immediately if conditions are not met.
  static Future<void> checkAndShowRating(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final ratingDone = prefs.getBool(_keyRatingDone) ?? false;
    if (ratingDone) return;

    final openCount = prefs.getInt(_keyOpenCount) ?? 0;
    if (openCount < _minOpensRequired) return;

    // Time-of-day gate: only 8 AM – 9 PM
    final hour = DateTime.now().hour;
    if (hour < 8 || hour >= 21) return;

    // All conditions met — show the dialog
    if (!context.mounted) return;
    await _showRatingDialog(context, prefs);
  }

  // ───────────────────────────────────────────────────────────
  //  PRIVATE: Two-step dialog
  // ───────────────────────────────────────────────────────────

  static Future<void> _showRatingDialog(
    BuildContext context,
    SharedPreferences prefs,
  ) async {
    final result = await showDialog<int?>(
      context: context,
      barrierDismissible: true, // tapping outside = "Maybe later"
      builder: (_) => const _RatingDialog(),
    );

    if (result == null) {
      // User tapped outside or "Maybe later"
      await _handleMaybeLater(prefs);
    } else {
      // User submitted a star rating
      await _handleSubmit(result, prefs);
    }
  }

  /// "Maybe later" or barrier dismiss: reset open count, keep rating_done false
  static Future<void> _handleMaybeLater(SharedPreferences prefs) async {
    await prefs.setInt(_keyOpenCount, 0);
    // rating_done stays false → will ask again after 5 more opens
  }

  /// User tapped Submit with [stars] selected.
  static Future<void> _handleSubmit(int stars, SharedPreferences prefs) async {
    // Always mark done so we never ask again
    await prefs.setBool(_keyRatingDone, true);

    if (stars >= 4) {
      // Trigger the official Google Play in-app review sheet
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    }
    // stars <= 3: dismiss silently — don't send to Play Store
  }
}

// ═══════════════════════════════════════════════════════════════
//  Custom rating dialog widget (Step A)
// ═══════════════════════════════════════════════════════════════

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _selectedStars = 0; // 0 = none selected

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Enjoying KoyamRate?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Help Koyambedu shoppers by rating us',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Star row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNum = index + 1;
              final isSelected = starNum <= _selectedStars;
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = starNum),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    scale: isSelected ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        // "Maybe later" text button
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Maybe later',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        // "Submit" button — disabled until at least 1 star
        ElevatedButton(
          onPressed: _selectedStars > 0
              ? () => Navigator.of(context).pop(_selectedStars)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            disabledForegroundColor: Colors.grey.shade400,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
