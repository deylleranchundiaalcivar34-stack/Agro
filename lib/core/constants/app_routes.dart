/// Rutas nombradas de la aplicación.
/// Centralizar los paths evita errores de typo y facilita refactors.
abstract class AppRoutes {
  // Splash
  static const String splash = '/splash';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';

  // Principal
  static const String home = '/home';

  // Productos
  static const String products = '/products';
  static const String productDetail = '/products/:id';
  static const String productCreate = '/products/create';

  // Mapa
  static const String map = '/map';

  // Chat
  static const String chatList = '/chat';
  static const String chatRoom = '/chat/:roomId';

  // Perfil
  static const String profile = '/profile';
}

