import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VegetableImage extends StatelessWidget {
  final String? assetPath;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const VegetableImage({
    super.key,
    this.assetPath,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (assetPath != null && assetPath!.isNotEmpty) {
      return Image.asset(
        assetPath!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _buildNetworkOrPlaceholder(),
      );
    }
    return _buildNetworkOrPlaceholder();
  }

  Widget _buildNetworkOrPlaceholder() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildShimmer(),
        errorWidget: (context, url, err) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildShimmer() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.eco,
          size: 40,
          color: Colors.green.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
