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

Tras detener la captura, pulsa **Exportar CSV RSSI** y elige dónde guardar `rumbo_rssi_reference_v2.csv`. La pantalla también muestra la ruta privada para **Android Studio → Device Explorer**. Las columnas son `timestamp_utc`, `device_id`, `advertised_name`, `manufacturer_data`, `rssi_dbm`, `reference_location`, `condition` y `run_id`. Cada inicio de captura genera un `run_id` UUID que se repite en las filas de esa sesión. El archivo anterior `rumbo_rssi_reference.csv` permanece intacto en el mismo directorio. Los nombres y direcciones proceden del anuncio BLE; no se asume que la dirección sea un identificador permanente ni que mayor RSSI implique menor distancia.

Para normalizar el archivo nuevo: `dart run tool/rssi_analysis.dart normalize-android rumbo_rssi_reference_v2.csv normalizado.csv pixel-1 legacy-only`. El adaptador conserva el `run_id` de cada fila; el último argumento solo se usa con archivos antiguos. Después, `dart run tool/rssi_analysis.dart select-run normalizado.csv calibracion.csv <run_id>` y lo mismo para la sesión de prueba. Ejecutar `dart run tool/rssi_analysis.dart compare calibracion.csv prueba.csv`. Conservar los originales: la herramienta no sobrescribe salidas. Las filas sin identidad iBeacon verificable se cuentan y omiten; pedir a Julio el inventario real si el hardware no emite ese payload. El reporte expresa dispersión y diferencias RSSI en dB, y una estimación de ubicación por comparación; no es error espacial en metros.

## Dependencias con otros WI

- **WI-TS08-01 (Jaziel):** esta fase declara y solicita el mínimo de permisos necesario para ejecutar el escaneo. Jaziel conserva la responsabilidad de revisar el flujo final de permisos y su experiencia de usuario.
- **WI-SP01-01 (Julio):** la selección de balizas y los puntos físicos de referencia dependen de su escenario. Esta entrega no contiene mediciones físicas ni estimaciones de precisión.

Las comprobaciones con hardware pendientes son: visibilidad de las balizas, concesión y revocación de permisos en versiones reales de Android, continuidad con pantalla bloqueada, comportamiento de direcciones aleatorias, interrupción por Bluetooth apagado y lectura del CSV después de recorridos reales.

## Prueba de PR-198 con un teléfono como emisor

No se necesitan balizas comerciales para el primer experimento. En un segundo teléfono Android compatible, abrir **Inicio → Diagnóstico BLE → Emisor BLE de referencia**, dejar el UUID de baliza de prueba o ingresar otro, conceder el permiso **Dispositivos cercanos** y pulsar **Emitir referencia BLE**. El teléfono anuncia una trama iBeacon `UUID/1/1` por radio. En el teléfono Rumbo receptor, pulsar **Descubrir 10 s**, seleccionar su dirección y capturar RSSI con la ubicación y condición anotadas. El anuncio iBeacon no contiene un UUID de servicio GATT; no usar el filtro de UUID de servicio para esta prueba. Registrar los puntos físicos medidos, por ejemplo 1 m, 3 m y 5 m, junto con línea de vista, pared y teléfono quieto/caminando. Repetir cada condición y detener ambos lados al terminar.

La opción usa el emisor BLE del sistema Android; no inventa mediciones RSSI. Requiere Android 12 o posterior con Bluetooth LE Peripheral/Advertiser disponible. Una laptop alternativa debe emitir la misma trama iBeacon, no solo un servicio GATT. El CSV Android guarda `manufacturer_data=004C:0215...`; `normalize-android` reconoce esa identidad sin asignar MAC como identidad lógica. Cada emisor simultáneo necesita un UUID distinto. La comparación de huellas en `RssiAnalysisService` exige al menos dos emisores compartidos entre calibración y prueba; con uno solo se pueden estudiar dispersión y estabilidad, pero no concluir una ubicación. La distancia conocida se registra como referencia del ensayo; RSSI no se convierte a metros. El modo emisor es solo para diagnóstico y se detiene al salir de la pantalla o cerrar la actividad.

El CSV v2 conserva `run_id`. Normalizarlo completo y usar `select-run` para separar las corridas antes de comparar. Para un emisor también puede resumirse una corrida ya seleccionada:

```sh
dart run tool/rssi_analysis.dart normalize-android rumbo_rssi_reference_v2.csv normalizado.csv telefono-1 legacy-only
dart run tool/rssi_analysis.dart select-run normalizado.csv corrida-a-normalizada.csv <run_id>
dart run tool/rssi_analysis.dart summarize corrida-a-normalizada.csv
```

El resumen muestra cantidad, media, mediana, desviación estándar, MAD y valores atípicos por ubicación, condición y baliza. Mantener la distancia física anotada fuera del CSV como referencia del ensayo. La estadística de señal no representa por sí sola error de posición en metros. Para evaluar ubicación, captar al menos dos emisores distintos en cada punto y usar corridas independientes de calibración y prueba con el comando `compare`.

La calibración para comparar ubicación debe reunir lecturas de al menos dos puntos de referencia de la misma fuente y condición; puede combinar varias corridas conservando sus `run_id` y una sola cabecera CSV. El archivo de prueba debe contener una única corrida, ubicación y condición, excluida de la calibración. `select-run` permite separar esa prueba sin mezclar sesiones; `compare` rechaza un archivo de prueba con referencias mezcladas.
