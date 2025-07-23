class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? age;
  final String? healthCondition;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.age,
    this.healthCondition,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      age: data['age'],
      healthCondition: data['healthCondition'],
      createdAt: data['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt']) 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'age': age,
      'healthCondition': healthCondition,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? age,
    String? healthCondition,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      healthCondition: healthCondition ?? this.healthCondition,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 