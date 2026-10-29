/// Strings centralizados de la aplicación.
/// Facilita la futura internacionalización (l10n / ARB).
abstract class AppStrings {
  // --- App ---
  static const String appName = 'Agro+';
  static const String appTagline = 'Del campo a tu mesa';

  // --- Auth ---
  static const String login = 'Iniciar sesión';
  static const String register = 'Crear cuenta';
  static const String logout = 'Cerrar sesión';
  static const String email = 'Correo electrónico';
  static const String password = 'Contraseña';
  static const String confirmPassword = 'Confirmar contraseña';
  static const String fullName = 'Nombre completo';
  static const String selectRole = 'Selecciona tu rol';
  static const String roleProducer = 'Productor';
  static const String roleBuyer = 'Comprador';
  static const String roleAdmin = 'Administrador';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';
  static const String noAccount = '¿No tienes cuenta? ';
  static const String alreadyAccount = '¿Ya tienes cuenta? ';

  // --- Validaciones ---
  static const String fieldRequired = 'Este campo es requerido';
  static const String emailInvalid = 'Ingresa un correo válido';
  static const String passwordMin = 'Mínimo 6 caracteres';
  static const String passwordsNoMatch = 'Las contraseñas no coinciden';

  // --- Errores genéricos ---
  static const String genericError = 'Ocurrió un error. Intenta de nuevo.';
  static const String connectionError = 'Sin conexión. Verifica tu red.';

  // --- Productos ---
  static const String products = 'Productos';
  static const String myProducts = 'Mis productos';
  static const String addProduct = 'Agregar producto';
  static const String productName = 'Nombre del producto';
  static const String productDescription = 'Descripción';
  static const String productPrice = 'Precio por unidad';
  static const String productCategory = 'Categoría';
  static const String productQuantity = 'Cantidad disponible';

  // --- Navegación ---
  static const String home = 'Inicio';
  static const String map = 'Mapa';
  static const String chat = 'Chat';
  static const String profile = 'Perfil';
}

