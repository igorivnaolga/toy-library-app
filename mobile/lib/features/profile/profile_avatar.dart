import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

String memberFirstName(String? fullName) {
  final trimmed = fullName?.trim() ?? "";
  if (trimmed.isEmpty) return "";
  return trimmed.split(RegExp(r"\s+")).first;
}

/// Profile heading when Parent B is registered, e.g. "Jay & Emma".
String memberDisplayLabel({
  String? fullName,
  String? parentBName,
}) {
  final firstA = memberFirstName(fullName);
  final firstB = memberFirstName(parentBName);
  if (firstA.isEmpty && firstB.isEmpty) return "";
  if (firstB.isEmpty) return firstA;
  if (firstA.isEmpty) return firstB;
  return "$firstA & $firstB";
}

String memberAvatarInitials({
  String? fullName,
  String? parentBName,
}) {
  final firstA = memberFirstName(fullName);
  final firstB = memberFirstName(parentBName);
  if (firstA.isNotEmpty && firstB.isNotEmpty) {
    return "${firstA[0]}&${firstB[0]}".toUpperCase();
  }
  return ProfileAvatar.initialsFor(fullName);
}

/// Circular avatar with photo or initials fallback.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.fullName,
    this.parentBName,
    this.avatarPath,
    this.radius = 18,
    this.onTap,
  });

  final String? fullName;
  final String? parentBName;
  final String? avatarPath;
  final double radius;
  final VoidCallback? onTap;

  String? resolveAvatarUrl() {
    final path = avatarPath?.trim();
    if (path == null || path.isEmpty) return null;
    if (path.startsWith("http://") || path.startsWith("https://")) {
      return path;
    }
    try {
      return Supabase.instance.client.storage.from("avatars").getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  static String initialsFor(String? fullName) {
    final name = fullName?.trim();
    if (name == null || name.isEmpty) return "?";
    final parts =
        name.split(RegExp(r"\s+")).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return "${parts.first[0]}${parts.last[0]}".toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = resolveAvatarUrl();
    final parentB = parentBName?.trim();
    final initials = memberAvatarInitials(
      fullName: fullName,
      parentBName: parentB,
    );

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Padding(
              padding: EdgeInsets.all(radius * 0.12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initials,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: radius * 0.85,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            )
          : null,
    );

    if (onTap == null) return avatar;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      ),
    );
  }
}
