import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:proyecto_agro/core/network/supabase_service.dart';
import 'package:proyecto_agro/features/auth/data/repositories/profile_repository.dart';
import 'package:proyecto_agro/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:proyecto_agro/features/profile/presentation/widgets/profile_avatar_action.dart';

class _TestSupabaseService extends SupabaseService {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;
}

void main() {
  late AuthViewModel authViewModel;

  setUp(() {
    final supabase = _TestSupabaseService();
    authViewModel = AuthViewModel(
      supabaseService: supabase,
      profileRepository: ProfileRepository(supabaseService: supabase),
    );
  });

  tearDown(() => authViewModel.dispose());

  testWidgets('profile action displays a single white circular avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authViewModel,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [const ProfileAvatarAction()]),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final action = tester.widget<IconButton>(find.byType(IconButton));
    expect(find.byTooltip('Abrir menú de cuenta'), findsOneWidget);
    expect(
      action.style?.backgroundColor?.resolve(const <WidgetState>{}),
      Colors.transparent,
    );
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(tester.widget<CircleAvatar>(find.byType(CircleAvatar)).radius, 20);
    expect(tester.takeException(), isNull);
  });
}
