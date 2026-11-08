abstract class AppRoutes {
  static const String splash = '/splash';
  static const String welcome = '/welcome';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profileSelection = '/auth/profile-selection';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String mfaSetup = '/auth/mfa-setup';
  static const String mfaChallenge = '/auth/mfa-challenge';
  static const String emailConfirmed = '/auth/email-confirmed';

  static const String home = '/home';

  static const String products = '/products';
  static const String productDetail = '/products/:id';
  static const String productCreate = '/products/create';

  static const String map = '/map';

  static const String chatList = '/chat';
  static const String chatRoom = '/chat/:roomId';
  static const String publicProducerProfile = '/producer/:producerId';

  static const String profile = '/profile';
  static const String publicLocation = '/profile/public-location';
  static const String profileOrders = '/profile/orders';
  static const String profileData = '/profile/data';
  static const String profileNotifications = '/profile/notifications';
  static const String profileSecurity = '/profile/security';
  static const String profileSupport = '/profile/support';
}
