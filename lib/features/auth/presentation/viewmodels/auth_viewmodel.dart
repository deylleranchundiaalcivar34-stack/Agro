import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';

/// Roles disponibles en Agro+
enum UserRole { producer, buyer, admin }

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.producer:
        return 'Productor';
      case UserRole.buyer:
        return 'Comprador';
      case UserRole.admin:
        return 'Administrador';
    }
  }

  String get value {
    switch (this) {
      case UserRole.producer:
        return 'producer';
      case UserRole.buyer:
        return 'buyer';
      case UserRole.admin:
        return 'admin';
    }
  }
}

/// Estados posibles del proceso de autenticación
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// ViewModel de autenticación (MVVM con ChangeNotifier).
///
/// Responsabilidades:
/// - Manejar sign in, sign up y sign out.
/// - Exponer el estado de carga y errores a la UI.
/// - Mantener el rol del usuario actual.
class AuthViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  AuthViewModel({required this._supabaseService}) {
    // Escucha cambios de sesión para actualizar el estado automáticamente.
    _supabaseService.authStateChanges.listen(_onAuthStateChanged);
    // Determina el estado inicial
    _status = _supabaseService.isAuthenticated
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
  }

  // ---------------------------------------------------------------------------
  // Estado interno
  // ---------------------------------------------------------------------------
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  UserRole _selectedRole = UserRole.buyer;
  User? _currentUser;

  // ---------------------------------------------------------------------------
  // Getters públicos (la UI solo lee, nunca escribe directamente)
  // ---------------------------------------------------------------------------
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  UserRole get selectedRole => _selectedRole;
  User? get currentUser => _currentUser ?? _supabaseService.currentUser;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ---------------------------------------------------------------------------
  // Métodos públicos
  // ---------------------------------------------------------------------------

  /// Actualiza el rol seleccionado en el formulario de registro.
  void setRole(UserRole role) {
    _selectedRole = role;
    notifyListeners();
  }

  /// Inicia sesión con email y contraseña.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      final response = await _supabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _currentUser = response.user;
      _setAuthenticated();
      return true;
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return false;
    } catch (_) {
      _setError('Error de conexión. Verifica tu red.');
      return false;
    }
  }

  /// Registra un nuevo usuario con email, contraseña y rol.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    _setLoading();
    try {
      final response = await _supabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': role.value,
        },
      );
      _currentUser = response.user;
      // Supabase puede requerir confirmación de email
      if (response.user != null && response.session != null) {
        _setAuthenticated();
      } else {
        // Email de confirmación enviado
        _setStatus(AuthStatus.unauthenticated);
        _errorMessage = null;
      }
      return true;
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return false;
    } catch (_) {
      _setError('Error de conexión. Verifica tu red.');
      return false;
    }
  }

  /// Cierra la sesión del usuario actual.
  Future<void> signOut() async {
    await _supabaseService.client.auth.signOut();
    _currentUser = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  /// Limpia el mensaje de error (útil al navegar entre pantallas).
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Listener del stream de Auth
  // ---------------------------------------------------------------------------
  void _onAuthStateChanged(AuthState state) {
    if (state.event == AuthChangeEvent.signedIn) {
      _currentUser = state.session?.user;
      _setAuthenticated();
    } else if (state.event == AuthChangeEvent.signedOut) {
      _currentUser = null;
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers privados de estado
  // ---------------------------------------------------------------------------
  void _setLoading() {
    _errorMessage = null;
    _setStatus(AuthStatus.loading);
  }

  void _setAuthenticated() => _setStatus(AuthStatus.authenticated);

  void _setError(String message) {
    _errorMessage = message;
    _setStatus(AuthStatus.error);
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Traduce mensajes de error de Supabase Auth a español.
  String _mapAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    } else if (m.contains('email already registered') ||
        m.contains('user already registered')) {
      return 'Este correo ya está registrado.';
    } else if (m.contains('email not confirmed')) {
      return 'Confirma tu correo antes de iniciar sesión.';
    } else if (m.contains('password should be')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    } else if (m.contains('rate limit')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    return 'Error de autenticación. Intenta de nuevo.';
  }
}
