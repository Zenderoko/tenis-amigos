/// Usuario autenticado en la aplicación.
///
/// La identidad interna es [id], que corresponde al id de Supabase Auth. El
/// correo y el nombre son solo datos de presentación.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  factory AuthUser.fromSupabaseUser({
    required String id,
    required String? email,
    String? displayName,
    String? photoUrl,
  }) {
    return AuthUser(
      id: id,
      email: email ?? '',
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  String get displayNameOrEmail {
    final String? name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final int at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }
}
