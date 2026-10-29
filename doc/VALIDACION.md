# Verificación y pruebas

Las pruebas utilizan datos genéricos y llaves generadas durante cada ejecución. No se distribuyen PEM guardados, capturas de aplicaciones ni fixtures anteriores. El ejemplo HTTP solo se conecta a localhost.

## Comandos

Desde la raíz del paquete, con Dart, Flutter y OpenSSL disponibles en el PATH:

```sh
dart test
dart analyze lib test tool example
cd packages/network_json_extension
flutter test
flutter analyze
cd ../..
dart run tool/verify_vm.dart
dart run tool/build.dart
```

## Cobertura

| Área | Comprobaciones |
| --- | --- |
| Cifrado | JSON y Unicode, PEM PKCS#1/PKCS#8, llaves diferentes por llamada, AES manual y contraste con OpenSSL. |
| Errores | Llaves inválidas, sobres incompletos, longitudes incorrectas y contenido no JSON. |
| Perfil HTTP | Captura desde una VM Dart local y descifrado de request y response hasta JSON. |
| Interfaz | Request/Response, headers sensibles, olvidar llave, filtros, Clear y panel estrecho. |
| Importación PEM | Lectura asíncrona, clic fuera, Escape, cancelación y reemplazo inválido sin perder la llave anterior. |
| Distribución | Compilación Flutter web, validación oficial de DevTools y revisión del contenido publicable. |

La prueba de interoperabilidad crea archivos temporales, cifra con `openssl pkeyutl` (RSA-OAEP SHA-1/MGF1-SHA-1) y `openssl enc -aes-256-cbc` (PKCS7), y comprueba el resultado con el descifrador del paquete. Los archivos se eliminan al terminar. Las otras pruebas de cifrado y las de interfaz generan sus llaves en memoria.

## Alcance

Las pruebas automatizadas verifican la implementación y una VM local de ejemplo. La compatibilidad con una API concreta requiere que utilice el [formato admitido](FORMATO_CIFRADO.md) y la llave correspondiente.

Las pruebas de importación utilizan un selector controlado. El selector nativo del editor requiere además una comprobación manual.

## Mejora de puntuación · 0.1.3 · 2026-10-29

El [informe publicado de 0.1.2](https://pub.dev/packages/network_json_devtools/versions/0.1.2/score) otorgó 125/160. La versión local 0.1.3 con licencia MIT obtuvo **160/160** con Pana 0.23.19, Dart 3.11.5 y Dartdoc 9.0.11, ejecutado sobre una copia temporal del paquete.

| Categoría | 0.1.2 publicada | 0.1.3 local |
| --- | --- | --- |
| Convenciones de archivos | 25/30 | 30/30 |
| Documentación | 10/20 | 20/20 |
| Plataformas | 20/20 | 20/20 |
| Análisis estático | 40/50 | 50/50 |
| Dependencias | 30/40 | 40/40 |
| **Total** | **125/160** | **160/160** |

Los 54 elementos de la API pública tienen documentación Dartdoc (100 %). Se habilitaron las reglas oficiales de análisis de Dart y la comprobación de documentación pública en `lib/`. PointyCastle se actualizó a 4.0.0; se retiraron `encrypt` y su dependencia transitiva descontinuada `js`. La lectura de PEM conserva RSA PKCS#1 y PKCS#8 mediante el analizador ASN.1 de PointyCastle.

Las 18 pruebas Dart y las 9 de interfaz pasaron, al igual que ambos analizadores, la captura HTTP de una VM local y el validador de DevTools. La interoperabilidad incluye llaves generadas por OpenSSL, sobres RSA-OAEP SHA-1 y cuerpos AES-CBC, además de errores de formato y de algoritmo del PEM.

El propietario eligió MIT para el material propio de 0.1.3. La licencia está reconocida por OSI y permite obtener los 30 puntos de convenciones de archivos. Se conservan la atribución a ModLovelace y los avisos de terceros. La versión 0.1.2 publicada conserva su licencia original. El resultado definitivo en pub.dev requiere publicar la nueva versión y que el servicio vuelva a analizarla; la medición local no modifica el puntaje de 0.1.2.

La simulación inicial `dart pub publish --dry-run` no detectó errores de paquete. Su única advertencia correspondió a modificaciones locales sin confirmar en Git (código de salida 65). Antes de publicar 0.1.3, repetir la simulación desde un estado limpio de Git y comprobar que termina sin advertencias. No se ejecutó la publicación real de esta versión.
