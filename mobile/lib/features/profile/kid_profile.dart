/// A child linked to the member profile.
class KidProfile {  const KidProfile({required this.name, this.birthDate});

  final String name;
  final DateTime? birthDate;

  factory KidProfile.fromJson(Map<String, dynamic> json) {
    final rawDate = json["birth_date"]?.toString();
    DateTime? birthDate;
    if (rawDate != null && rawDate.isNotEmpty) {
      birthDate = DateTime.tryParse(rawDate);
    }
    return KidProfile(
      name: json["name"]?.toString().trim() ?? "",
      birthDate: birthDate == null
          ? null
          : DateTime(birthDate.year, birthDate.month, birthDate.day),
    );
  }

  Map<String, dynamic> toJson() {
    final date = birthDate;
    return {
      "name": name,
      if (date != null)
        "birth_date":
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
    };
  }

  int? get age {
    final dob = birthDate;
    if (dob == null) return null;
    final today = DateTime.now();
    var years = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      years--;
    }
    return years;
  }

  String get displayLabel {
    final years = age;
    if (years == null) return name;
    return "$name · $years yrs";
  }
}

List<KidProfile> parseKidsList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => KidProfile.fromJson(Map<String, dynamic>.from(item)))
      .where((kid) => kid.name.isNotEmpty)
      .toList();
}
