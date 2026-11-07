# Captura de RSSI de referencia en Android

Esta herramienta cubre WI-SP01-02 y WI-TS08-02. Es una pantalla de diagnóstico en compilaciones debug, no un flujo final de Rumbo. Las muestras se guardan en un CSV privado de la app; no se envían al backend. El RSSI es una observación de señal y no se convierte aquí en distancia.

## Decisión técnica

Se evaluaron `flutter_reactive_ble` y `flutter_blue_plus`. Ambas ofrecen descubrimiento BLE en Flutter, pero el requisito de seguir capturando con la app minimizada o bloqueada necesita mantener el trabajo en Android y un servicio en primer plano. Se usa la API oficial `BluetoothLeScanner` desde un servicio Kotlin, con `MethodChannel` y `EventChannel` para el control y los eventos visibles en Flutter. No hay dependencia de Unity.

La captura usa ventanas de **5 segundos de escaneo y 15 segundos de pausa** (`SCAN_MODE_BALANCED`), con máximo una muestra por baliza cada 500 ms. El servicio evita un segundo escaneo simultáneo, detiene cada ventana antes de iniciar la siguiente y libera el callback al detenerse. La notificación persistente permite detener la sesión. Si Android detiene el proceso o el usuario fuerza el cierre de la app, la sesión no se reinicia automáticamente.

Android detiene escaneos BLE sin filtro cuando la pantalla se apaga. Por ello, el descubrimiento inicial dura 10 segundos con la pantalla encendida y **la captura requiere al menos una dirección BLE o un UUID de servicio**. Una dirección BLE puede rotar; si las balizas del escenario la cambian, usar un UUID de servicio anunciado o definir un filtro estable con Julio antes de la prueba.

Como las lecturas se usarán para posicionamiento, el manifiesto solicita ubicación precisa y **no** declara `neverForLocation` en `BLUETOOTH_SCAN`; esa bandera podría filtrar algunas balizas. El servicio se inicia desde la pantalla visible y continúa como servicio en primer plano mientras la captura esté activa.

## Prueba con teléfono y balizas reales

1. Coordinar con Julio el escenario de WI-SP01-01: identificadores de balizas, ubicaciones de referencia y condiciones de recorrido. No registrar resultados si no se conoce la referencia física.
2. Instalar una compilación debug en un Android con BLE. Abrir **Inicio → Diagnóstico BLE**.
3. Conceder Bluetooth, ubicación **precisa** y, si Android lo solicita, notificaciones. Activar Bluetooth y el servicio de ubicación del dispositivo.
4. Con la pantalla encendida, pulsar **Descubrir 10 s**. Seleccionar las direcciones de las balizas preparadas. También se puede introducir un UUID de servicio anunciado; varios UUID se separan con comas.
5. Escribir la **ubicación de referencia** y la **condición** (por ejemplo, quieta o caminando). Pulsar **Capturar RSSI**.
6. Esperar al menos dos ciclos de 20 segundos. Minimizar la app y bloquear la pantalla durante parte de la captura. La notificación debe permanecer y el contador de muestras debe aumentar al regresar a la pantalla.
7. Repetir con otra ubicación o condición: detener primero la sesión y volver a iniciarla con las nuevas etiquetas. El CSV conserva las filas anteriores.
8. Detener desde la pantalla o la notificación. Verificar que no sigan apareciendo muestras nuevas.

La pantalla muestra la ruta del archivo `rumbo_rssi_reference.csv` en el almacenamiento privado. En una compilación debug puede extraerse con **Android Studio → Device Explorer** desde la ruta mostrada. Las columnas son `timestamp_utc`, `device_id`, `advertised_name`, `manufacturer_data`, `rssi_dbm`, `reference_location` y `condition`. Los nombres y direcciones proceden del anuncio BLE; no se asume que la dirección sea un identificador permanente ni que mayor RSSI implique menor distancia.

## Dependencias con otros WI

- **WI-TS08-01 (Jaziel):** esta fase declara y solicita el mínimo de permisos necesario para ejecutar el escaneo. Jaziel conserva la responsabilidad de revisar el flujo final de permisos y su experiencia de usuario.
- **WI-SP01-01 (Julio):** la selección de balizas y los puntos físicos de referencia dependen de su escenario. Esta entrega no contiene mediciones físicas ni estimaciones de precisión.

Las comprobaciones con hardware pendientes son: visibilidad de las balizas, concesión y revocación de permisos en versiones reales de Android, continuidad con pantalla bloqueada, comportamiento de direcciones aleatorias, interrupción por Bluetooth apagado y lectura del CSV después de recorridos reales.
