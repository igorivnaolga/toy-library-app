/// Member row from `GET /api/v1/duty/members` (volunteer desk walk-in).
class DeskMember {
  const DeskMember({
    required this.userId,
    required this.fullName,
    required this.email,
  });

  final String userId;
  final String fullName;
  final String email;

  factory DeskMember.fromJson(Map<String, dynamic> json) {
    return DeskMember(
      userId: json["user_id"]?.toString() ?? "",
      fullName: json["full_name"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
    );
  }

  String get displayLabel {
    if (fullName.isNotEmpty && email.isNotEmpty) {
      return "$fullName · $email";
    }
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) return email;
    return userId;
  }
}

List<DeskMember> parseDeskMemberList(Map<String, dynamic> json) {
  final raw = json["data"];
  if (raw is! List<dynamic>) return [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(DeskMember.fromJson)
      .toList();
}
