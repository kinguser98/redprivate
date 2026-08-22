import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/app_error_widget.dart';
import '../main_layout_screen.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({Key? key}) : super(key: key);

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeIn;
  bool _isLogin = true;

  final _loginEmailController = TextEditingController();
  final _loginPassController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPassController = TextEditingController();

  bool _isLoading = false;
  bool _obscureLogin = true;
  bool _obscureReg = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _loginEmailController.dispose();
    _loginPassController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPassController.dispose();
    super.dispose();
  }

  void _switchMode(bool login) {
    if (_isLogin == login) return;
    setState(() {
      _isLogin = login;
      _errorMessage = '';
    });
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _handleLogin({bool forceLogin = false}) async {
    final email = _loginEmailController.text.trim();
    final pass = _loginPassController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await ApiService.login(email, pass, forceLogin: forceLogin);
    setState(() => _isLoading = false);

    if (res['status'] == 'success' && res['data']?['user'] != null) {
      final user = UserModel.fromJson(res['data']['user']);
      AppSession.user = user;
      await ApiService.saveUserSession(user);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainLayoutScreen(user: user)),
      );
    } else if (res['data']?['device_conflict'] == true) {
      // Another device is actively using this account
      final oldDevice = res['data']['old_device_name'] ?? 'Another device';
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A2132),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.devices, color: Colors.orangeAccent),
              SizedBox(width: 10),
              Text('Device Limit Reached', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your account is already logged in on another device:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        oldDevice,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Only 1 device can be logged in at a time. Logging in here will automatically log out the other device.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _handleLogin(forceLogin: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Logout old device & login here', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      );
    } else {
      setState(() =>
          _errorMessage = friendlyError(res['message'], 'Login failed'));
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final pass = _regPassController.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Please fill all required fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await ApiService.register(name, email, pass);
    setState(() => _isLoading = false);

    if (res['status'] == 'success' && res['data']?['user'] != null) {
      final user = UserModel.fromJson(res['data']['user']);
      AppSession.user = user;
      await ApiService.saveUserSession(user);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainLayoutScreen(user: user)),
      );
    } else {
      setState(() =>
          _errorMessage = friendlyError(res['message'], 'Registration failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Full-screen gradient background (covers 100% of the screen)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2A0A14),
                    Color(0xFF0D0D12),
                    Color(0xFF0D0D12),
                    Color(0xFF2A0A14),
                  ],
                  stops: [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),
          // Ambient gradient glows
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(size: 260, color: const Color(0xFF8E2DE2)),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _GlowOrb(size: 300, color: const Color(0xFFE50914)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFE50914).withOpacity(0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFFE50914).withOpacity(0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Brand
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
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
                                  blurRadius: 28,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "R C",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -3.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            "RED CHILLIES",
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFFE50914).withOpacity(0.7),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Stream unlimited movies & web series",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Mode switch pill
                    Container(
                      height: 52,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeButton(
                              label: "SIGN IN",
                              active: _isLogin,
                              onTap: () => _switchMode(true),
                            ),
                          ),
                          Expanded(
                            child: _ModeButton(
                              label: "CREATE ACCOUNT",
                              active: !_isLogin,
                              onTap: () => _switchMode(false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    if (_errorMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1517),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE50914).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFE50914), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_errorMessage,
                                  style: GoogleFonts.inter(
                                      color: Colors.redAccent, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Forms
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim, child: child),
                      child: _isLogin
                          ? _buildLoginForm()
                          : _buildRegisterForm(),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLogin
                              ? "New to Red App? "
                              : "Already have an account? ",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () => _switchMode(!_isLogin),
                          child: Text(
                            _isLogin ? "Create Account" : "Sign In",
                            style: const TextStyle(
                              color: Color(0xFFE50914),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      children: [
        _buildField(_loginEmailController, "Email Address",
            Icons.alternate_email_rounded, TextInputType.emailAddress),
        const SizedBox(height: 14),
        _buildField(_loginPassController, "Password",
            Icons.lock_rounded, TextInputType.visiblePassword,
            isObscure: _obscureLogin,
            suffix: IconButton(
              icon: Icon(_obscureLogin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38, size: 20),
              onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
            )),
        const SizedBox(height: 26),
        _buildSubmitButton("SIGN IN", Icons.login_rounded, _handleLogin),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey('register'),
      children: [
        _buildField(_regNameController, "Full Name",
            Icons.person_outline_rounded, TextInputType.name),
        const SizedBox(height: 14),
        _buildField(_regEmailController, "Email Address",
            Icons.alternate_email_rounded, TextInputType.emailAddress),
        const SizedBox(height: 14),
        _buildField(_regPassController, "Password",
            Icons.lock_rounded, TextInputType.visiblePassword,
            isObscure: _obscureReg,
            suffix: IconButton(
              icon: Icon(_obscureReg ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38, size: 20),
              onPressed: () => setState(() => _obscureReg = !_obscureReg),
            )),
        const SizedBox(height: 26),
        _buildSubmitButton("CREATE ACCOUNT", Icons.person_add_alt_1_rounded, _handleRegister),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String hint,
      IconData icon, TextInputType keyboardType,
      {bool isObscure = false, Widget? suffix}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF8E2DE2), size: 20),
        suffixIcon: suffix,
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF14141C),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF8E2DE2), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(
      String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE50914),
          disabledBackgroundColor: const Color(0xFFE50914).withOpacity(0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: const Color(0xFFE50914).withOpacity(0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white)),
                ],
              ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFE50914).withOpacity(0.4),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: active ? Colors.white : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.25),
              color.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
