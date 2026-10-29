# Publicación de Network JSON

Entrega para el agente que creará el repositorio y publicará el paquete en pub.dev.

## Objetivo y alcance

- Paquete que se publica: `network_json_devtools`, desde la raíz de este proyecto.
- Versión preparada: `0.1.2`.
- El subproyecto `packages/network_json_extension` compila la interfaz y conserva `publish_to: none`; no se publica como paquete independiente.
- No se ha creado ni subido un repositorio remoto desde esta entrega. No se ha ejecutado la publicación real en pub.dev.
- El propietario ya tiene cuenta en pub.dev. El inicio de sesión y la autorización finales corresponden a su cuenta.

## Licencia ya elegida

El usuario ha elegido **CC BY-NC 4.0** para el material propio de Network JSON.

- `LICENSE`: texto oficial completo de Creative Commons Attribution-NonCommercial 4.0 International.
- `NOTICE`: atribución a **ModLovelace**, copyright 2026 y alcance de la licencia.
- `THIRD_PARTY_NOTICES.md`: conservación de las licencias de dependencias.
- La licencia del proyecto no sustituye las licencias de terceros ni las de los avisos generados por Flutter.

La decisión de licencia está tomada; no reemplazarla por una licencia diferente al preparar la publicación.

## Pendientes del repositorio

1. Elegir con el propietario el nombre del repositorio público y crearlo en su cuenta u organización. No se ha inventado una URL para esta entrega.
2. Añadir a `pubspec.yaml` la URL real en `repository`. Añadir también `issue_tracker` si corresponde. `homepage` es opcional.
3. Cambiar `issueTracker` de `extension/devtools/config.yaml` por la URL real de los issues. Actualmente apunta a la documentación de DevTools como enlace provisional.
4. Ejecutar la compilación y las verificaciones de esta guía.
5. Subir las fuentes, `LICENSE`, `NOTICE`, los avisos de terceros, el README, el historial de cambios y los documentos públicos al nuevo repositorio.

Se puede crear el repositorio por la interfaz de GitHub o mediante una CLI autorizada. Si se usa GitHub CLI, comprobar su autenticación antes de operar. No convertir esta carpeta en un worktree de otro proyecto: es una herramienta independiente.

Para un repositorio Git nuevo, después de confirmar su URL:

```sh
git init
git add .
git commit -m "Prepare Network JSON 0.1.2"
git branch -M main
git remote add origin URL_REAL_DEL_REPOSITORIO
git push -u origin main
```

Sustituir `URL_REAL_DEL_REPOSITORIO` antes de ejecutar el comando. Si Git o el remoto ya existen, revisar su estado y continuar desde él sin reinicializar ni sobrescribir cambios.

## Qué debe conservar el paquete

- `lib/`: código Dart del paquete.
- `extension/devtools/config.yaml`: metadatos de la extensión.
- `extension/devtools/build/`: interfaz compilada, CanvasKit, assets y avisos de Flutter.
- `doc/`: documentación pública con el nombre de carpeta esperado por Pub.
- `README.md`, `CHANGELOG.md`, `LICENSE`, `NOTICE` y `THIRD_PARTY_NOTICES.md`.
- Las pruebas y el ejemplo de localhost generan llaves y datos genéricos en cada ejecución. No se incluyen PEM guardados ni capturas anteriores.

La documentación mantenida en `docs/` se sincroniza a `doc/` mediante `dart run tool/build.dart`. `.pubignore` excluye `docs/` de la publicación para evitar duplicados. Las cachés y salidas de desarrollo también se excluyen.

Los recursos compilados pueden estar ignorados por Git. Por eso, después de clonar el repositorio hay que ejecutar la compilación antes de publicar. No publicar solo `config.yaml` sin su directorio `build/`.

No hay excepciones `false_secrets` en el manifiesto. Las pruebas usan llaves efímeras y eliminan sus archivos temporales al terminar. La prueba de interoperabilidad requiere `openssl` en el PATH.

## Verificaciones antes de subir

Desde la raíz:

```sh
dart pub get
dart test
dart analyze lib test tool example
cd packages/network_json_extension
flutter pub get
flutter test
flutter analyze
cd ../..
dart run tool/verify_vm.dart
dart run tool/build.dart
dart pub publish --dry-run
```

`--dry-run` valida y muestra el contenido del paquete sin subirlo. Comprobar en su salida que:

- El nombre y la versión son los previstos.
- Se incluyen `LICENSE`, `NOTICE`, los avisos de terceros y la interfaz compilada.
- No aparecen cachés del SDK, configuración personal, diagramas antiguos, PEM guardados ni datos de aplicaciones.
- La advertencia sobre `homepage`/`repository` desaparece después de añadir la URL real.
- No quedan errores de validación.

## Publicación real en pub.dev

1. Verificar que el nombre `network_json_devtools` está disponible o pertenece a la cuenta del propietario. La disponibilidad definitiva no queda garantizada por una simulación local.
2. Comprobar que la versión `0.1.2` no haya sido publicada previamente; si existe, elegir otra versión y mantenerla sincronizada con `extension/devtools/config.yaml`, el subproyecto de interfaz y el historial de cambios.
3. Repetir la simulación después de completar los enlaces reales del repositorio.
4. Ejecutar desde la raíz:

```sh
dart pub publish
```

Completar la autorización de Google si la herramienta la solicita y revisar la lista de archivos antes de confirmar la subida. No usar `--force` ni `--skip-validation` para la primera publicación.

Publicar el código en GitHub no publica automáticamente el paquete en pub.dev.

## Verificación después de publicar

- Abrir la página del paquete en pub.dev y confirmar versión, licencia, README y enlaces.
- Probar en una app de ejemplo la instalación desde el registro:

```sh
flutter pub add dev:network_json_devtools
```

- Iniciar debug, abrir DevTools y habilitar `network_json_devtools`.
- Comprobar captura HTTP, carga del PEM y descifrado con datos de prueba compatibles.
- Registrar la versión publicada en Git y actualizar las instrucciones de instalación si fuese necesario.

## Estado de validación de esta entrega

Verificado el 2026-10-28:

| Comprobación | Resultado |
| --- | --- |
| Licencia | Texto oficial CC BY-NC 4.0, atribución propia y avisos de terceros incluidos. |
| `dart test` | 15 pruebas correctas. |
| `dart analyze lib test tool example` | Sin incidencias. |
| Interfaz | 9 pruebas correctas y análisis Flutter sin incidencias después de la limpieza. |
| `dart run tool/verify_vm.dart` | Captura HTTP local y descifrado de ambos cuerpos correctos. |
| `dart run tool/build.dart` | Compilación release y validador oficial de DevTools correctos; demo recompilada. |
| `dart pub publish --dry-run` | Sin errores de validación; una advertencia por faltar `homepage` o `repository`. |
| Tamaño comprimido estimado por Pub | 12 MB. |
| Limpieza | Sin referencias al proyecto original, fixtures anteriores ni diagramas antiguos en las fuentes y el paquete distribuible. |
| Publicación real | No ejecutada. |

El SDK utilizado devuelve código 65 cuando la simulación tiene advertencias. En esta entrega la única advertencia pendiente depende de crear el repositorio y añadir su URL real. Después de completar ese dato, repetir la simulación y comprobar que termina sin advertencias.

Se retiraron los fixtures anteriores, los PEM persistentes y los diagramas antiguos. Las pruebas usan datos genéricos generados durante la ejecución y conservan una comprobación independiente con OpenSSL. La documentación pública se genera en `doc/`.
