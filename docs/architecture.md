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

Las dependencias apuntan hacia el dominio. Los módulos se comunican mediante contratos de aplicación y valores explícitos, evitando importar modelos de transporte de otro contexto. `shared` contiene solo piezas transversales (tema, router, configuración de API y shell), sin reglas de negocio.

## Estado de esta entrega

Solo están creadas las piezas que tienen uso en el arranque: tema, router, configuración de API, composición de dependencias y pantallas de marcador de posición. No hay entidades ni repositorios inventados sin un caso de uso, y ninguna pantalla afirma resultados de BLE, rutas o datos reales.
