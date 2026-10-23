import 'story_continuity.dart';

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
    this.visibility = const StoryVisibility(),
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawBoundIds = json['boundCharacterIds'];
    return UserProfile(
      id: json['id']?.toString() ?? '',
      visibility: StoryVisibility.fromJson(json['visibility']),
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
  final StoryVisibility visibility;

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
    StoryVisibility? visibility,
    bool clearBoundCharacterIds = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      visibility: visibility ?? this.visibility,
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
      'visibility': visibility.toJson(),
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
    this.visibility = const StoryVisibility(),
  });

  final String name;
  final String persona;
  final String avatarDataUri;
  final String gender;
  final String description;
  final List<String> boundCharacterIds;
  final StoryVisibility visibility;
}
