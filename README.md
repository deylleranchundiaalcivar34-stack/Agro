# 🌾 Agro+ — Del Campo A Tu Mano

Aplicación móvil diseñada para conectar directamente a pequeños y medianos agricultores con compradores, optimizando la comercialización agrícola y reduciendo las pérdidas poscosecha mediante herramientas de geolocalización, bases de datos en la nube y servicios en tiempo real.

---

## 👥 Equipo de Desarrollo
* **Jhonatan Gadvay**
* **Mirian Saquinga**
* **Deyller Anchundia**
* **David Castillo**

---

## 📌 Problemática
Los pequeños y medianos agricultores enfrentan pérdidas económicas severas debido al desperdicio de alimentos generado por la sobreproducción y la falta de canales directos para comercializar sus excedentes a tiempo, lo que provoca que los cultivos se deterioren.

## 💡 Propuesta y Fases de Comercialización
**Agro+** optimiza la venta agrícola operando bajo un flujo estratégico de tres etapas:
1. **Fase 0 (Preventa):** Publicación de cosechas futuras para medir la demanda antes de recolectar.
2. **Fase 1 (Venta Directa):** Comercialización de productos disponibles al público y comercios.
3. **Fase 2 (Canales Alternativos):** Venta de excedentes a tiendas, restaurantes o ganaderos, o valorización orgánica (abono y compostaje) si el producto pierde uso alimenticio.

---

## 🛠️ Tecnologías Utilizadas

* **Frontend Móvil:** Flutter (con patrón arquitectónico MVVM y Clean Architecture).
* **Backend y Base de Datos:** Supabase (Supabase Auth, Supabase Database con PostgreSQL, Supabase Storage y Supabase Realtime).
* **Gestión de Imágenes:** Cloudinary / Supabase Storage.
* **Mapas y Geolocalización:** OpenStreetMap, Flutter Map, Geolocator y Geoapify.
* **Control de Versiones:** Git y GitHub.
* **Diseño UI/UX:** Figma.
* **Entorno:** Visual Studio Code y Android Studio.

---

## 📱 Requisitos Funcionales Principales
* **RF01 - Gestión de Cuentas y Accesos:** Registro e inicio de sesión con control de permisos según rol (Comprador, Vendedor/Productor y Administrador).
* **RF02 - Publicación y Preventa:** Creación de publicaciones de productos o cosechas futuras indicando precios, cantidades y fotografías.
* **RF03 - Búsqueda y Geolocalización:** Filtrado de productos, visualización interactiva en mapas y cálculo de distancias entre productores y compradores.
* **RF04 - Comunicación (Chat):** Canales de negociación directa para acordar precios, cantidades y entregas.
* **RF05 - Aprovechamiento de Excedentes:** Sugerencias de compradores alternativos y opciones de abono/compostaje.
* **RF06 - Notificaciones y Avisos:** Alertas sobre publicaciones, disponibilidad y oportunidades de compra.

---

## 📂 Estructura del Proyecto (Clean Architecture / MVVM)
```text
lib/
├── core/
│   ├── constants/       # Colores, textos y constantes de la app
│   ├── network/         # Configuración y servicios de Supabase
│   ├── router/          # Enrutamiento con GoRouter y Auth Guards
│   └── theme/           # Tema Material 3 centralizado
│
└── features/
    ├── auth/            # Módulo de Autenticación (Login, Registro, Roles)
    ├── home/            # Panel de Control Agrícola (Dashboard)
    ├── products/        # CRUD de Productos, Catálogo y Preventas
    ├── map/             # Geolocalización y Mapas
    ├── chat/            # Mensajería instantánea en tiempo real
    └── notifications/   # Alertas y avisos del sistema