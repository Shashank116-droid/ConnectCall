class UserModel {
  final String uid;
  final String email;
  final String name;
  final bool isOnline;
  final String? fcmToken;
  final String? profileImageUrl;
  final DateTime? lastSeen;
  final List<String> blockedUsers;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.isOnline = false,
    this.fcmToken,
    this.profileImageUrl,
    this.lastSeen,
    this.blockedUsers = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      isOnline: json['isOnline'] ?? false,
      fcmToken: json['fcmToken'],
      profileImageUrl: json['profileImageUrl'],
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
      blockedUsers: List<String>.from(json['blockedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'isOnline': isOnline,
      'fcmToken': fcmToken,
      'profileImageUrl': profileImageUrl,
      'lastSeen': lastSeen?.toIso8601String(),
      'blockedUsers': blockedUsers,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    bool? isOnline,
    String? fcmToken,
    String? profileImageUrl,
    DateTime? lastSeen,
    List<String>? blockedUsers,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      isOnline: isOnline ?? this.isOnline,
      fcmToken: fcmToken ?? this.fcmToken,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastSeen: lastSeen ?? this.lastSeen,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}
