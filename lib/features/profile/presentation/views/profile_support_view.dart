import 'package:flutter/material.dart';

import '../widgets/profile_subpage.dart';

class ProfileSupportView extends StatelessWidget {
  const ProfileSupportView({super.key});

  static const _questions = <(String, String)>[
    (
      '¿Como publico un producto?',
      'Si tu cuenta es de productor, toca el boton azul + del menu inferior y completa la informacion del producto.',
    ),
    (
      '¿Como contacto a un productor?',
      'Abre una publicacion o el mapa, selecciona el producto y usa la opcion para iniciar una conversacion.',
    ),
    (
      '¿Como cambio mi contrasena?',
      'Entra a Mi perfil, abre Seguridad y confirma primero tu contrasena actual.',
    ),
    (
      '¿Para que sirve la zona publica?',
      'Permite que un productor comparta voluntariamente una zona aproximada para aparecer en el mapa. No publica su ubicacion exacta del dispositivo.',
    ),
    (
      '¿Donde encuentro mis pedidos y avisos?',
      'Abre Mi perfil. Alli puedes consultar tus pedidos y las notificaciones recibidas en Agro+.',
    ),
  ];

  @override
  Widget build(BuildContext context) => ProfileSubpage(
    title: 'Ayuda y soporte',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Preguntas frecuentes',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (final item in _questions)
          Card(
            elevation: 0,
            child: ExpansionTile(
              title: Text(
                item.$1,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(alignment: Alignment.centerLeft, child: Text(item.$2)),
              ],
            ),
          ),
      ],
    ),
  );
}
