import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Performance utilities for optimizing Flutter app
class PerformanceUtils {
  PerformanceUtils._();

  /// Optimized image cache settings
  static const int maxMemoryCacheSize = 100; // Max 100 images in memory
  static const int maxCacheWidth = 400; // Default max width for avatars
  static const int maxCacheHeight = 400; // Default max height for avatars

  /// Get optimized CachedNetworkImage for avatars
  static Widget optimizedAvatar({
    required String? imageUrl,
    double radius = 24,
    IconData fallbackIcon = Icons.person,
    Color? backgroundColor,
  }) {
    final bool hasValidUrl = imageUrl != null && imageUrl.isNotEmpty;
    final int cacheSize = (radius * 2 * 2).toInt(); // 2x for retina displays

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.shade200,
      backgroundImage: hasValidUrl
          ? CachedNetworkImageProvider(
              imageUrl,
              maxWidth: cacheSize,
              maxHeight: cacheSize,
            )
          : null,
      child: !hasValidUrl
          ? Icon(
              fallbackIcon,
              size: radius,
              color: Colors.grey.shade600,
            )
          : null,
    );
  }

  /// Get optimized CachedNetworkImage widget
  static Widget optimizedImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: Icon(Icons.image, color: Colors.grey.shade400),
          );
    }

    // Calculate cache dimensions (2x for retina)
    final int? memCacheWidth = width != null ? (width * 2).toInt() : maxCacheWidth;
    final int? memCacheHeight = height != null ? (height * 2).toInt() : maxCacheHeight;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: Icon(Icons.broken_image, color: Colors.grey.shade400),
          ),
    );
  }
}

/// Optimized list view that avoids shrinkWrap issues
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool reverse;
  final ScrollPhysics? physics;
  final double? cacheExtent;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.reverse = false,
    this.physics,
    this.cacheExtent,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      padding: padding,
      reverse: reverse,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      // Increase cache extent for smoother scrolling
      cacheExtent: cacheExtent ?? 500,
      // Use automatic keep alive to preserve state of visible items
      addAutomaticKeepAlives: true,
      // Add repaint boundaries for better performance
      addRepaintBoundaries: true,
    );
  }
}

/// Debouncer utility for preventing excessive function calls
class Debouncer {
  final Duration delay;
  VoidCallback? _action;
  bool _isWaiting = false;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    _action = action;
    if (!_isWaiting) {
      _isWaiting = true;
      Future.delayed(delay, () {
        _action?.call();
        _isWaiting = false;
      });
    }
  }

  void cancel() {
    _action = null;
    _isWaiting = false;
  }
}

/// Throttler utility for limiting function call frequency
class Throttler {
  final Duration interval;
  DateTime? _lastActionTime;

  Throttler({this.interval = const Duration(milliseconds: 500)});

  void run(VoidCallback action) {
    final now = DateTime.now();
    if (_lastActionTime == null ||
        now.difference(_lastActionTime!) >= interval) {
      _lastActionTime = now;
      action();
    }
  }
}

/// Mixin for optimizing StatefulWidget with auto-dispose
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T> {
  final List<VoidCallback> _disposeCallbacks = [];

  /// Register a callback to be called on dispose
  void autoDispose(VoidCallback callback) {
    _disposeCallbacks.add(callback);
  }

  @override
  void dispose() {
    for (final callback in _disposeCallbacks) {
      callback();
    }
    _disposeCallbacks.clear();
    super.dispose();
  }
}
