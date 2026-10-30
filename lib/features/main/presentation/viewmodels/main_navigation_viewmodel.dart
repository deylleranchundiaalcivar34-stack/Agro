import 'package:flutter/material.dart';

/// ViewModel para la navegación principal de Agro+.
/// Controla el índice activo, eventos de cambio de pestaña y badges informativos.
class MainNavigationViewModel extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  /// Cambia el índice de la pestaña activa y notifica a los oyentes.
  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }
}
