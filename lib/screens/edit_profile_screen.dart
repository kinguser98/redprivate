import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/hero_avatars.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late String _picUrl;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _picUrl = widget.user.profilePic;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomInset),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("Choose Profile Avatar",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text("Pick a comic hero avatar or remove it.",
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: HeroAvatars.all.length,
                    itemBuilder: (context, index) {
                      final hero = HeroAvatars.all[index];
                      final selected = _picUrl == hero.url;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _picUrl = hero.url);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFE50914)
                                  : Colors.white24,
                              width: selected ? 3 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFE50914)
                                          .withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: hero.url,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => Container(
                                color: const Color(0xFF1E1E28),
                                child: Center(
                                  child: Text(
                                    hero.name.isNotEmpty ? hero.name[0] : '?',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _picUrl = '');
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text("Remove avatar",
                          style:
                              TextStyle(color: Colors.white54, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name cannot be empty")),
      );
      return;
    }
    final newPass = _newPassCtrl.text;
    if (newPass.isNotEmpty && newPass.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New password must be at least 4 characters")),
      );
      return;
    }
    setState(() => _saving = true);

    // Save locally first so the change is never lost.
    final localUser = UserModel(
      id: widget.user.id,
      name: name,
      email: widget.user.email,
      role: widget.user.role,
      activeSubscription: widget.user.activeSubscription,
      subscriptionExp: widget.user.subscriptionExp,
      profilePic: _picUrl,
    );
    AppSession.user = localUser;
    await ApiService.saveUserSession(localUser);

    final res = await ApiService.updateProfile(
      name: name,
      profilePic: _picUrl,
      currentPassword: _currentPassCtrl.text,
      newPassword: newPass,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['status'] == 'success') {
      final updated = res['data']?['user'];
      if (updated != null) {
        final user = UserModel.fromJson(updated);
        AppSession.user = user;
        await ApiService.saveUserSession(user);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated"), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      final msg = (res['message'] ?? '').toString();
      if (msg.contains('Current password') || msg.contains('password')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Password change failed: $msg"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved on this device (server offline). It will sync later."),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroName = HeroAvatars.nameFor(_picUrl);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        title: const Text("Edit Profile",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar preview with change button
            Center(
              child: GestureDetector(
                onTap: _showAvatarPicker,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFF2A3145),
                          backgroundImage: _picUrl.trim().isNotEmpty
                              ? CachedNetworkImageProvider(_picUrl.trim())
                              : null,
                          child: _picUrl.trim().isEmpty
                              ? Text(
                                  _nameCtrl.text.isNotEmpty
                                      ? _nameCtrl.text[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF0D0D12), width: 2),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text("Change Profile Icon",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(heroName.isNotEmpty ? heroName : "No avatar selected",
                        style:
                            const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Name",
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF141722),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Password change
            const Text("Change Password",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text("Enter your current password, then a new one (min 4 characters).",
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _currentPassCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Current Password",
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF141722),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPassCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "New Password (leave blank to keep)",
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.lock_reset_rounded, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF141722),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF14141C),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                _saving ? "SAVING..." : "SAVE PROFILE",
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shadowColor: const Color(0xFFE50914).withOpacity(0.6),
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
