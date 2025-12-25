import 'package:my_porject/configs/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global Error Handler
/// Handles various non-critical errors and logs them appropriately
class ErrorHandler {
  /// Initialize error handling
  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        // In debug mode, show full error
        FlutterError.presentError(details);
      } else {
        // In release mode, log and continue
        _logError(details);
      }
    };

    // Handle platform errors (like WebView HTTP/2 errors)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (kDebugMode) {
        return ErrorWidget(details.exception);
      }
      // In release, show a clean error widget
      return Container(
        color: AppTheme.gray100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.gray400),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray600,
                ),
              ),
            ],
          ),
        ),
      );
    };
  }

  /// Log error to console (can be extended to Firebase Crashlytics)
  static void _logError(FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('=== Flutter Error ===');
      debugPrint('Error: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
      debugPrint('====================');
    }
    
    // TODO: Send to Firebase Crashlytics in production
    // FirebaseCrashlytics.instance.recordFlutterError(details);
  }

  /// Filter common non-critical errors
  static bool isNonCriticalError(String errorMessage) {
    final nonCriticalPatterns = [
      'ERR_HTTP2_PROTOCOL_ERROR',
      'WebResourceError',
      'net::ERR_',
      'isForMainFrame: false',
    ];

    return nonCriticalPatterns.any(
      (pattern) => errorMessage.contains(pattern),
    );
  }

  /// Handle caught exceptions
  static void handleException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? context,
  }) {
    if (kDebugMode) {
      debugPrint('=== Exception ===');
      if (context != null) debugPrint('Context: $context');
      debugPrint('Exception: $exception');
      if (stackTrace != null) debugPrint('Stack: $stackTrace');
      debugPrint('================');
    }

    // TODO: Log to analytics/crashlytics
  }

  /// Show user-friendly error dialog
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.gray700,
            height: 1.4,
          ),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Retry'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
