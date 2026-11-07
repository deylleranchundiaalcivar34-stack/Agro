import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/supabase_service.dart';
import '../../data/models/chat_conversation.dart';
import '../../data/repositories/chat_repository.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({super.key, this.repository});
  final ChatRepository? repository;
  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  late final ChatRepository _repository =
      widget.repository ?? ChatRepository(supabaseService: SupabaseService());
  List<ChatConversation> _chats = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = await _repository.listMine();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar tus conversaciones.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Mensajes Agro+'),
      actions: [
        IconButton(
          tooltip: 'Actualizar conversaciones',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 16),
                Text(_error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _load,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          )
        : _chats.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aun no tienes conversaciones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Abre un producto para contactar a su productor.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.products),
                    child: const Text('Ver productos'),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: _chats.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final isBuyer = chat.buyerId == _repository.currentUserId;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.agriculture, color: AppColors.surface),
                  ),
                  title: Text(
                    chat.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    isBuyer
                        ? 'Conversacion con el productor'
                        : 'Consulta de un comprador',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context
                      .push('${AppRoutes.chatList}/${chat.id}')
                      .then((_) {
                        if (mounted) _load();
                      }),
                );
              },
            ),
          ),
  );
}
