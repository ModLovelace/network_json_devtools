# Formato de cifrado admitido

Network JSON permite inspeccionar cuerpos JSON cifrados con AES-CBC y, opcionalmente, recuperar la llave AES y el IV desde un sobre RSA del request.

## Sobre RSA

El request debe ser un objeto JSON con los siguientes campos:

```json
{
  "rsaEncryptedAesKey": "<Base64 del valor cifrado con RSA>",
  "rsaEncryptedIv": "<Base64 del valor cifrado con RSA>",
  "aesEncryptedData": "<Cuerpo cifrado con AES>"
}
```

Cada campo RSA usa RSA-OAEP con SHA-1/MGF1-SHA-1. El texto UTF-8 recuperado representa una lista JSON de bytes: 16, 24 o 32 bytes para la llave AES y 16 bytes para el IV. Se admiten valores RSA procesados en bloques con el mismo formato de codificación.

La llave privada debe corresponder a la llave pública utilizada para crear el sobre. Puede configurarse en PEM PKCS#1 o PKCS#8 sin contraseña. La lectura y el descifrado se realizan localmente en el panel.

## Cuerpos cifrados

Los cuerpos se interpretan como JSON, se extrae el campo configurado y se decodifica su contenido desde hexadecimal o Base64. El descifrado aplica, en orden:

1. AES-CBC con la llave y el IV seleccionados.
2. Eliminación del padding PKCS7.
3. Decodificación UTF-8.
4. Interpretación como JSON.

El valor predeterminado del request es `aesEncryptedData`. El valor predeterminado del response es `data`, por ejemplo:

```json
{"data": "<Cuerpo cifrado con AES>"}
```

Estos nombres de campo pueden cambiarse en la configuración, incluidas rutas como `payload.data`. Un nombre vacío usa el cuerpo JSON completo, que debe ser una cadena cifrada.

## Relación entre request y response

En modo RSA, ambos cuerpos usan la llave y el IV recuperados del request seleccionado. Por ello se necesita el request correspondiente para descifrar el response. El panel no comparte los valores recuperados entre llamadas distintas.

En modo manual, el usuario introduce directamente la llave AES y el IV de la llamada. Si el cliente cambia estos valores en cada petición, también debe actualizarse la configuración manual para cada par inspeccionado.

Un cuerpo sin un campo cifrado elegible se muestra como original. Los errores de llave, padding, codificación o JSON conservan el original y muestran el aviso correspondiente. AES-CBC en este formato no incluye un tag de autenticación.

## Referencias de implementación

- `lib/src/decryption.dart:19`: configuración y campos predeterminados.
- `lib/src/decryption.dart:95`: lectura de la llave privada y validación de AES manual.
- `lib/src/decryption.dart:122`: resolución de valores por par request/response.
- `lib/src/decryption.dart:169`: apertura del sobre RSA.
- `lib/src/decryption.dart:193`: AES-CBC, PKCS7, UTF-8 y JSON.
- `lib/src/decryption.dart:215`: longitudes admitidas de llave e IV.
