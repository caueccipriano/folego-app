class ProfileIdentity {
  const ProfileIdentity({
    required this.email,
    this.fullName,
  });

  final String? fullName;
  final String email;

  String get displayName {
    final normalizedName = fullName?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }

    final normalizedEmail = email.trim();
    if (normalizedEmail.isNotEmpty) {
      final localPart = normalizedEmail.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return localPart;
      }
      return normalizedEmail;
    }

    return 'Você';
  }

  String get initials {
    final words = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.isEmpty) {
      return '?';
    }

    if (words.length == 1) {
      final value = words.first;
      if (value.length == 1) {
        return value.toUpperCase();
      }
      return value.substring(0, 2).toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}
