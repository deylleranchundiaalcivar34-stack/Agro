# 🌾 Agro+ — Del Campo A Tu Mano

Aplicacion movil disenada para conectar directamente a pequenos y medianos agricultores con compradores, optimizando la comercializacion agricola y reduciendo las perdidas poscosecha mediante herramientas de geolocalizacion, bases de datos en la nube y servicios en tiempo real.

---

## 👥 Equipo de Desarrollo
* **Jhonatan Gadvay**
* **Mirian Saquinga**
* **Deyller Anchundia**
* **David Castillo**

---

## 📌 Problematica
Los pequenos y medianos agricultores enfrentan perdidas economicas severas debido al desperdicio de alimentos generado por la sobreproduccion y la falta de canales directos para comercializar sus excedentes a tiempo, lo que provoca que los cultivos se deterioren.

## 💡 Propuesta y Fases de Comercializacion
**Agro+** optimiza la venta agricola operando bajo un flujo estrategico de tres etapas:
1. **Fase 0 (Preventa):** Publicacion de cosechas futuras para medir la demanda antes de recolectar.
2. **Fase 1 (Venta Directa):** Comercializacion de productos disponibles al publico y comercios.
3. **Fase 2 (Canales Alternativos):** Venta de excedentes a tiendas, restaurantes o ganaderos, o valorizacion organica (abono y compostaje) si el producto pierde uso alimenticio.

---

## 🛠️ Tecnologias Utilizadas

* **Frontend Movil:** Flutter (con patron arquitectonico MVVM y Clean Architecture).
* **Backend y Base de Datos:** Supabase (Supabase Auth, Supabase Database con PostgreSQL, Supabase Storage y Supabase Realtime).
* **Gestion de Imagenes:** Cloudinary / Supabase Storage.
* **Mapas y Geolocalizacion:** OpenStreetMap, Flutter Map, Geolocator y Geoapify.
* **Control de Versiones:** Git y GitHub.
* **Diseno UI/UX:** Figma.
* **Entorno:** Visual Studio Code y Android Studio.

---

## 📱 Requisitos Funcionales Principales
* **RF01 - Gestion de Cuentas y Accesos:** Registro e inicio de sesion con control de permisos segun rol (Comprador, Vendedor/Productor y Administrador).
* **RF02 - Publicacion y Preventa:** Creacion de publicaciones de productos o cosechas futuras indicando precios, cantidades y fotografias.
* **RF03 - Busqueda y Geolocalizacion:** Filtrado de productos, visualizacion interactiva en mapas y calculo de distancias entre productores y compradores.
* **RF04 - Comunicacion (Chat):** Canales de negociacion directa para acordar precios, cantidades y entregas.
* **RF05 - Aprovechamiento de Excedentes:** Sugerencias de compradores alternativos y opciones de abono/compostaje.
* **RF06 - Notificaciones y Avisos:** Alertas sobre publicaciones, disponibilidad y oportunidades de compra.

---

## 📂 Estructura del Proyecto (Clean Architecture / MVVM)
```text
lib/
├── core/
│   ├── constants/       # Colores, textos y constantes de la app
│   ├── network/         # Configuracion y servicios de Supabase
│   ├── router/          # Enrutamiento con GoRouter y Auth Guards
│   └── theme/           # Tema Material 3 centralizado
│
└── features/
    ├── auth/            # Modulo de Autenticacion (Login, Registro, Roles)
    ├── home/            # Panel de Control Agricola (Dashboard)
    ├── products/        # CRUD de Productos, Catalogo y Preventas
    ├── map/             # Geolocalizacion y Mapas
    ├── chat/            # Mensajeria instantanea en tiempo real
    └── notifications/   # Alertas y avisos del sistema