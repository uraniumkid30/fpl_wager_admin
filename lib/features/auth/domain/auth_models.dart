class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.status = 'active',
    this.role = 'user',
    this.emailVerified = false,
    this.fplEntryId,
  });

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
        id: json['id']! as String,
        fullName: json['full_name']! as String,
        email: json['email']! as String,
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        role: json['role'] as String? ?? 'user',
        emailVerified: json['email_verified'] as bool? ?? false,
        fplEntryId: (json['fpl_entry_id'] as num?)?.toInt(),
      );

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String status;
  final String role;
  final bool emailVerified;

  /// Set for accounts that signed in with FPL; null for password accounts.
  final int? fplEntryId;

  String get firstName {
    final value = fullName.trim();
    return value.isEmpty ? 'Admin' : value.split(RegExp(r'\s+')).first;
  }

  bool get isAdmin => role == 'admin' || role == 'superadmin';
  bool get isSuperadmin => role == 'superadmin';
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserProfile user;
  final String accessToken;
  final String refreshToken;
}
