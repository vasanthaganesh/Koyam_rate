import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Test ad unit IDs — replace with real IDs before Play Store launch.
class AdConstants {
  AdConstants._();

  // TODO: Replace with your real Android banner ad unit ID before launch
  static const String bannerAdUnitId = 'ca-app-pub-6476706508818949/5495312985';
}

/// A self-contained banner ad widget that handles loading, display, and disposal.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _bannerAd = BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _hasFailed = true;
              _bannerAd = null;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasFailed || _bannerAd == null) {
      return const SizedBox(height: 0);
    }

    if (!_isLoaded) {
      return const SizedBox(height: 50);
    }

    return SizedBox(
      width: AdSize.banner.width.toDouble(),
      height: AdSize.banner.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
