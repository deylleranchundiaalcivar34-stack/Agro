import 'package:flutter/material.dart';
import 'chat_room_view.dart';

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = [
      {
        'roomId': 'room_1',
        'name': 'Finca San José (Productor 1)',
        'product': 'Tomate Riñón y Pimiento',
        'lastMessage': 'Hola, me interesa coordinar la entrega...',
        'time': '08:15',
        'unread': 2,
        'online': true,
      },
      {
        'roomId': 'room_2',
        'name': 'Huertos del Chimborazo (Productor 2)',
        'product': 'Papa Superchola y Cebolla',
        'lastMessage': 'Claro, tenemos 15 quintales listos para hoy.',
        'time': 'Ayer',
        'unread': 0,
        'online': true,
      },
      {
        'roomId': 'room_3',
        'name': 'AgroFrutales Guano (Productor 3)',
        'product': 'Mora de Castilla y Frutilla',
        'lastMessage': 'El precio por gaveta le queda en 12 dólares.',
        'time': 'Ayer',
        'unread': 1,
        'online': false,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F6),
      appBar: AppBar(
        title: const Text(
          'Mensajes Agro+',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 110),
        itemCount: chats.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final chat = chats[index];
          final isOnline = chat['online'] == true;
          final unreadCount = chat['unread'] as int;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Stack(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.agriculture, color: Colors.white, size: 28),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.lightGreenAccent.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              chat['name'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat['product'].toString(),
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  chat['lastMessage'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat['time'].toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (context) => ChatRoomView(
                    roomId: chat['roomId'].toString(),
                    producerName: chat['name'].toString(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}