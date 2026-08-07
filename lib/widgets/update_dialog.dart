import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> settings;

  const UpdateDialog({Key? key, required this.settings}) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _localApkPath;
  String? _error;
  http.Client? _httpClient;

  late String _latestVersion;
  late bool _skippable;
  late String _urlV7a;
  late String _urlV8a;
  late String _urlUniversal;

  @override
  void initState() {
    super.initState();
    _latestVersion = widget.settings['latest_version']?.toString() ?? '1.0.0';
    _skippable = widget.settings['update_skippable']?.toString() == '1';
    _urlV7a = widget.settings['download_url_v7a']?.toString() ?? '';
    _urlV8a = widget.settings['download_url_v8a']?.toString() ?? '';
    _urlUniversal = widget.settings['download_url_universal']?.toString() ?? '';
  }

  Future<void> _startDownload(String url, String archLabel) async {
    if (url.isEmpty) {
      setState(() => _error = "Download URL is not configured on the server.");
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
      _localApkPath = null;
    });

    try {
      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await _httpClient!.send(request);

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final dir = await getTemporaryDirectory();
      final safeLabel = archLabel.replaceAll(RegExp(r'[^\w]'), '_');
      final file = File('${dir.path}/redapp_${safeLabel}_$_latestVersion.apk');
      if (file.existsSync()) file.deleteSync();

      final sink = file.openWrite();

      await response.stream.forEach((chunk) {
        if (!_downloading) {
          throw Exception("Download cancelled");
        }
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _progress = downloaded / contentLength;
          });
        }
      });

      await sink.close();
      _httpClient?.close();
      _httpClient = null;

      if (mounted) {
        setState(() {
          _downloading = false;
          _localApkPath = file.path;
        });
        // Automatically request permission and trigger installation on finish
        _installApk();
      }
    } catch (e) {
      _httpClient?.close();
      _httpClient = null;
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = e.toString().contains("cancelled") ? "Download cancelled." : "Download failed: $e";
        });
      }
    }
  }

  void _cancelDownload() {
    _downloading = false;
    _httpClient?.close();
    _httpClient = null;
    setState(() {
      _progress = 0.0;
    });
  }

  Future<void> _installApk() async {
    if (_localApkPath == null) return;
    
    // Request install packages permission (needed for Android 8.0+)
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Installation permission is required to update the app."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    try {
      final result = await OpenFilex.open(_localApkPath!);
      if (result.type != ResultType.done && mounted) {
        setState(() {
          _error = "Could not open installer: ${result.message}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to run package installer: $e";
        });
      }
    }
  }

  void _deleteInstaller() {
    if (_localApkPath != null) {
      try {
        final file = File(_localApkPath!);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
      setState(() {
        _localApkPath = null;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _httpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _skippable ? "New Update Available" : "Mandatory Update Required";
    final descText = _skippable
        ? "A new version of Red App (v$_latestVersion) is available! Select an option below to download and install."
        : "You must update to the latest version (v$_latestVersion) to continue using Red App. Select your phone architecture below to begin.";

    return WillPopScope(
      onWillPop: () async => _skippable && !_downloading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A).withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE50914).withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE50914).withOpacity(0.15),
                blurRadius: 36,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update_rounded, color: Color(0xFFE50914), size: 28),
                  ),
                  if (_skippable && !_downloading)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              
              // Title & Desc
              Text(
                titleText,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                descText,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Downloading Progress View
              if (_downloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Downloading update package...",
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                        Text("${(_progress * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(color: Color(0xFFE50914), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white10,
                        color: const Color(0xFFE50914),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _cancelDownload,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ],
                ),
              ]
              // Installed/Ready View
              else if (_localApkPath != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Download completed! Click Install to proceed.",
                              style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _installApk,
                      icon: const Icon(Icons.install_mobile_rounded, size: 18),
                      label: const Text("INSTALL UPDATE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _deleteInstaller,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      label: const Text("Delete Installer File", style: TextStyle(color: Colors.redAccent)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ]
              // Download Selection Grid
              else ...[
                _buildDownloadCard(
                  title: "v7a Release APK",
                  subtitle: "Best for Normal / Older Phones",
                  url: _urlV7a,
                  label: "v7a",
                ),
                const SizedBox(height: 8),
                _buildDownloadCard(
                  title: "v8a Release APK",
                  subtitle: "Best for New / High-end Phones",
                  url: _urlV8a,
                  label: "v8a",
                ),
                const SizedBox(height: 8),
                _buildDownloadCard(
                  title: "Universal Full APK",
                  subtitle: "Full Release Installer (High Size)",
                  url: _urlUniversal,
                  label: "universal",
                ),
                if (_skippable) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Skip Update", style: TextStyle(color: Colors.white38)),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadCard({
    required String title,
    required String subtitle,
    required String url,
    required String label,
  }) {
    final bool configured = url.isNotEmpty;

    return InkWell(
      onTap: configured ? () => _startDownload(url, label) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: configured ? const Color(0xFF1E1E28) : Colors.black12,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: configured ? Colors.white.withOpacity(0.06) : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: configured ? const Color(0xFFE50914).withOpacity(0.1) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.download_rounded,
                color: configured ? const Color(0xFFE50914) : Colors.white24,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: configured ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    configured ? subtitle : "Not configured on server",
                    style: TextStyle(
                      color: configured ? Colors.white54 : Colors.white24,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: configured ? Colors.white30 : Colors.white12,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
