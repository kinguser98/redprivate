import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared cache manager for poster/banner images.
/// Combined with `maxWidthDiskCache`/`maxHeightDiskCache` on each
/// CachedNetworkImage, the disk cache stores downscaled copies so repeat
/// loads are near-instant and network/memory usage is minimized.
class AppImageCache {
  static final CacheManager posters = CacheManager(
    Config(
      'app_image_cache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 800,
    ),
  );

  static const int posterMaxWidth = 500;
  static const int posterMaxHeight = 750;
}
