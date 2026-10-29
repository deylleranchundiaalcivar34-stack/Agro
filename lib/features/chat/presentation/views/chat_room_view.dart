import 'package:flutter/material.dart';

/// Sala de chat individual entre productor y comprador.
/// TODO (Bloque 5): Implementar mensajes en tiempo real con Supabase Realtime.
class ChatRoomView extends StatelessWidget {
  final String roomId;

  const ChatRoomView({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat #$roomId')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '🚧 Chat Realtime — Bloque 5',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

