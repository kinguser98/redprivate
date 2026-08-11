import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../themes/app_colors.dart';
import 'admin/hidden_admin_screen.dart';
import 'auth/login_register_screen.dart';
import 'downloads_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'subscription_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel user;
  const SettingsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _secretTapCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshUser();
  }

  void _handleAppVersionTap() {
    setState(() => _secretTapCount++);
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _showAdminPinDialog();
    }
  }

  void _showAdminPinDialog() {
    String enteredPin = "";
    bool checking = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void handleKey(String digit) {
            if (enteredPin.length < 4) {
              setDialogState(() {
                enteredPin += digit;
              });
            }
          }

          void handleBackspace() {
            if (enteredPin.isNotEmpty) {
              setDialogState(() {
                enteredPin = enteredPin.substring(0, enteredPin.length - 1);
              });
            }
          }

          Future<void> submit() async {
            if (enteredPin.length < 4) return;
            setDialogState(() => checking = true);
            final ok = await _validateAdminPin(enteredPin);
            if (!ctx.mounted) return;
            setDialogState(() => checking = false);
            if (ok) {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HiddenAdminScreen()),
              );
            } else {
              setDialogState(() {
                enteredPin = "";
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Invalid Admin PIN")),
              );
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Center(
              child: Text(
                "Admin Portal Lock",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final hasDigit = index < enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasDigit ? AppColors.accent : Colors.white24,
                          border: Border.all(color: Colors.white30, width: 1),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),
                  checking
                      ? const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDialRow([
                              _buildDialButton("1", () => handleKey("1")),
                              _buildDialButton("2", () => handleKey("2")),
                              _buildDialButton("3", () => handleKey("3")),
                            ]),
                            _buildDialRow([
                              _buildDialButton("4", () => handleKey("4")),
                              _buildDialButton("5", () => handleKey("5")),
                              _buildDialButton("6", () => handleKey("6")),
                            ]),
                            _buildDialRow([
                              _buildDialButton("7", () => handleKey("7")),
                              _buildDialButton("8", () => handleKey("8")),
                              _buildDialButton("9", () => handleKey("9")),
                            ]),
                            _buildDialRow([
                              _buildDialButton("⌫", handleBackspace, isIcon: true),
                              _buildDialButton("0", () => handleKey("0")),
                              _buildDialButton("✔", submit, isIcon: true, isAction: true),
                            ]),
                          ],
                        ),
                ],
              ),
            ),
            actions: [
              Center(
                child: TextButton(
                  child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialButton(String text, VoidCallback onPressed, {bool isIcon = false, bool isAction = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isAction ? AppColors.accent.withOpacity(0.15) : const Color(0xFF2C2C3C),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isAction ? AppColors.accent.withOpacity(0.4) : Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: isIcon
                ? Text(
                    text,
                    style: TextStyle(
                      color: isAction ? Colors.greenAccent : Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialRow(List<Widget> buttons) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 55, child: buttons[i])),
          ],
        ],
      ),
    );
  }

  Future<bool> _validateAdminPin(String entered) async {
    try {
      final res = await ApiService.fetchAppSettings();
      final settings = res['data']?['settings'];
      final serverPin =
          (settings != null ? settings['admin_pin']?.toString() : '') ?? '';
      final expected = serverPin.isNotEmpty ? serverPin : '8888';
      return entered == expected;
    } catch (_) {
      return entered == '8888';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.user ?? widget.user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text("Settings & Account",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Profile Card ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.accent,
                    backgroundImage: user.profilePic.isNotEmpty
                        ? CachedNetworkImageProvider(user.profilePic)
                        : null,
                    child: user.profilePic.isNotEmpty
                        ? null
                        : Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Text(user.email,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Active Device Card ---
            _DeviceInfoCard(),

            const SizedBox(height: 24),

            _buildSettingTile(Icons.person_outline, "Edit Profile", () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: user),
                ),
              );
              if (updated == true) _refreshUser();
            }),
            _buildSettingTile(Icons.favorite_outline, "My Favorites", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            }),
            _buildSettingTile(Icons.download_outlined, "Downloads Manager", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            }),
            _buildSettingTile(Icons.history_outlined, "Clear Watch History", () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text("Clear Watch History?",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: const Text(
                      "Are you sure you want to clear all items in your Continue Playing watch history?",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    TextButton(
                      child: const Text("CLEAR",
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                final res = await ApiService.clearWatchHistory(user.id.toString());
                if (mounted) {
                  if (res['status'] == 'success') {
                    final prefs = await SharedPreferences.getInstance();
                    final keys = prefs.getKeys();
                    for (final key in keys.toList()) {
                      if (key.startsWith('progress_') || key.startsWith('duration_')) {
                        await prefs.remove(key);
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Watch history cleared!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed: ${res['message'] ?? 'Unknown error'}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            }),
            _buildSettingTile(
              Icons.card_membership_outlined,
              user.isVip
                  ? "Subscription Status (VIP Active)"
                  : "Subscription Status (Free)",
              () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubscriptionDetailsScreen(user: user),
                  ),
                );
                _refreshUser();
              },
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ApiService.logout();
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text("LOG OUT",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 40),
            GestureDetector(
              onTap: _handleAppVersionTap,
              child: Center(
                child: Column(
                  children: [
                    Text("Red App v1.0.0",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    Text("Cinema Engine",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshUser() async {
    final fresh = await ApiService.refreshUser(AppSession.user?.id ?? widget.user.id);
    if (fresh != null) {
      AppSession.user = fresh;
      await ApiService.saveUserSession(fresh);
    }
    if (mounted) setState(() {});
  }

  Widget _buildSettingTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class _DeviceInfoCard extends StatefulWidget {
  @override
  State<_DeviceInfoCard> createState() => _DeviceInfoCardState();
}

class _DeviceInfoCardState extends State<_DeviceInfoCard> {
  String _deviceName = '';
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await ApiService.getDeviceId();
    final name = ApiService.getDeviceName();
    if (mounted) {
      setState(() {
        _deviceId = id.length > 16 ? '${id.substring(0, 8)}...${id.substring(id.length - 8)}' : id;
        _deviceName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_android_rounded, color: Colors.cyanAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACTIVE DEVICE',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 3),
                Text(
                  _deviceName.isEmpty ? 'Loading...' : _deviceName,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${_deviceId.isEmpty ? '...' : _deviceId}',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('THIS DEVICE', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }
}
