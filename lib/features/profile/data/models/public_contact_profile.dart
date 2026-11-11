class PublicContactProfile {
  const PublicContactProfile({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.whatsappPhone,
    this.whatsappVisible = false,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? whatsappPhone;
  final bool whatsappVisible;

  String get initial {
    final name = displayName.trim();
    return name.isEmpty
        ? 'A'
        : String.fromCharCode(name.runes.first).toUpperCase();
  }

  factory PublicContactProfile.fromMap(Map<String, dynamic> row) {
    final visible = row['whatsapp_visible'] as bool? ?? false;
    return PublicContactProfile(
      userId: row['id_usuario'] as String,
      displayName: (row['nombre_publico'] as String? ?? '').trim(),
      avatarUrl: row['avatar_url'] as String?,
      whatsappPhone: visible ? row['telefono_whatsapp'] as String? : null,
      whatsappVisible: visible,
    );
  }
}
