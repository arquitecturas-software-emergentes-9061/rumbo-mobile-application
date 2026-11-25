# Validación de navegación indoor

Flutter conserva la sesión, destino, ruta y progreso al mostrar 2D o AR. El directorio consulta destinos publicados con el token del paciente. El recálculo conserva el destino y las preferencias y envía el nodo de origen actualizado al mismo servicio A* del backend.

## Preparar una sede

1. Publica el mapa con escala, destinos y nodos de referencia transitables. Registra las identidades iBeacon y mide RSSI con un Android representativo en al menos dos nodos de cada zona que se vaya a guiar. Para calibrar AR, mide dos puntos del mismo piso separados al menos 1,25 m que puedan recorrerse en línea recta.
2. Prepara un JSON con un arreglo de sedes. Cada elemento tiene `siteId`, `modelVersionId` y `points`. Cada punto tiene `nodeId` y un arreglo `signals` de `{ "uuid": "...", "major": 1, "minor": 2, "rssiDbm": -65 }`. Completa IDs y RSSI con tus mediciones. Exporta el RSSI de referencia desde el diagnóstico BLE y usa los valores robustos de sesiones independientes.
3. Inicia la API con el perfil postgres y `--rumbo.navigation.ble-survey=file:/ruta/mediciones.json`. Vincula la medición con cada publicación que utilices. Si falta la medición, la publicación cambió o las señales son ambiguas, la API no entrega una posición.
4. En un teléfono conectado por USB, ejecuta `adb reverse tcp:8080 tcp:8080` y compila en debug con `--dart-define=RUMBO_API_BASE_URL=http://127.0.0.1:8080`. También puedes usar la URL HTTPS de una API accesible desde el teléfono. Entra con una cuenta de paciente.

## Compilar y probar AR

Exporta Unity con **Rumbo → Export Android library** usando Unity 6000.3.26f1 con Android Build Support. Comprueba que `rumbo-ar-unity/Builds/Android/unityLibrary` existe antes de compilar el APK Flutter.

En un Android compatible con ARCore, elige un destino publicado y busca la ubicación en un nodo medido. Pulsa **Ver en AR**, apunta al suelo y camina hacia la segunda referencia. Comprueba que la instrucción coincide con el pasillo y los giros. Interrumpe el tracking, vuelve a 2D y confirma que el destino y el progreso siguen visibles. Retoma AR, prueba **Calibrar**, cambia de piso por 2D y luego provoca un desvío para comprobar el recálculo.

Mide repetibilidad RSSI, error espacial y deriva en campo. Los umbrales de software y las pruebas con señales controladas no acreditan precisión en una sede real.
