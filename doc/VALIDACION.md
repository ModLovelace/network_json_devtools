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

## Entrega 0.1.2 · 2026-10-28

Se verificaron 15 pruebas Dart y 9 de interfaz, ambos analizadores, la captura HTTP de una VM local, la compilación release y el validador oficial de DevTools. Se retiraron los diagramas y fixtures anteriores y se sustituyeron los ejemplos por datos genéricos.

La licencia es CC BY-NC 4.0 para el material propio, con atribución y conservación de los avisos de terceros. La simulación de publicación deja pendiente la URL del repositorio. Los pasos y pendientes están en [PUBLICACION.md](../PUBLICACION.md).
