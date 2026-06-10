class User {
  final String email;
  final String userId;

  User({
    required this.email,
    required this.userId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] as String? ?? '',
      userId: (json['user_id'] ?? json['id']) as String? ?? '',
    );
  }
}
