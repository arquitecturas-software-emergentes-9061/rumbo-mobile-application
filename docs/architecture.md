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

El arranque incorpora IAM: `SessionFacade`, `SessionCubit`, repositorio, API HTTP y almacenamiento seguro inyectado. El router protege el shell y ofrece Bienvenida, Iniciar sesión, Crear cuenta y recuperación con Reintentar. El resto de contextos conserva sus pantallas de marcador de posición, con una acción mínima de cierre de sesión en Perfil.

### Regla de primera visita (PR-51)

`SessionFacade.restore()` distingue la ausencia de sesión guardada (`Unauthenticated(firstVisit: true)`, Bienvenida) del rechazo del refresh por cualquier 4xx (`SessionExpired`, Iniciar sesión con aviso y correo precargado). Un refresh correcto consulta `profiles/me/preferences`: `configured: false` dirige a `/profile`; `configured: true`, a `/home`. Un error de red, 5xx o una respuesta de preferencias no utilizable ofrece Reintentar sin borrar la sesión.

Solo se persisten refresh token, correo y userId en un registro seguro. El access token vive en memoria. Cada refresh rotado se guarda antes de consultar preferencias. Al expirar se retira el token y se conservan correo y userId; el cierre de sesión también retira los tokens y establece `Unauthenticated(firstVisit: false)`, con destino a Bienvenida. No se registran tokens en logs.

Los contextos consumidores pueden inyectar `AuthorizedClient` (contrato `http.Client`) para añadir Bearer y repetir una solicitud una sola vez después de un 401 y refresh correcto. Los refresh concurrentes en curso comparten una misma operación. El cliente HTTP de autenticación es independiente de ese wrapper para evitar recursión. Ningún modelo de transporte de Profiles entra en el dominio IAM.
