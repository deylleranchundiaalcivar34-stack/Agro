import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_service.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/profile_repository.dart';

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

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final ProfileRepository _profileRepository;
  late final StreamSubscription<AuthState> _authSubscription;
  late final Future<void> initialLoad;

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
      initialLoad = Future<void>.value();
    } else {
      initialLoad = _hydrateAuthenticatedUser(currentUser);
    }
  }

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  UserRole _selectedRole = UserRole.buyer;
  User? _currentUser;
  UserProfile? _profile;
  bool _mfaRequired = false;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  UserRole get selectedRole => _selectedRole;
  User? get currentUser => _currentUser ?? _supabaseService.currentUser;
  UserProfile? get profile => _profile;
  String get displayName => _profile?.fullName ?? 'Usuario Agro+';
  String get userInitial => _profile?.initial ?? 'A';
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get mfaRequired => _mfaRequired;

  void setRole(UserRole role) {
    _selectedRole = role;
    notifyListeners();
  }

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

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading();
    try {
      final response = await _supabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        _setError('No se pudo iniciar la sesion. Intenta nuevamente.');
        return false;
      }
      _currentUser = user;
      await _hydrateAuthenticatedUser(user);
      return isAuthenticated;
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return false;
    } catch (_) {
      _setError('Error de conexion. Verifica tu red.');
      return false;
    }
  }

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
        emailRedirectTo: kIsWeb ? null : 'io.supabase.agro://auth/callback',
        data: {
          'full_name': fullName.trim(),
          'role': role.value,
          'company_name': companyName?.trim(),
          'administrator_reason': administratorReason?.trim(),
        },
      );
      _currentUser = response.user;
      if (response.user != null && response.session != null) {
        await _hydrateAuthenticatedUser(response.user!);
      } else {
        _setStatus(AuthStatus.unauthenticated);
        _errorMessage = null;
      }
      return true;
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return false;
    } catch (_) {
      _setError('Error de conexion. Verifica tu red.');
      return false;
    }
  }

  Future<AuthMFAEnrollResponse?> enrollTotp() async {
    try {
      return await _supabaseService.client.auth.mfa.enroll(
        issuer: 'Agro+',
        friendlyName: 'Google Authenticator',
      );
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return null;
    }
  }

  Future<bool> verifyTotp(String factorId, String code) async {
    try {
      await _supabaseService.client.auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: code,
      );
      _mfaRequired = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return false;
    }
  }

  Future<bool> verifyCurrentTotp(String code) async {
    final factors = await _supabaseService.client.auth.mfa.listFactors();
    if (factors.totp.isEmpty) return false;
    return verifyTotp(factors.totp.first.id, code);
  }

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
      _setError('No se pudo cerrar la sesion. Intenta nuevamente.');
    }
  }

  Future<bool> resetPasswordForEmail({required String email}) async {
    _setLoading();
    try {
      await _supabaseService.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'https://agroplus-recuperar.vercel.app',
      );
      _setStatus(AuthStatus.unauthenticated);
      _errorMessage = null;
      return true;
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return false;
    } catch (_) {
      _setError(
        'Error al enviar el correo de recuperacion. Intenta nuevamente.',
      );
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _setLoading();
    try {
      final response = await _supabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (response.user != null) {
        _errorMessage = null;
        _setStatus(AuthStatus.unauthenticated);
        return true;
      }
      _setError('No se pudo actualizar la contrasena.');
      return false;
    } on AuthException catch (e) {
      _setError(_mapAuthError(e.message));
      return false;
    } catch (_) {
      _setError('Error al actualizar la contrasena.');
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

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
        _setError('No se encontro el perfil de esta cuenta.');
        return;
      }

      _profile = profile;
      _selectedRole = UserRoleExtension.fromValue(profile.role);
      final aal = _supabaseService.client.auth.mfa
          .getAuthenticatorAssuranceLevel();
      _mfaRequired =
          aal.currentLevel != AuthenticatorAssuranceLevels.aal2 &&
          aal.nextLevel == AuthenticatorAssuranceLevels.aal2;
      _setAuthenticated();
    } catch (_) {
      _setError('No se pudo cargar tu perfil. Verifica tu conexion.');
    }
  }

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

  String _mapAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Correo o contrasena incorrectos.';
    } else if (m.contains('email already registered') ||
        m.contains('user already registered')) {
      return 'Este correo ya esta registrado.';
    } else if (m.contains('email not confirmed')) {
      return 'Confirma tu correo antes de iniciar sesion.';
    } else if (m.contains('password should be')) {
      return 'La contrasena debe tener al menos 6 caracteres.';
    } else if (m.contains('rate limit')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    return 'Error de autenticacion. Intenta de nuevo.';
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
