import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../products/data/services/product_storage_service.dart';
import '../../data/models/public_contact_profile.dart';
import '../../data/repositories/public_contact_profile_repository.dart';
import 'public_profile_avatar.dart';

class PublicChatProfileSection extends StatefulWidget {
  const PublicChatProfileSection({
    super.key,
    required this.repository,
    required this.storage,
    required this.suggestedName,
  });

  final PublicContactProfileRepository repository;
  final ProductStorageService storage;
  final String suggestedName;

  @override
  State<PublicChatProfileSection> createState() =>
      _PublicChatProfileSectionState();
}

class _PublicChatProfileSectionState extends State<PublicChatProfileSection> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  PublicContactProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _whatsappVisible = false;
  bool _schemaUnavailable = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _name.text = widget.suggestedName.trim();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.repository.getMine();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        if (profile != null) {
          _name.text = profile.displayName;
          _avatarUrl = profile.avatarUrl;
          _whatsappVisible = profile.whatsappVisible;
          _phone.text = profile.whatsappPhone ?? '';
        }
        _loading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _schemaUnavailable = const {
          '42P01',
          'PGRST204',
          'PGRST205',
        }.contains(error.code);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await widget.storage.seleccionarAvatar();
      if (file == null || !mounted) return;
      setState(() => _uploading = true);
      final url = await widget.storage.subirAvatar(file);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      _showMessage('Foto lista. Guarda el perfil para publicarla.');
    } on ProductUploadException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('No se pudo subir la foto. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _uploading) return;
    setState(() => _saving = true);
    try {
      _profile = await widget.repository.saveMine(
        displayName: _name.text,
        avatarUrl: _avatarUrl,
        whatsappVisible: _whatsappVisible,
        whatsappPhone: _phone.text,
      );
      if (!mounted) return;
      setState(() {});
      _showMessage('Tu perfil publico para chats se guardo.');
    } on ArgumentError catch (error) {
      if (mounted) _showMessage(error.message.toString());
    } catch (_) {
      if (mounted) {
        _showMessage(
          'No se pudo guardar. Revisa tu conexion e intenta otra vez.',
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
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: LinearProgressIndicator(minHeight: 3),
        ),
      );
    }

    if (_schemaUnavailable) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_sync_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'El perfil publico para chats se activara cuando se aplique la migracion de Supabase. Tu cuenta y tus datos actuales siguen funcionando.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final initial = _name.text.trim().isEmpty ? 'A' : _name.text.trim()[0];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perfil publico para chats',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Esto es lo que veran otras personas dentro de Agro+.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  PublicProfileAvatar(
                    radius: 34,
                    initial: initial,
                    imageUrl: _avatarUrl,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickAvatar,
                      icon: _uploading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _uploading ? 'Subiendo foto' : 'Cambiar foto',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre que veran en el chat',
                  counterText: '',
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) {
                    return 'Escribe el nombre que quieres mostrar.';
                  }
                  if (name.length > 80) {
                    return 'Usa hasta 80 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _whatsappVisible,
                onChanged: (value) => setState(() {
                  _whatsappVisible = value;
                  if (!value) {
                    _phone.clear();
                  }
                }),
                title: const Text('Mostrar mi WhatsApp'),
                subtitle: const Text(
                  'Opcional. Si lo activas, otras personas registradas veran el numero.',
                ),
              ),
              if (_whatsappVisible) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 16,
                  decoration: const InputDecoration(
                    labelText: 'Numero internacional',
                    hintText: '+593...',
                    helperText:
                        'Al ocultarlo, el numero se borra del perfil publico.',
                  ),
                  validator: (value) {
                    final phone = (value ?? '').replaceAll(
                      RegExp(r'[\s()\-]'),
                      '',
                    );
                    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
                      return 'Incluye el codigo del pais, por ejemplo +593...';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || _uploading ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Guardando' : 'Guardar perfil publico'),
                ),
              ),
              if (_profile == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Tu nombre y foto se publicaran en Agro+ cuando guardes.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
