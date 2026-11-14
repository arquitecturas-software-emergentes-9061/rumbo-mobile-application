# Fase 2 — análisis RSSI compartido para Android e iOS

## Evidencia y alcance

El documento de Rumbo define el identificador lógico del beacon como `UUID/Major/Minor` en US-14 y en el value object `BeaconIdentifier`. Esto corresponde al esquema iBeacon, pero todavía debe confirmarse con las balizas físicas del escenario WI-SP01-01 que emitan ese payload. No hay evidencia de un servicio GATT concreto ni de otro formato de anuncio. WI-SP01-03 pide comparar técnicas iniciales y cuantificar dispersión o error observado; aquí se implementa el mecanismo de análisis, sin resultados físicos inventados.

La Fase 1 se conserva: el `BleDiagnosticsRepository<T extends BleCaptureSession>` y su fachada no importan APIs ni identificadores Android. La configuración genérica del dominio contiene solo la ubicación y condición; `AndroidBleSessionConfiguration` mantiene las direcciones y filtros Android en infraestructura. El diagnóstico debug se muestra solo en Android. `BleObservation.deviceId` sigue siendo un identificador opaco del dispositivo, no la identidad lógica; la solicitud de permisos y algunos estados/mensajes de diagnóstico siguen reflejando el flujo Android. Su CSV contiene `device_id` y `manufacturer_data`, pero no un identificador lógico ni un límite de sesión. Es una fuente de datos de Android, no el contrato multiplataforma definitivo.

## Flujo de datos

```text
Android Fase 1 CSV ── AndroidPhase1RssiCsvAdapter ─┐
                                                     ├─ RssiMeasurement (Domain)
iOS Core Location (pendiente) ─ adaptador Swift/Dart ┘          │
                                                               ├─ RssiAnalysisService
                                                               └─ CSV común / herramienta de comparación
```

`RssiMeasurement` contiene `beaconId = UUID/major/minor`, `rssiDbm`, `observedAt` UTC, `referenceLocation`, `condition`, `sourceId` (teléfono o procedencia de captura) y `runId` (sesión). El formato CSV común usa `timestamp_utc,beacon_uuid,major,minor,rssi_dbm,reference_location,condition,source_id,run_id`. No transporta MAC ni `CBPeripheral.identifier` como identidad lógica. Una lectura sin identidad comprobable queda fuera de la comparación y el adaptador informa cuántas filas omitió. Una asignación de dirección Android a baliza solo se acepta si procede de un inventario explícito; si contradice el payload iBeacon, se rechaza.

La herramienta de desarrollo permite normalizar un CSV Android de Fase 1 y comparar un archivo de calibración con otro de prueba:

```sh
dart run tool/rssi_analysis.dart normalize-android fase1.csv calibracion.csv pixel-1 corrida-calibracion
dart run tool/rssi_analysis.dart normalize-android fase1-prueba.csv prueba.csv pixel-1 corrida-prueba
dart run tool/rssi_analysis.dart compare calibracion.csv prueba.csv
```

El CSV histórico de Fase 1 es acumulativo y no guarda `run_id`. **Antes de normalizarlo, separar físicamente las filas de cada sesión usando el registro de prueba y sus timestamps**; la herramienta asigna el `run_id` proporcionado a todo el archivo y no puede deducir los límites de sesión. El CSV nuevo `rumbo_rssi_reference_v2.csv` añade `run_id` por fila y puede normalizarse completo; luego `select-run` extrae cada sesión para comparar. Conservar las cabeceras al separar archivos antiguos. Si no existe esa información, no usar el archivo histórico para comparar corridas independientes. La herramienta no altera el CSV original y se niega a sobrescribir un archivo de salida existente.

El análisis agrupa por fuente, sesión, ubicación, condición y baliza. Calcula media, mediana, desviación estándar, desviación absoluta mediana (MAD) y media tras excluir valores atípicos con regla de Hampel (umbral `3 × 1.4826 × MAD`). La comparación crea huellas RSSI de las sesiones de calibración de **la misma fuente** y evalúa **una sesión separada** mediante diferencia absoluta media de señal en dB; exige por defecto dos balizas compartidas y al menos dos ubicaciones candidatas comparables. Un iPhone necesita su propia calibración: no se reutiliza automáticamente la huella RSSI de un Android. Compara media, mediana y media robusta sin escoger una como ganadora a priori. Una igualdad exacta o cobertura desigual entre las dos primeras candidatas produce resultado no concluyente. El puntaje en dB **no es una distancia física ni un nivel de confianza calibrado**.

`referencePointSeparationMeters` solo devuelve la separación entre dos puntos medidos de Planning, con escala real y mismo piso para referencia y estimación. Si faltan puntos o son pisos distintos, devuelve `null`. Incluso un valor cero no mide el error de posición del teléfono dentro de ese punto o zona. Para evaluar estabilidad y error espacial real en campo se requieren varias corridas independientes por ubicación y condición, tiempos registrados, balizas configuradas y una posición física de referencia medida. Comparar Android/iOS por separado por `sourceId`; no asumir igual frecuencia de muestras, sesgo RSSI ni precisión. Las pruebas automatizadas usan valores sintéticos exclusivamente para comprobar cálculos y contratos.

## Diseño iOS pendiente

- Si las balizas reales son iBeacon, usar **Core Location** para monitoreo de región y ranging durante una sesión explícita. `CLBeacon` aporta UUID, major, minor y RSSI; el adaptador Swift convierte esos valores al mismo `RssiMeasurement`. [Apple: identificación y ranging iBeacon](https://developer.apple.com/documentation/corelocation/determining-the-proximity-to-an-ibeacon-device).
- Si el hardware anuncia UUID de servicios BLE, usar **Core Bluetooth** para descubrir esos servicios; acordar con Planning un identificador lógico estable del anuncio o inventario antes de convertir a `BeaconIdentifier`. Un identificador local de `CBPeripheral` no sustituye UUID/major/minor. Solo combinar ambos frameworks si el hardware requiere ambas clases de señal. [Apple: Core Bluetooth](https://developer.apple.com/documentation/corebluetooth).
- La sesión comienza desde una acción visible, conserva su `runId`, termina explícitamente y libera el monitoreo/ranging/scan. El adaptador debe reportar capacidades y fallos sin prometer una tasa fija de muestras. La integración Flutter futura necesitará un proveedor iOS y composición de dependencias por plataforma; no hay todavía proyecto `ios/` ni implementación Swift.

En segundo plano, iOS puede suspender la app. Core Bluetooth requiere el modo `bluetooth-central` para ciertas tareas, agrupa descubrimientos duplicados y puede aumentar el intervalo de escaneo. El ranging iBeacon se diseña principalmente para uso en primer plano; el monitoreo de región puede despertar la app para eventos, pero no equivale a RSSI continuo. No se traslada el ciclo Android de 5 s/15 s a iOS. Validar permisos, capacidades y comportamiento real en cada versión de iOS y con la pantalla bloqueada. [Apple: Core Bluetooth en segundo plano](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html), [Apple: guía iBeacon](https://developer.apple.com/ibeacon/Getting-Started-with-iBeacon.pdf).

Para validar: Mac con Xcode, Flutter y herramientas iOS configuradas; cuenta de desarrollo y firma para instalar; iPhone físico con Bluetooth, permisos de localización adecuados y balizas reales identificadas; recorridos repetidos en puntos medidos, primero en primer plano y después con app minimizada/bloqueada. El simulador no sustituye una prueba de radio BLE. [Flutter: configuración iOS](https://docs.flutter.dev/platform-integration/ios/setup).

## Unity compartido, sin avanzar a AR

No hay proyecto Unity en este repositorio. Cuando corresponda la fase AR, crear **un solo proyecto** con escenas y lógica C# basadas en AR Foundation, y activar ARCore XR Plugin para Android y ARKit XR Plugin para iOS mediante XR Plug-in Management. Las diferencias de disponibilidad, permisos, configuración de cámara y comportamiento de tracking se aíslan en adaptadores o configuración por plataforma; no se incorporan APIs ARCore/ARKit directas en la lógica C# compartida. No se crea ni modifica Unity en esta Fase 2. [Unity: AR Foundation y proveedores](https://docs.unity3d.com/cn/2023.2/Manual/AROverview.html).

## Work Items adicionales propuestos (identificadores provisionales)

1. **IOS-01 — Confirmar hardware y contrato de identidad:** verificar con Julio el payload iBeacon real, UUID/major/minor, rotación de direcciones y relación con el inventario de Planning.
2. **IOS-02 — Preparar target Flutter iOS:** generar `ios/` en Mac, configurar firma, permisos y modos de fondo que justifique el adaptador elegido.
3. **IOS-03 — Adaptador BLE Swift:** Core Location para iBeacon o Core Bluetooth para servicios anunciados, ciclo de sesión, estados, errores y exportación al formato común.
4. **IOS-04 — Validación de captura en iPhone:** primer plano, minimizada/bloqueada, Bluetooth/permisos revocados, frecuencia y calidad de muestras; comparar corridas de referencia sin asumir equivalencia con Android.
5. **AR-PLATFORM-01 — Proyecto Unity único:** cuando inicie la fase AR, configurar AR Foundation con ambos proveedores y validar capacidades en Android e iPhone.
