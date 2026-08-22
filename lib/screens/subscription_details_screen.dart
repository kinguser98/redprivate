import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'subscription_vip_screen.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  final UserModel user;
  const SubscriptionDetailsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SubscriptionDetailsScreen> createState() => _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  List<dynamic> _history = [];
  List<dynamic> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.getSubscriptionDetails();
    if (!mounted) return;
    if (res['status'] == 'success' && res['data'] != null) {
      setState(() {
        _user = res['data']['user'];
        _history = res['data']['history'] as List? ?? [];
        _plans = res['data']['plans'] as List? ?? [];
        _loading = false;
      });
    } else {
      setState(() {
        _user = {
          'id': widget.user.id,
          'name': widget.user.name,
          'email': widget.user.email,
          'active_subscription': widget.user.activeSubscription,
          'subscription_exp': widget.user.subscriptionExp,
          'subscription_start': widget.user.subscriptionStart,
          'time': widget.user.subscriptionTime,
          'amount': widget.user.subscriptionAmount,
        };
        _history = [];
        _plans = [];
        _loading = false;
      });
    }
    if (_plans.isEmpty) {
      final plans = await ApiService.fetchSubscriptionPlans();
      if (mounted && plans.isNotEmpty) {
        setState(() => _plans = plans);
      }
    }
  }

  bool get _isVip {
    final sub = (_user?['active_subscription'] ?? '').toString().trim().toLowerCase();
    if (sub.isEmpty || sub == '0' || sub == 'free' || sub == 'none' || sub == 'null' || sub == 'false' || sub == '1') {
      return false;
    }
    final exp = (_user?['subscription_exp'] ?? '').toString().trim();
    if (exp.isNotEmpty && exp != '0000-00-00' && exp != '0000-00-00 00:00:00') {
      final dt = DateTime.tryParse(exp);
      if (dt != null && dt.isBefore(DateTime.now())) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        title: const Text("Subscription",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8E2DE2)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current status card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isVip
                                ? [const Color(0xFF8E2DE2), const Color(0xFFE50914)]
                                : [const Color(0xFF232A3C), const Color(0xFF161B28)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: _isVip ? Colors.amber.withOpacity(0.4) : Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_isVip ? Icons.workspace_premium_rounded : Icons.lock_rounded,
                                    color: _isVip ? Colors.amber : Colors.white54, size: 30),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isVip ? "VIP ACTIVE" : "FREE PLAN",
                                    style: TextStyle(
                                        color: _isVip ? Colors.amber : Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _detailRow("Plan", (_user?['active_subscription'] ?? 'Free').toString()),
                            _detailRow("Duration",
                                _durationValue()),
                            _detailRow("Amount",
                                _amountValue()),
                            _detailRow("Started",
                                _startedValue()),
                            _detailRow("Expires", '${_user?['subscription_exp'] ?? 'N/A'}'),
                            if (!_isVip) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SubscriptionVipScreen(user: widget.user),
                                      ),
                                    ).then((_) => _load());
                                  },
                                  icon: const Icon(Icons.workspace_premium_rounded),
                                  label: const Text("GET VIP / REDEEM COUPON",
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE50914),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Active Device Card ---
                      _SubscriptionDeviceCard(),

                      const SizedBox(height: 20),

                      // Current plans
                      if (_plans.isNotEmpty) ...[
                        const Text("Available Plans",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ..._plans.map((p) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2132),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${p['name'] ?? 'VIP'}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text('${p['time'] ?? 0} Days • ₹${p['amount'] ?? 0}',
                                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 20),
                      ],

                      // Subscription history
                      const Text("Subscription History",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (_history.isEmpty)
                        const Text("No subscription history yet.",
                            style: TextStyle(color: Colors.white38, fontSize: 13))
                      else
                        ..._history.map((h) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2132),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('${h['plan_name'] ?? 'VIP'}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8E2DE2).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text('${h['method'] ?? ''}',
                                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${h['days'] ?? 0} Days • ₹${h['amount'] ?? 0}  •  Started ${h['started'] ?? ''}  •  Exp ${h['expires'] ?? ''}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  String _durationValue() {
    final raw = _user?['time'];
    if (raw == null || raw.toString().trim().isEmpty || raw == 0) return 'N/A';
    return '$raw Days';
  }

  String _amountValue() {
    final raw = _user?['amount'];
    if (raw == null || raw.toString().trim().isEmpty || raw == 0) return 'N/A';
    return '₹$raw';
  }

  String _startedValue() {
    final raw = _user?['subscription_start']?.toString().trim() ?? '';
    if (raw.isEmpty || raw == '0000-00-00' || raw == '0000-00-00 00:00:00') {
      return 'N/A';
    }
    return raw;
  }
}

class _SubscriptionDeviceCard extends StatefulWidget {
  @override
  State<_SubscriptionDeviceCard> createState() => _SubscriptionDeviceCardState();
}

class _SubscriptionDeviceCardState extends State<_SubscriptionDeviceCard> {
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2132),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF0097A7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'ACTIVE SESSION DEVICE',
                style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: const Text('ONLINE', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row(Icons.devices_rounded, 'Device', _deviceName.isEmpty ? 'Loading...' : _deviceName),
          const SizedBox(height: 6),
          _row(Icons.fingerprint_rounded, 'Device ID', _deviceId.isEmpty ? '...' : _deviceId),
          const SizedBox(height: 6),
          _row(Icons.info_outline_rounded, 'Session', 'This device only (1 device limit)'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
