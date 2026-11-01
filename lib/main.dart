import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/network/supabase_service.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/data/repositories/profile_repository.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'features/products/data/repositories/products_repository.dart';
import 'features/products/presentation/viewmodels/products_viewmodel.dart';
import 'features/splash/splash_view.dart';

Future<void> main() async {
  // Garantiza que los bindings de Flutter están listos antes de cualquier
  // operación asíncrona (plugins, canales nativos, etc.)
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Dibuja el primer frame mientras se inicializan los servicios.
  runApp(const _AgroBootstrap());
}

class _AgroBootstrap extends StatefulWidget {
  const _AgroBootstrap();

  @override
  State<_AgroBootstrap> createState() => _AgroBootstrapState();
}

class _AgroBootstrapState extends State<_AgroBootstrap> {
  AuthViewModel? _authViewModel;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final startupWatch = Stopwatch()..start();
    try {
      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        // ignore: deprecated_member_use
        anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );
      final service = SupabaseService();
      final auth = AuthViewModel(
        supabaseService: service,
        profileRepository: ProfileRepository(supabaseService: service),
      );
      await auth.initialLoad;
      const minimumBrandTime = Duration(milliseconds: 3200);
      if (startupWatch.elapsed < minimumBrandTime) {
        await Future<void>.delayed(minimumBrandTime - startupWatch.elapsed);
      }
      if (kProfileMode) {
        debugPrint(
          'Agro+ servicios y perfil: ${startupWatch.elapsedMilliseconds} ms',
        );
      }
      if (!mounted) {
        auth.dispose();
        return;
      }
      setState(() => _authViewModel = auth);
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    }
  }

  @override
  void dispose() {
    _authViewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.primary,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudo iniciar Agro+.',
                  style: TextStyle(color: AppColors.surface),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _startupError = null);
                    _initialize();
                  },
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(color: AppColors.surface),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final auth = _authViewModel;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: auth == null
          ? const MaterialApp(
              key: ValueKey('brand'),
              home: SplashView(autoNavigate: false),
            )
          : MultiProvider(
              key: const ValueKey('app'),
              providers: [
                ChangeNotifierProvider<AuthViewModel>.value(value: auth),
                ChangeNotifierProvider(
                  create: (_) => ProductsViewModel(
                    productsRepository: ProductsRepository(
                      supabaseService: SupabaseService(),
                    ),
                  ),
                ),
              ],
              child: const AgroApp(),
            ),
    );
  }
}
