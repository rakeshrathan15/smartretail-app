/// Mirrors the backend's AuthDtos.UserSummary.
class UserSummary {
  const UserSummary({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.roles,
    required this.shopProfileComplete,
  });

  final String id;
  final String? email;
  final String? phone;
  final String? fullName;
  final List<String> roles;
  final bool shopProfileComplete;

  bool get isAdmin => roles.contains('ADMIN');

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        fullName: json['fullName'] as String?,
        roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
        shopProfileComplete: json['shopProfileComplete'] as bool? ?? false,
      );
}
