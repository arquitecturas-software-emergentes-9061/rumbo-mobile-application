# Rumbo Mobile Application

Base Flutter compartida para la aplicación móvil Android/iOS de pacientes y acompañantes de Rumbo. El escaneo BLE de Fase 1 funciona en Android; la Fase 2 incorpora análisis RSSI en Dart puro. El adaptador BLE iOS queda pendiente.

## Decisiones de la base

- Flutter y Dart para la aplicación móvil, según la decisión del equipo.
- Organización por bounded context y por capas `application`, `domain`, `infrastructure` y `presentation`, siguiendo la estructura del proyecto Restock proporcionado como referencia.
- `go_router` para el shell de navegación, `get_it` para composición de dependencias y `flutter_bloc` disponible para los futuros flujos con estado. La capa de dominio no depende de Flutter, HTTP ni del almacenamiento.
- Tema visual inicial basado en los colores y la navegación inferior del [wireframe móvil de Rumbo](https://www.figma.com/design/AHtjv9ROVjsIrE7UE6rTay/Rumbo---UI-Topic?node-id=33-20659).
- El cliente móvil consumirá el Web Services API REST. El modelo espacial publicado es propiedad de Planning; la sesión y el guiado pertenecen a Navigation.

La estrategia AR prevé un único proyecto Unity/AR Foundation, con ARCore XR Plugin en Android y ARKit XR Plugin en iOS. No se implementa Unity en esta fase.

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

Cada contexto incorpora sus capas cuando se implemente el primer caso de uso. Las pantallas del producto siguen siendo marcadores de posición. La ruta debug **Inicio → Diagnóstico BLE** contiene la herramienta Android de la [Fase 1](docs/ble_reference_capture.md) para WI-SP01-02 y WI-TS08-02. El [análisis multiplataforma de Fase 2](docs/multiplatform_ble_phase2.md) cubre WI-SP01-03 mediante modelos y algoritmos compartidos, sin cambiar esa pantalla.

## Ejecutar

Se necesita Flutter con Dart compatible con `pubspec.yaml` y el entorno Android configurado. El proyecto Android base ya está incluido; el target iOS todavía no se ha generado y requerirá Mac y Xcode. En este entorno no está disponible el SDK Android:

```sh
flutter pub get
flutter run --dart-define=RUMBO_API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` es la dirección del host desde el emulador Android. Para un dispositivo físico, usar la dirección accesible del API. IAM ya hace solicitudes reales de inicio de sesión y recuperación de sesión.

Para probar IAM desde Flutter Web con el backend local, inicia la API y usa un puerto Web fijo que esté permitido por CORS:

```sh
flutter run -d chrome --web-port=4200 --dart-define=RUMBO_API_BASE_URL=http://localhost:8080
```

Web utiliza `http://localhost:8080` por defecto si no se define la URL y el emulador Android usa `http://10.0.2.2:8080` en debug. El backend local permite por defecto el origen web `http://localhost:4200`. Si se usa otro host o puerto, agrégalo a `CORS_ALLOWED_ORIGINS`. El directorio remoto carga destinos publicados con el token del paciente. Consulta [la guía de validación](docs/sprint2_navigation_validation.md) para preparar la sede y probar BLE y AR.

## Próximos pasos

Agregar cada historia dentro de su contexto, empezando por entidades y contratos del dominio, luego aplicación, adaptadores de infraestructura y BLoC/pantallas. La captura BLE Android de Fase 1 y el análisis RSSI compartido de Fase 2 ya están incorporados. La captura iOS, la resolución de posición productiva, AR, FCM y el almacenamiento de sesión se abordarán en sus work items correspondientes.
