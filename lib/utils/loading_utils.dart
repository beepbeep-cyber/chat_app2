import 'package:my_porject/configs/app_theme.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

class LoadingUtils {
  static OverlayEntry? _overlayEntry;

  /// Hiển thị premium loading overlay với blur effect
  static void show(BuildContext context, {String? message}) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _PremiumLoadingOverlay(message: message),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Ẩn loading overlay
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Show loading with custom duration then auto hide
  static void showTimed(
    BuildContext context, {
    String? message,
    Duration duration = const Duration(seconds: 2),
  }) {
    show(context, message: message);
    Future.delayed(duration, () => hide());
  }
}

/// Premium Loading Overlay với animations
class _PremiumLoadingOverlay extends StatefulWidget {
  final String? message;

  const _PremiumLoadingOverlay({this.message});

  @override
  State<_PremiumLoadingOverlay> createState() => _PremiumLoadingOverlayState();
}

class _PremiumLoadingOverlayState extends State<_PremiumLoadingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Pulse animation for loading card
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Blur background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
          // Loading content
          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: _buildLoadingCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium spinner
          _buildPremiumSpinner(),
          if (widget.message != null) ...[
            const SizedBox(height: 24),
            Text(
              widget.message!,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumSpinner() {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gray50,
            ),
          ),
          // Outer progress
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              backgroundColor: AppTheme.gray100,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
          ),
          // Inner gradient circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accent,
                  AppTheme.accentDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog loading - sử dụng cho các thao tác cần confirm
class LoadingDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    required Future<T> Function() task,
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
  }) async {
    LoadingUtils.show(context, message: loadingMessage);

    try {
      final result = await task();
      LoadingUtils.hide();

      if (successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      return result;
    } catch (e) {
      LoadingUtils.hide();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'An error occurred: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      rethrow;
    }
  }
}
