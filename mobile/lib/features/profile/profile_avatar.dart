import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Circular avatar with photo or initials fallback.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.fullName,
    this.avatarPath,
    this.radius = 18,
    this.onTap,
  });

  final String? fullName;
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
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(
              initialsFor(fullName),
              style: TextStyle(
                fontSize: radius * 0.85,
                fontWeight: FontWeight.w600,
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
