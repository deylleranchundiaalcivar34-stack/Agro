import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/network/supabase_service.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';

Future<void> main() async {
  // Garantiza que los bindings de Flutter están listos antes de cualquier
  // operación asíncrona (plugins, canales nativos, etc.)
  WidgetsFlutterBinding.ensureInitialized();

  // Carga las variables de entorno desde el archivo .env
  // El archivo .env está declarado en pubspec.yaml como asset.
  await dotenv.load(fileName: '.env');

  // Inicializa Supabase usando las variables de entorno (nunca hardcoded)
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    // ignore: deprecated_member_use
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    // MultiProvider en la raíz para que los ViewModels estén disponibles
    // en todo el árbol de widgets
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(
            supabaseService: SupabaseService(),
          ),
        ),
      ],
      child: const AgroApp(),
    ),
  );
}
