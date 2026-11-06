# Rumbo Mobile Application

Base Flutter para la aplicación Android de pacientes y acompañantes de Rumbo. Esta etapa prepara la estructura y la navegación de la aplicación; no implementa work items del Sprint 1.

## Decisiones de la base

- Flutter y Dart para la aplicación móvil, según la decisión del equipo.
- Organización por bounded context y por capas `application`, `domain`, `infrastructure` y `presentation`, siguiendo la estructura del proyecto Restock proporcionado como referencia.
- `go_router` para el shell de navegación, `get_it` para composición de dependencias y `flutter_bloc` disponible para los futuros flujos con estado. La capa de dominio no depende de Flutter, HTTP ni del almacenamiento.
- Tema visual inicial basado en los colores y la navegación inferior del [wireframe móvil de Rumbo](https://www.figma.com/design/AHtjv9ROVjsIrE7UE6rTay/Rumbo---UI-Topic?node-id=33-20659).
- El cliente móvil consumirá el Web Services API REST. El modelo espacial publicado es propiedad de Planning; la sesión y el guiado pertenecen a Navigation.

El documento del proyecto también menciona Unity/AR Foundation en un párrafo del diagrama C4 y en el spike de realidad aumentada. Esa integración no forma parte de esta base Flutter.

## Estructura

```text
lib/
  main.dart
  injections.dart
  shared/                 # configuración, navegación y UI compartida
  iam/                    # identidad y control de acceso
  profiles/               # perfiles y preferencias
  planning/               # lectura del modelo espacial publicado
  navigation/             # posicionamiento y guiado interior
  communications/         # avisos y notificaciones
  analytics/              # retroalimentación y telemetría del recorrido
```

Cada contexto incorpora sus capas cuando se implemente el primer caso de uso. Las pantallas actuales son marcadores de posición, sin autenticación, BLE, búsqueda, rutas, API ni notificaciones.

## Ejecutar

Se necesita Flutter con Dart compatible con `pubspec.yaml` y el entorno Android configurado. El proyecto Android base ya está incluido. En este entorno no está disponible el SDK, por lo que las dependencias y los archivos generados por Flutter se preparan al ejecutarlo localmente:

```sh
flutter pub get
flutter run --dart-define=RUMBO_API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` es la dirección del host desde el emulador Android. Para un dispositivo físico, usar la dirección accesible del API. La URL se registra en la configuración, pero todavía no se hacen solicitudes.

## Próximos pasos

Agregar cada historia dentro de su contexto, empezando por entidades y contratos del dominio, luego aplicación, adaptadores de infraestructura y BLoC/pantallas. Las integraciones de BLE, AR, FCM y almacenamiento seguro se incorporarán cuando correspondan a sus work items y estén definidos sus contratos.
