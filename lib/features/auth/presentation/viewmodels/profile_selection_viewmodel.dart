import 'package:flutter/foundation.dart';

import 'auth_viewmodel.dart';

class ProfileSelectionViewModel extends ChangeNotifier {
  final AuthViewModel authViewModel;

  ProfileSelectionViewModel({required this.authViewModel})
    : _selectedRole = authViewModel.selectedRole == UserRole.admin
          ? null
          : authViewModel.selectedRole;

  UserRole? _selectedRole;
  bool _isLoading = false;
  String? _errorMessage;

  UserRole? get selectedRole => _selectedRole;
  bool get hasSelection => _selectedRole != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void selectRole(UserRole role) {
    if (_selectedRole == role) return;
    _selectedRole = role;
    _errorMessage = null;
    notifyListeners();
  }

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
      _errorMessage =
          'Ocurrio un error al guardar tu perfil. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
