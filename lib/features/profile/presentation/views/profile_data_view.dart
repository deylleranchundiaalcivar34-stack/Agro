import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../products/data/services/product_storage_service.dart';
import '../../data/repositories/public_contact_profile_repository.dart';
import '../widgets/profile_subpage.dart';
import '../widgets/public_chat_profile_section.dart';

class ProfileDataView extends StatefulWidget {
  const ProfileDataView({super.key});

  @override
  State<ProfileDataView> createState() => _ProfileDataViewState();
}

class _ProfileDataViewState extends State<ProfileDataView> {
  late final _publicContactRepository = PublicContactProfileRepository(
    supabaseService: SupabaseService(),
  );
  late final _productStorage = ProductStorageService();
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _companyName = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _companyName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final profile = auth.profile;
    if (!_initialized && profile != null) {
      _firstName.text = profile.firstName;
      _lastName.text = profile.lastName;
      _companyName.text = profile.companyName;
      _initialized = true;
    }

    return ProfileSubpage(
      title: 'Mis datos',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            'Informacion de tu cuenta',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombres'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe tus nombres.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Apellidos'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe tus apellidos.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _companyName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de empresa (opcional)',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: profile?.email ?? auth.currentUser?.email ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Correo electronico',
                    helperText:
                        'El correo se mantiene protegido en esta etapa.',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Guardando' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PublicChatProfileSection(
            repository: _publicContactRepository,
            storage: _productStorage,
            suggestedName: profile == null
                ? ''
                : '${profile.firstName} ${profile.lastName}'.trim(),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await context.read<AuthViewModel>().updateProfileData(
      firstName: _firstName.text,
      lastName: _lastName.text,
      companyName: _companyName.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Tus datos se guardaron.' : 'No se pudieron guardar tus datos.',
        ),
      ),
    );
  }
}
