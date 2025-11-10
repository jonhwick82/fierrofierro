
/// Modelo para almacenar los datos del usuario de la app, incluyendo su rol.
class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });
}

/// Servicio para gestionar la autenticación y el rol del usuario.
/// Usamos un singleton para tener una única instancia en toda la app.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  // Métodos para verificar roles
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isEmployee => _currentUser?.role == 'empleado';
  bool get isUser => _currentUser?.role == 'usuario';

  void setUser(AppUser user) {
    _currentUser = user;
  }
}