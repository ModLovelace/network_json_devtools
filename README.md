# Network JSON · DevTools

Inspector HTTP para Dart y Flutter DevTools con descifrado local y un visor JSON. Muestra una tabla de peticiones y paneles **Overview**, **Headers**, **Request** y **Response**. Puedes alternar entre el cuerpo original y el descifrado, explorar el árbol JSON y copiar el contenido.

## Requisitos

- Flutter/Dart y las extensiones Dart y Flutter de VS Code si utilizas ese editor.
- Una aplicación móvil o desktop en modo debug con tráfico registrado por el perfil HTTP de Dart.
- Una llave privada RSA o una llave AES y un IV compatibles con el [formato de cifrado admitido](doc/FORMATO_CIFRADO.md).

Probado con Flutter **3.41.8**, Dart **3.11.5** y `devtools_extensions` **0.4.0**.

## Instalación desde pub.dev

Una vez publicada la versión 0.1.2, puedes añadirla como dependencia de desarrollo:

```sh
flutter pub add dev:network_json_devtools
```

```yaml
dev_dependencies:
  network_json_devtools: ^0.1.2
```

## Licencia

El código y la documentación propios de Network JSON se distribuyen bajo **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)**. Permite compartir y adaptar el material para fines no comerciales, conservando la atribución, el enlace a la licencia y la indicación de cambios conforme a sus términos.

Consulta [LICENSE](LICENSE), [NOTICE](NOTICE) y los [avisos de terceros](THIRD_PARTY_NOTICES.md). Los componentes de terceros conservan sus licencias respectivas.

## Instalación local

La distribución local incluye los recursos compilados de la extensión en `extension/devtools/build/`.

Si trabajas desde un clon del repositorio que no incluya esos recursos generados, compílalos primero con `dart run tool/build.dart`.

Desde la carpeta de esta herramienta, indica la ruta de tu aplicación Flutter:

```sh
dart run tool/install.dart /ruta/a/tu/aplicacion
```

El instalador añade una dependencia de desarrollo local mediante `flutter pub add`. También puedes añadirla manualmente al `pubspec.yaml` de tu aplicación; ajusta la ruta a la ubicación del paquete:

```yaml
dev_dependencies:
  network_json_devtools:
    path: ../network_json_devtools
```

Después ejecuta `flutter pub get` en la aplicación. El instalador no copia llaves ni modifica el cliente HTTP.

## Uso en VS Code

1. Ejecuta la aplicación en debug y abre DevTools desde la paleta de comandos de VS Code.
2. En **Extensions**, habilita **network_json_devtools** y abre su pestaña.
3. Pulsa **Configurar llave** y elige el origen de la llave.
4. En modo **Sobre RSA de cada petición**, utiliza **Cargar archivo PEM** o pega una llave privada compatible. Admite PKCS#1 y PKCS#8 sin contraseña.
5. Cuando aparezca **Llave privada cargada**, pulsa **Aplicar y descifrar**.
6. Con el panel abierto, realiza una petición en tu aplicación y selecciona su fila.
7. Revisa **Request** y **Response**, alternando **Descifrado** y **Original**. El botón de código cambia entre árbol y texto; el de copiar copia la vista elegida.

El diálogo conserva la llave durante la importación y evita el cierre por clics fuera o Escape. **Cancelar** o el botón de cerrar descartan los cambios pendientes. Un archivo inválido no sustituye una llave que ya se haya cargado.

Si actualizas una instalación local abierta, ejecuta `flutter pub get` en tu aplicación y reinicia VS Code antes de volver a abrir DevTools. El encabezado de esta versión indica **v0.1.2**.

## Modos de descifrado

**Sobre RSA de cada petición:** el request contiene `rsaEncryptedAesKey` y `rsaEncryptedIv`. La llave privada configurada abre estos valores y recupera la llave AES y el IV del par request/response. Los nombres predeterminados de los cuerpos cifrados son `aesEncryptedData` para el request y `data` para el response.

**Llave AES + IV manuales:** introduce los valores correspondientes a la petición seleccionada. La llave AES admite 16, 24 o 32 bytes; el IV debe tener 16 bytes. Puedes introducirlos en hexadecimal, Base64, texto UTF-8 o como lista de bytes de Dart, por ejemplo `[1, 2, ...]`.

El texto cifrado admite hexadecimal o Base64. Los campos del request y response son configurables y admiten rutas como `payload.data`. Un campo vacío usa el cuerpo JSON completo, que debe ser una cadena cifrada.

## Controles y captura

- Captura HTTP/HTTPS del perfil de Dart, incluido `dart:io`, `package:http` y Dio sobre `HttpClient`.
- Pausa y reanudación, **Clear** local, búsqueda y filtros como `m:post s:200 t:json`.
- Tabla con orden por hora y un máximo de 500 peticiones. Los cuerpos se solicitan al seleccionar una fila.
- Separador arrastrable y paneles apilados cuando el ancho disponible es menor de 800 px.
- Árbol JSON con carga progresiva, texto seleccionable y copia.
- Headers sensibles ocultos hasta pulsar **Mostrar sensibles**.
- Indicaciones de peticiones pendientes, errores HTTP, fallos de conexión y errores de descifrado.

**Clear** solo borra la lista de esta extensión; conserva el perfil compartido con Network. La captura no altera el tráfico ni las respuestas que recibe la aplicación.

## Llaves y límites

La llave permanece solo en memoria del panel. No se escribe en almacenamiento local ni se envía a servidores. **Olvidar llave** elimina la configuración y las vistas descifradas. Cerrar o recargar el panel exige configurarla otra vez.

El descifrado admite **AES-CBC con PKCS7** y, para abrir el sobre RSA, **RSA-OAEP SHA-1/MGF1-SHA-1**. No detecta automáticamente otros algoritmos. Una llave pública no sustituye a la privada. Si no se puede descifrar un cuerpo, se conserva el original y se muestra un aviso.

Flutter Web utiliza el tráfico del navegador y queda fuera de este perfil de `dart:io`. Los cuerpos que Dart no haya registrado no se pueden recuperar después. Los sockets TCP no forman parte de la tabla de esta herramienta.

## Desarrollo y pruebas

Desde la raíz del paquete:

```sh
dart pub get
dart test # requiere OpenSSL para comprobar interoperabilidad
dart analyze lib test tool example
cd packages/network_json_extension
flutter test
flutter analyze
cd ../..
dart run tool/verify_vm.dart
dart run tool/build.dart
```

El último comando sincroniza la documentación pública de `docs/` a `doc/`, genera la interfaz Flutter web en `extension/devtools/build/` y ejecuta el validador oficial de extensiones. Los recursos de CanvasKit son locales y la página utiliza rutas relativas.

Para abrir una demostración con datos ficticios:

```sh
dart run tool/build.dart --demo
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/demo
```

Abre `http://127.0.0.1:8765`. La compilación **DEMO** utiliza una llave AES de prueba y no reemplaza los recursos de la extensión real.

Para generar tráfico real contra un backend de prueba en localhost:

```sh
dart --observe=0 example/main.dart
```

Abre el enlace de DevTools que imprime Dart, habilita la extensión y carga el PEM temporal cuya ruta aparece como `Sample PEM:`. La demo genera una llave RSA nueva al arrancar y una llave AES y un IV nuevos por petición. El PEM temporal se elimina al cerrar normalmente con Ctrl+C. No se distribuyen archivos PEM ni capturas de aplicaciones.

## Documentación

- [Formato de cifrado admitido](doc/FORMATO_CIFRADO.md).
- [Verificación y pruebas](doc/VALIDACION.md).
- [Historial de cambios](CHANGELOG.md).
- [Instrucciones y pendientes de publicación](PUBLICACION.md).
- [Guía oficial de extensiones de DevTools](https://docs.flutter.dev/tools/devtools/custom-tool).
