import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// Friendly error message without raw server URLs.
String friendlyError(Object? error, String fallback) {
  if (error == null) return fallback;
  final str = error.toString().trim();
  if (str.isEmpty) return fallback;

  // Preserve direct human-readable API messages (e.g. "Email already registered")
  if (!str.contains('Exception') &&
      !str.contains('HTTP ') &&
      !str.contains('SocketException') &&
      !str.contains('http://') &&
      !str.contains('https://')) {
    return str;
  }

  final s = str.toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('connection refused') ||
      s.contains('connection reset') ||
      s.contains('connection closed') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('host unreachable')) {
    return 'No internet connection. Please check your Wi-Fi or mobile data.';
  }
  if (s.contains('timeout') || s.contains('timed out')) {
    return 'The server is taking too long to respond. Please try again.';
  }
  if (s.contains('403') || s.contains('forbidden')) {
    return 'Access denied by the server. Please contact support.';
  }
  if (s.contains('404') || s.contains('not found')) {
    return 'The requested content could not be found on the server.';
  }
  if (s.contains('500') || s.contains('502') || s.contains('503') || s.contains('server error')) {
    return 'The server is temporarily busy. Please try again later.';
  }
  if (s.contains('bad certificate') || s.contains('certificate') || s.contains('ssl') || s.contains('tls')) {
    return 'A secure connection could not be established. Please try again.';
  }
  if (s.contains('failed to connect') || s.contains('failed connection') || s.contains('unable to access')) {
    return 'Unable to reach the server. Please try again.';
  }
  return fallback;
}

/// Modern full-screen error view with a retry button and admin contact info.
class AppErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String? adminLink;

  const AppErrorView({
    Key? key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.adminLink,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing error orb
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14, height: 1.5),
              ),
              if (adminLink != null && adminLink!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    'Need help? Contact: $adminLink',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('TRY AGAIN',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern loading view (used for details / screens while fetching).
class AppLoadingView extends StatelessWidget {
  final String? label;
  const AppLoadingView({Key? key, this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SpinKitFadingCircle(color: Color(0xFFE50914), size: 48),
            if (label != null) ...[
              const SizedBox(height: 20),
              Text(
                label!,
                style: const TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a modern error popup dialog.
Future<void> showAppErrorDialog(
  BuildContext context, {
  String title = 'Oops!',
  required String message,
  VoidCallback? onRetry,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF1A1A24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE50914).withOpacity(0.45),
                    blurRadius: 22,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CLOSE',
                      style: TextStyle(color: Colors.white70)),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onRetry();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('RETRY',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
