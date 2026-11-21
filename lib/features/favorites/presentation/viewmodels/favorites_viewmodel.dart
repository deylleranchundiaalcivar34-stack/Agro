import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/favorite_product.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../../products/data/models/agricultural_product.dart';

/// Estado compartido de favoritos para la cuenta activa.
class FavoritesViewModel extends ChangeNotifier {
  FavoritesViewModel({required FavoritesRepository repository})
    : _repository = repository {
    _userId = repository.currentUserId;
    _authSubscription = repositoryAuthChanges.listen(_onAuthChanged);
    unawaited(refresh());
  }

  final FavoritesRepository _repository;
  late final StreamSubscription _authSubscription;
  String? _userId;
  List<FavoriteProduct> _favorites = const [];
  final Set<String> _pendingIds = {};
  bool _isLoading = true;
  Object? _error;

  // Se recupera el stream mediante el repositorio para mantener una sola fuente de sesion.
  Stream<dynamic> get repositoryAuthChanges => _repository.authStateChanges;

  List<FavoriteProduct> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  Object? get error => _error;
  int get count => _favorites.length;

  bool isFavorite(String productId) =>
      _favorites.any((item) => item.productId == productId);

  bool isPending(String productId) => _pendingIds.contains(productId);

  Future<void> refresh() async {
    final userId = _repository.currentUserId;
    if (userId == null) {
      _favorites = const [];
      _isLoading = false;
      _error = null;
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.getFavorites();
      if (_repository.currentUserId != userId) return;
      _favorites = result;
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _error = error;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(AgriculturalProduct product) async {
    final id = product.id;
    if (_pendingIds.contains(id)) return;
    final wasFavorite = isFavorite(id);
    final previous = _favorites;
    _pendingIds.add(id);
    _error = null;
    _favorites = wasFavorite
        ? _favorites.where((item) => item.productId != id).toList()
        : [
            FavoriteProduct(
              productId: id,
              product: product,
              createdAt: DateTime.now(),
            ),
            ..._favorites,
          ];
    notifyListeners();
    try {
      if (wasFavorite) {
        await _repository.remove(id);
      } else {
        await _repository.add(id);
      }
    } catch (error) {
      _favorites = previous;
      _error = error;
      rethrow;
    } finally {
      _pendingIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> removeUnavailable(String productId) async {
    if (_pendingIds.contains(productId)) return;
    final previous = _favorites;
    _pendingIds.add(productId);
    _favorites = _favorites
        .where((item) => item.productId != productId)
        .toList();
    notifyListeners();
    try {
      await _repository.remove(productId);
    } catch (error) {
      _favorites = previous;
      _error = error;
      rethrow;
    } finally {
      _pendingIds.remove(productId);
      notifyListeners();
    }
  }

  void _onAuthChanged(dynamic _) {
    final nextUserId = _repository.currentUserId;
    if (nextUserId == _userId) return;
    _userId = nextUserId;
    _favorites = const [];
    _pendingIds.clear();
    unawaited(refresh());
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
