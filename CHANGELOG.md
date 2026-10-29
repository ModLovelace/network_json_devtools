# Historial de cambios

## 0.1.2 · 2026-10-28

- Licencia CC BY-NC 4.0 para el material propio, atribución y conservación de avisos de terceros.
- Preparación de la publicación del paquete raíz y guía de entrega con los pendientes del repositorio.
- Interfaz, descripciones y documentación genéricas para inspeccionar APIs con sobres RSA y cuerpos AES-CBC.
- Guía de instalación portable y contrato de cifrado documentado.
- Limpieza de ejemplos, pruebas y artefactos anteriores; llaves de prueba generadas en cada ejecución, sin PEM persistentes ni diagramas antiguos.
- Reglas de distribución que incluyen la interfaz compilada y excluyen los metadatos locales de desarrollo.

## 0.1.1 · 2026-10-28

- El diálogo de configuración permanece abierto al volver del selector de PEM: un clic fuera o Escape no descarta la llave pendiente de aplicar.
- La carga bloquea temporalmente aplicar, cerrar y cancelar mientras lee y valida el archivo.
- Cancelar la selección o importar un PEM inválido conserva la llave anterior y muestra el error cuando corresponde.
- El mensaje de llave cargada indica que falta pulsar «Aplicar y descifrar».
- Cuatro pruebas de regresión nuevas cubren importación asíncrona, clic fuera, Escape, cancelación y reemplazo inválido.

## 0.1.0 · 2026-10-26

- Inspector de DevTools con captura del perfil HTTP, descifrado RSA-OAEP/AES-CBC y vistas JSON para request y response.
