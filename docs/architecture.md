# Arquitectura de la aplicación móvil

## Relación con el C4 de Rumbo

La app es un cliente del Web Services API. No accede directamente a PostgreSQL, Redis ni RabbitMQ. La API implementa los siete bounded contexts del sistema y expone contratos REST versionados. La app organiza su código por los contextos que consume, sin asumir propiedad sobre sus aggregates del servidor.

| Contexto | Responsabilidad en la app |
| --- | --- |
| IAM | Acceso y sesión del visitante. |
| Profiles | Perfil y preferencias de accesibilidad y guiado. |
| Planning | Lectura del modelo espacial publicado, destinos y referencias de balizas. Su edición pertenece a la aplicación web. |
| Navigation | Posicionamiento, selección de destino, ruta y estado de guiado. |
| Communications | Centro de avisos y recepción de notificaciones. |
| Analytics | Envío de telemetría y retroalimentación del recorrido. |

Suscripciones y Pagos no tiene interfaz móvil en el alcance actual: se gestiona desde el flujo administrativo. Si surge un caso de uso móvil, se agregará su módulo entonces.

## Regla de capas

Cada módulo sigue el estilo de Restock:

```text
<context>/
  application/       # fachadas y coordinación de casos de uso
  domain/            # entidades, value objects y contratos de repositorio
  infrastructure/    # modelos de transporte, data sources y adaptadores
  presentation/      # pantallas, widgets y BLoC por flujo
```

El dominio no depende de Flutter ni de infraestructura. El contrato del repositorio vive en `domain/repositories`; la sesión de captura genérica contiene ubicación y condición, mientras que los filtros de escaneo Android viven en infraestructura. La implementación convierte los modelos del proveedor de plataforma a entidades del dominio. La fachada de aplicación coordina el repositorio y el servicio de permisos, y el BLoC transforma eventos en estado de presentación. Los módulos se comunican mediante valores explícitos, evitando importar modelos de transporte de otro contexto. `shared` contiene solo piezas transversales (tema, router, configuración de API y shell), sin reglas de negocio.

## Estado de esta entrega

La base contiene tema, router, configuración de API, composición de dependencias y pantallas de marcador de posición. La Fase 1 agrega entidades y un contrato de repositorio BLE en Navigation, una fachada de aplicación, modelos y un proveedor de canales de plataforma, un servicio Android para escaneo y CSV, y un BLoC con pantalla de diagnóstico disponible solo en debug. La Fase 2 agrega un modelo de mediciones por identificador lógico y algoritmos de comparación RSSI en Dart puro. La captura sigue siendo Android; el adaptador iOS está diseñado pero pendiente. Véanse [Captura de RSSI de referencia](ble_reference_capture.md) y [Fase 2 multiplataforma](multiplatform_ble_phase2.md).
