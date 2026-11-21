import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../products/data/services/product_storage_service.dart';
import '../../data/models/ecuador_mobile_phone.dart';
import '../../data/models/public_contact_profile.dart';
import '../../data/repositories/private_contact_profile_repository.dart';
import '../../data/repositories/public_contact_profile_repository.dart';
import '../widgets/profile_subpage.dart';
import '../widgets/public_profile_avatar.dart';

class ProfileDataView extends StatefulWidget {
  const ProfileDataView({super.key});

  @override
  State<ProfileDataView> createState() => _ProfileDataViewState();
}

class _ProfileDataViewState extends State<ProfileDataView> {
  late final _supabase = SupabaseService();
  late final _publicContactRepository = PublicContactProfileRepository(
    supabaseService: _supabase,
  );
  late final _privateContactRepository = PrivateContactProfileRepository(
    supabaseService: _supabase,
  );
  late final _productStorage = ProductStorageService();
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _companyName = TextEditingController();
  final _mobileNumber = TextEditingController();

  bool _initialized = false;
  bool _loadingContact = true;
  bool _contactLoadFailed = false;
  bool _saving = false;
  bool _uploading = false;
  bool _sharePhone = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadContactData();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _companyName.dispose();
    _mobileNumber.dispose();
    super.dispose();
  }

  Future<void> _loadContactData() async {
    setState(() {
      _loadingContact = true;
      _contactLoadFailed = false;
    });
    try {
      final results = await Future.wait<Object?>([
        _publicContactRepository.getMine(),
        _privateContactRepository.getMine(),
      ]);
      final publicProfile = results[0] as PublicContactProfile?;
      final privatePhone = results[1] as String?;
      if (!mounted) return;
      setState(() {
        _avatarUrl =
            publicProfile?.avatarUrl ??
            context.read<AuthViewModel>().profile?.avatarUrl;
        _sharePhone = publicProfile?.whatsappVisible ?? false;
        _mobileNumber.text = EcuadorMobilePhone.toLocal(
          privatePhone ?? publicProfile?.whatsappPhone,
        );
        _loadingContact = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _contactLoadFailed = true;
        _loadingContact = false;
      });
      if (const {'42P01', 'PGRST204', 'PGRST205'}.contains(error.code)) {
        _showMessage(
          'Falta aplicar la migración de perfil privado en Supabase.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _contactLoadFailed = true;
        _loadingContact = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await _productStorage.seleccionarAvatar();
      if (file == null || !mounted) return;
      setState(() => _uploading = true);
      final url = await _productStorage.subirAvatar(file);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      _showMessage('Foto lista. Guarda el perfil para aplicarla en Agro+.');
    } on ProductUploadException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('No se pudo subir la foto. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_contactLoadFailed || _loadingContact || _uploading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final phone = EcuadorMobilePhone.toInternational(_mobileNumber.text);
    final auth = context.read<AuthViewModel>();
    final profile = auth.profile;
    final isProducer = profile?.role == UserRole.producer.value;
    final companyName = isProducer
        ? _companyName.text
        : profile?.companyName ?? '';
    final accountSaved = await auth.updateProfileData(
      firstName: _firstName.text,
      lastName: _lastName.text,
      companyName: companyName,
    );
    if (!mounted) return;
    if (!accountSaved) {
      _showMessage('No se pudieron guardar tus datos de cuenta.');
      setState(() => _saving = false);
      return;
    }

    try {
      await _privateContactRepository.saveMine(phone: phone);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Tus datos de cuenta se guardaron, pero no se pudo guardar el celular. Intenta de nuevo.',
      );
      setState(() => _saving = false);
      return;
    }

    final displayName = '${_firstName.text.trim()} ${_lastName.text.trim()}'
        .trim();
    try {
      await _publicContactRepository.saveMine(
        displayName: displayName,
        avatarUrl: _avatarUrl,
        whatsappVisible: _sharePhone,
        whatsappPhone: _sharePhone ? phone ?? '' : '',
      );
      auth.updateAvatarUrl(_avatarUrl);
      if (!mounted) return;
      _showMessage('Tu perfil se actualizó en toda la aplicación.');
    } on ArgumentError catch (error) {
      if (mounted) _showMessage(error.message.toString());
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Tus datos y celular se guardaron, pero no se pudo actualizar el perfil del chat. Intenta guardar de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final profile = auth.profile;
    if (!_initialized && profile != null) {
      _firstName.text = profile.firstName;
      _lastName.text = profile.lastName;
      _companyName.text = profile.companyName;
      _avatarUrl ??= profile.avatarUrl;
      _initialized = true;
    }
    final isProducer = profile?.role == UserRole.producer.value;
    final email = profile?.email ?? auth.currentUser?.email ?? '';

    return ProfileSubpage(
      title: 'Mis datos',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  PublicProfileAvatar(
                    radius: 44,
                    initial: auth.userInitial,
                    imageUrl: _avatarUrl ?? profile?.avatarUrl,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu perfil en Agro+',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'La misma foto aparecerá en tu cuenta y en tus conversaciones.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _uploading || _saving || _loadingContact
                        ? null
                        : _pickAvatar,
                    icon: _uploading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                    label: Text(_uploading ? 'Subiendo foto' : 'Cambiar foto'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AbsorbPointer(
            absorbing: _saving || _loadingContact,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Datos personales',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _firstName,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nombres',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Escribe tus nombres.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _lastName,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Apellidos',
                            ),
                            validator: (value) {
                              final lastName = value?.trim() ?? '';
                              if (lastName.isEmpty) {
                                return 'Escribe tus apellidos.';
                              }
                              final fullName =
                                  '${_firstName.text.trim()} $lastName'.trim();
                              if (fullName.length > 80) {
                                return 'Nombres y apellidos deben sumar hasta 80 caracteres.';
                              }
                              return null;
                            },
                          ),
                          if (isProducer) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _companyName,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText:
                                    'Nombre de finca o negocio (opcional)',
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            key: ValueKey(email),
                            initialValue: email,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              helperText: 'Es el correo de acceso a tu cuenta.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Celular y contacto',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Opcional. Puedes guardarlo sin compartirlo.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _mobileNumber,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 9,
                            decoration: const InputDecoration(
                              labelText: 'Celular (opcional)',
                              prefixText: '+593 ',
                              hintText: '912345685',
                              helperText:
                                  'Escribe 9 dígitos, sin el 0 inicial.',
                              counterText: '',
                            ),
                            validator: (value) {
                              final digits = value?.trim() ?? '';
                              if (digits.isEmpty && !_sharePhone) return null;
                              if (digits.isEmpty && _sharePhone) {
                                return 'Agrega un celular para poder compartirlo.';
                              }
                              if (!EcuadorMobilePhone.localPattern.hasMatch(
                                digits,
                              )) {
                                return 'Usa 9 dígitos que empiecen en 9, sin el 0 inicial.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _sharePhone,
                            onChanged: _saving
                                ? null
                                : (value) =>
                                      setState(() => _sharePhone = value),
                            title: const Text(
                              'Permitir que vean mi número para WhatsApp',
                            ),
                            subtitle: const Text(
                              'Tu celular solo aparecerá a otras personas registradas en Agro+ si activas esta opción.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loadingContact) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                  if (_contactLoadFailed) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'No se pudieron cargar tus datos de contacto. Revisa tu conexión y vuelve a intentar.',
                              ),
                            ),
                            IconButton(
                              tooltip: 'Reintentar carga',
                              onPressed: _loadContactData,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed:
                        _saving ||
                            _uploading ||
                            _loadingContact ||
                            _contactLoadFailed
                        ? null
                        : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _saving ? 'Guardando perfil' : 'Guardar perfil',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
