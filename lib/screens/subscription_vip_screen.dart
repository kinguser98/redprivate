import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class SubscriptionVipScreen extends StatefulWidget {
  final UserModel user;
  const SubscriptionVipScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SubscriptionVipScreen> createState() => _SubscriptionVipScreenState();
}

class _SubscriptionVipScreenState extends State<SubscriptionVipScreen> {
  final _couponController = TextEditingController();
  bool _isLoading = true;
  bool _isRedeeming = false;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchSubscriptionPlans();
    setState(() {
      _plans = data;
      _isLoading = false;
    });
  }

  Future<void> _redeemCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid coupon code")),
      );
      return;
    }

    setState(() => _isRedeeming = true);
    final res = await ApiService.redeemCoupon(widget.user.id, code);
    setState(() => _isRedeeming = false);

    if (res['status'] == 'success' || res['status'] == 200 || res['message']?.toString().toLowerCase().contains('success') == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? "VIP Subscription Activated Successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      _couponController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? "Invalid or Expired Coupon Code"),
          backgroundColor: const Color(0xFFE50914),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        title: const Text(
          "VIP Membership",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VIP Pass Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8E2DE2).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.workspace_premium,
                          color: Colors.amber, size: 32),
                      SizedBox(width: 10),
                      Text(
                        "RED VIP ACCESS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Unlock Ultra HD 4K Streaming, Ad-Free Watching, and Exclusive Web Series Releases.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Coupon Code Redemption Section
            const Text(
              "Have a Redeem Code / Coupon?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF181824),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _couponController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter Coupon Code (e.g. VIP2026)",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF14141C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon:
                          const Icon(Icons.confirmation_number_outlined,
                              color: Color(0xFFE50914)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isRedeeming ? null : _redeemCoupon,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRedeeming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text(
                              "REDEEM VIP ACCESS",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Subscription Plans List
            const Text(
              "Available Membership Plans",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE50914)))
                : _plans.isEmpty
                    ? const Center(
                        child: Text(
                          "Contact Admin for external payment & VIP access.",
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      )
                    : Column(
                        children: _plans.map((p) {
                          final name = p['name'] ?? 'VIP Pass';
                          final amount = p['amount'] ?? '0';
                          final time = p['time'] ?? '30';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181824),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.purpleAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 36),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Duration: $time Days • ₹$amount",
                                        style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "VIP",
                                    style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ],
        ),
      ),
    );
  }
}
