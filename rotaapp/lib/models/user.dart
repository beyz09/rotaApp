class AppUser {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime? createdAt;
  // Diğer kullanıcı bilgileri eklenebilir

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.createdAt,
  });
}
