class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String activeSubscription;
  final String subscriptionExp;
  final String profilePic;
  final String subscriptionStart;
  final int subscriptionTime;
  final int subscriptionAmount;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'user',
    this.activeSubscription = 'Free',
    this.subscriptionExp = '',
    this.profilePic = '',
    this.subscriptionStart = '',
    this.subscriptionTime = 0,
    this.subscriptionAmount = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role']?.toString() ?? 'user',
      activeSubscription: json['active_subscription']?.toString() ?? 'Free',
      subscriptionExp: json['subscription_exp']?.toString() ?? '',
      profilePic: json['profile_pic']?.toString() ?? '',
      subscriptionStart: json['subscription_start']?.toString() ?? '',
      subscriptionTime: int.tryParse(json['time']?.toString() ?? '') ?? 0,
      subscriptionAmount: int.tryParse(json['amount']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'active_subscription': activeSubscription,
        'subscription_exp': subscriptionExp,
        'profile_pic': profilePic,
        'subscription_start': subscriptionStart,
        'time': subscriptionTime,
        'amount': subscriptionAmount,
      };

  bool get isVip {
    final low = activeSubscription.toLowerCase().trim();
    if (low.isEmpty ||
        low == '0' ||
        low == 'free' ||
        low == 'none' ||
        low == 'null' ||
        low == 'false') {
      return false;
    }
    final exp = subscriptionExp.trim();
    if (exp.isNotEmpty &&
        exp != '0000-00-00' &&
        exp != '0000-00-00 00:00:00') {
      final dt = DateTime.tryParse(exp);
      if (dt != null && dt.isBefore(DateTime.now())) return false;
    }
    return true;
  }
}

class AppSession {
  static UserModel? user;

  /// True when a real account is in session (not the anonymous guest placeholder)
  static bool get isLoggedIn =>
      user != null &&
      user!.email.isNotEmpty &&
      user!.email != 'guest@redapp.space';

  /// True when app is running in anonymous browse mode (no account)
  static bool get isGuest => !isLoggedIn;

  static bool get isVip => user?.isVip ?? false;

  static void Function()? onGlobalLogout;

  static void triggerGlobalLogout() {
    if (onGlobalLogout != null) {
      onGlobalLogout!();
    }
  }
}
