class UserProfile {
  final String uid;
  final String name;
  final String email;
  // Add other profile fields as needed, e.g., age, gender, etc.

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
    };
  }
} 