class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.persona,
    this.avatarDataUri = '',
    this.gender = '',
    this.description = '',
    this.boundCharacterIds = const <String>[],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawBoundIds = json['boundCharacterIds'];
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '未命名用户',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      persona: json['persona']?.toString() ?? '',
      avatarDataUri: json['avatarDataUri']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      boundCharacterIds: rawBoundIds is List
          ? rawBoundIds.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final String persona;
  final String avatarDataUri;
  final String gender;
  final String description;
  final List<String> boundCharacterIds;

  bool isBoundTo(String characterId) {
    return boundCharacterIds.contains(characterId);
  }

  UserProfile copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? persona,
    String? avatarDataUri,
    String? gender,
    String? description,
    List<String>? boundCharacterIds,
    bool clearBoundCharacterIds = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      persona: persona ?? this.persona,
      avatarDataUri: avatarDataUri ?? this.avatarDataUri,
      gender: gender ?? this.gender,
      description: description ?? this.description,
      boundCharacterIds: clearBoundCharacterIds
          ? const <String>[]
          : boundCharacterIds ?? this.boundCharacterIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'persona': persona,
      'avatarDataUri': avatarDataUri,
      'gender': gender,
      'description': description,
      'boundCharacterIds': boundCharacterIds,
    };
  }
}

class UserProfileDraft {
  const UserProfileDraft({
    required this.name,
    required this.persona,
    this.avatarDataUri = '',
    this.gender = '',
    this.description = '',
    this.boundCharacterIds = const <String>[],
  });

  final String name;
  final String persona;
  final String avatarDataUri;
  final String gender;
  final String description;
  final List<String> boundCharacterIds;
}
