import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio centralizado de acceso a Supabase.
///
/// En lugar de usar una variable global (`final supabase = ...`),
/// encapsulamos el cliente en una clase. Esto permite:
/// - Inyección de dependencias limpia en ViewModels y Repositories.
/// - Facilitar mocking en tests unitarios.
/// - Centralizar cualquier lógica adicional de configuración.
class SupabaseService {
  /// Acceso al cliente de Supabase (Auth, DB, Storage, Realtime).
  SupabaseClient get client => Supabase.instance.client;

  /// Usuario autenticado actualmente. Null si no hay sesión.
  User? get currentUser => client.auth.currentUser;

  /// Stream de cambios en el estado de autenticación.
  /// Útil para que el router reaccione a login/logout automáticamente.
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Indica si hay una sesión activa.
  bool get isAuthenticated => currentUser != null;
}

