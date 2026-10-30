import 'package:flutter/foundation.dart';

import 'auth_viewmodel.dart';

/// ViewModel para la pantalla de Selección de Perfil / Rol en Agro+.
///
/// Responsabilidades bajo MVVM:
/// - Controlar la opción seleccionada por el usuario (Productor/Vendedor o Comprador).
/// - Exponer el estado reactivo (`hasSelection`, `isLoading`, `errorMessage`) a la vista.
/// - Persistir el rol permitido en PostgreSQL mediante el AuthViewModel.
class ProfileSelectionViewModel extends ChangeNotifier {
  final AuthViewModel authViewModel;

  ProfileSelectionViewModel({
    required this.authViewModel,
  }) : _selectedRole = authViewModel.selectedRole == UserRole.admin
            ? null
            : authViewModel.selectedRole;

  // ---------------------------------------------------------------------------
  // Estado interno reactivo
  // ---------------------------------------------------------------------------
  UserRole? _selectedRole;
  bool _isLoading = false;
  String? _errorMessage;

  // ---------------------------------------------------------------------------
  // Getters públicos para la vista
  // ---------------------------------------------------------------------------
  UserRole? get selectedRole => _selectedRole;
  bool get hasSelection => _selectedRole != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Acciones y Lógica de Negocio
  // ---------------------------------------------------------------------------

  /// Selecciona o alterna el rol deseado en la interfaz.
  void selectRole(UserRole role) {
    if (_selectedRole == role) return;
    _selectedRole = role;
    _errorMessage = null;
    notifyListeners();
  }

  /// Guarda un rol permitido en PostgreSQL. La tabla de perfiles y RLS son la
  /// fuente de autorización; no se usan metadatos editables de Supabase Auth.
  Future<bool> confirmRoleSelection() async {
    if (_selectedRole == null) {
      _errorMessage = 'Por favor selecciona un tipo de perfil para continuar.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final role = _selectedRole!;

      final updated = await authViewModel.updateUserRole(role);
      _isLoading = false;
      _errorMessage = updated ? null : authViewModel.errorMessage;
      notifyListeners();
      return updated;
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Ocurrió un error al guardar tu perfil. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
  }

  /// Limpia errores previos al cambiar de pantalla.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
