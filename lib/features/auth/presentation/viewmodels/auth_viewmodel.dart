import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/profile_repository.dart';

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

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.buyer,
    );
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
  final ProfileRepository _profileRepository;
  late final StreamSubscription<AuthState> _authSubscription;

  AuthViewModel({
    required SupabaseService supabaseService,
    required ProfileRepository profileRepository,
  }) : this._(supabaseService, profileRepository);

  AuthViewModel._(this._supabaseService, this._profileRepository) {
    _authSubscription = _supabaseService.authStateChanges.listen(
      _onAuthStateChanged,
    );

    final currentUser = _supabaseService.currentUser;
    if (currentUser == null) {
      _status = AuthStatus.unauthenticated;
    } else {
      _hydrateAuthenticatedUser(currentUser);
    }
  }

  // ---------------------------------------------------------------------------
  // Estado interno
  // ---------------------------------------------------------------------------
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  UserRole _selectedRole = UserRole.buyer;
  User? _currentUser;
  UserProfile? _profile;

  // ---------------------------------------------------------------------------
  // Getters públicos (la UI solo lee, nunca escribe directamente)
  // ---------------------------------------------------------------------------
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  UserRole get selectedRole => _selectedRole;
  User? get currentUser => _currentUser ?? _supabaseService.currentUser;
  UserProfile? get profile => _profile;
  String get displayName => _profile?.fullName ?? 'Usuario Agro+';
  String get userInitial => _profile?.initial ?? 'A';
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

  /// Actualiza el rol del usuario autenticado en Supabase Auth y en el estado local.
  Future<bool> updateUserRole(UserRole role) async {
    if (role == UserRole.admin) {
      _setError('El rol administrador solo puede ser asignado internamente.');
      return false;
    }

    _setLoading();
    try {
      _profile = await _profileRepository.updateCurrentRole(role.value);
      _selectedRole = role;
      _setAuthenticated();
      return true;
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return false;
    } catch (_) {
      _setError('Error al actualizar el tipo de cuenta.');
      return false;
    }
  }

  /// Inicia sesión con email y contraseña.
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading();
    try {
      final response = await _supabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        _setError('No se pudo iniciar la sesión. Intenta nuevamente.');
        return false;
      }
      _currentUser = user;
      await _hydrateAuthenticatedUser(user);
      return isAuthenticated;
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
    String? companyName,
    String? administratorReason,
  }) async {
    _setLoading();
    try {
      final response = await _supabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': role.value,
          'company_name': companyName?.trim(),
          'administrator_reason': administratorReason?.trim(),
        },
      );
      _currentUser = response.user;
      // Supabase puede requerir confirmación de email
      if (response.user != null && response.session != null) {
        await _hydrateAuthenticatedUser(response.user!);
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
    try {
      await _supabaseService.client.auth.signOut();
      _currentUser = null;
      _profile = null;
      _selectedRole = UserRole.buyer;
      _setStatus(AuthStatus.unauthenticated);
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
    } catch (_) {
      _setError('No se pudo cerrar la sesión. Intenta nuevamente.');
    }
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
    if (state.event == AuthChangeEvent.signedOut || state.session == null) {
      _currentUser = null;
      _profile = null;
      _selectedRole = UserRole.buyer;
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    _hydrateAuthenticatedUser(state.session!.user);
  }

  Future<void> _hydrateAuthenticatedUser(User user) async {
    _currentUser = user;
    _setStatus(AuthStatus.loading);

    try {
      final profile = await _profileRepository.getCurrentProfile();
      if (profile == null) {
        _setError('No se encontró el perfil de esta cuenta.');
        return;
      }

      _profile = profile;
      _selectedRole = UserRoleExtension.fromValue(profile.role);
      _setAuthenticated();
    } catch (_) {
      _setError('No se pudo cargar tu perfil. Verifica tu conexión.');
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

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
