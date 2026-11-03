# La Última Mano

Juego de cartas de terror psicológico para Linux, con interfaz pixel art.
Despertás en una habitación familiar con tres desconocidos. Reconstruí los
recuerdos 6 y 7 para intentar salir antes de que alguien lo haga por vos.

Proyecto independiente derivado de [Sick Seven](https://github.com/Monguit0/sick-seven)
y de su [adaptación Linux](https://github.com/gokuexe/sick-seven-linux).
Los repositorios originales conservan su historial. Aquí se mantienen los créditos
y la procedencia. Ver [UPSTREAM.md](UPSTREAM.md).

## Desarrollo en Linux

Requiere Flutter 3.44 o posterior, GTK 3, CMake, Ninja, Clang y las bibliotecas
de desarrollo GStreamer. Esta versión se validó con Flutter 3.47.9 en Ubuntu 22.04.

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev \
  libblkid-dev liblzma-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
flutter pub get
flutter test
flutter run -d linux
```

El directorio `linux/` ya está incluido. No hace falta regenerarlo.

```bash
flutter build linux --release
./build/linux/x64/release/bundle/la_ultima_mano
```

Distribuí el directorio `bundle` completo: incluye ejecutable, datos y bibliotecas.
El workflow Linux ejecuta pruebas y compila con permisos de lectura. No publica
releases automáticamente.

## Reglas

Jugás contra tres rivales sin conexión. Las cartas modifican dos recuerdos
numéricos; necesitás un 6 y un 7 para intentar salir. Cada turno recuperás
lucidez para jugar cartas o responder a los demás. Incluye modos Clásico,
Rápido y Farol.

## Estado

Primera versión jugable con escenario, retratos, cartas y textos nuevos.
La campaña, la progresión persistente y el rediseño sonoro están pendientes.

## Créditos

- Mecánicas y código original: Monguit0, proyecto Sick Seven.
- Adaptación Linux y evolución: historial de sick-seven-linux.
- Rediseño La Última Mano: desarrollo en este proyecto.
- Pixelify Sans: licencia SIL OFL incluida en `assets/fonts/OFL.txt`.
- Escenario `assets/art/room.png`: generado con imagegen para este rediseño.

No se ha añadido una licencia general nueva al código heredado: el repositorio
original consultado no publica un archivo de licencia. La licencia de la fuente
se mantiene por separado.

## Multijugador privado (prototipo)

La opción **Jugar online · Sala privada** permite crear una sala con código de
seis caracteres. De 2 a 4 personas comparten una partida; los lugares vacíos
se completan con bots. No requiere cuentas. El anfitrión elige el modo y
comienza cuando hay al menos dos personas.

El servidor valida las jugadas y envía a cada cliente solo su mano y los
recuerdos que puede conocer. Las respuestas tienen plazo y se validan para
el jugador al que pertenecen. Los diálogos son texto narrativo local, no un
chat escrito por los jugadores.

Para iniciar el servidor con el SDK de Dart:

```bash
cd server
dart pub get
dart run bin/server.dart
```

La dirección por defecto es `ws://127.0.0.1:8080/ws`. Para probar entre dos
notebooks de la misma red, el anfitrión puede escuchar en la red local:

```bash
HOST=0.0.0.0 PORT=8080 dart run bin/server.dart
```

En ese caso, ambos clientes usan `ws://IP-DEL-ANFITRION:8080/ws`, además del
mismo código de sala. El servidor solo necesita Dart para ejecutarse; su
motor no importa Flutter. También puede compilarse desde `server/` con
`dart compile exe bin/server.dart`. Las reglas compartidas están en
`packages/game_core/`.

El prototipo no está alojado públicamente. Para jugar por Internet hace falta
un servidor accesible y un proxy TLS que ofrezca `wss://`. No se incluyen
reconexión, persistencia, migración del anfitrión ni moderación. Una desconexión
termina la sala para todos. Las salas y los nombres se mantienen en memoria.
El código de sala sirve para invitar; no sustituye una contraseña de cuenta.

### Prueba entre dos equipos Linux en la misma red

1. El anfitrión inicia el servidor con `HOST=0.0.0.0`. La consola muestra las
   direcciones de red disponibles. Elegí la dirección de la conexión Wi-Fi o
   Ethernet que ambos equipos comparten.
2. En ambos juegos, abrí **Jugar online · Sala privada** e ingresá esa misma
   dirección de servidor. En la segunda notebook, `127.0.0.1` no apunta al
   anfitrión: apunta a la propia notebook.
3. El anfitrión crea una sala y comparte el código. La otra persona ingresa
   el código; el anfitrión comienza la partida.
4. Comprobá que se vean las manos propias, que las reacciones lleguen al
   jugador correcto y que ambos vean el mismo resultado al terminar.

Si no conecta, verificá que ambos equipos estén en la misma red, que la red no
sea de invitados con aislamiento entre dispositivos y que el firewall permita
el puerto elegido. El juego no modifica el firewall ni abre puertos del router.

### Servidor por Internet (preparación)

`render.yaml` prepara un servicio Docker gratuito en Render desde la rama
`feature/private-rooms`, con despliegues automáticos desactivados. El archivo no
crea un servicio por sí solo: primero hay que conectar la cuenta y desplegarlo.
El contexto Docker es la raíz del repositorio y el Dockerfile es
`server/Dockerfile`. No requiere claves dentro del juego.

Tras desplegar, verificar `https://DIRECCION-REAL/health` (respuesta `ok`) y
probar dos clientes usando `wss://DIRECCION-REAL/ws`. Para empaquetar la dirección
en el cliente Linux:

```sh
flutter build linux --release --dart-define=ONLINE_SERVER_URL=wss://DIRECCION-REAL/ws
```

Sustituir `DIRECCION-REAL` por el dominio asignado al servicio. Sin esta opción,
el cliente permite ingresar una dirección manualmente. La conexión segura
espera hasta 90 segundos a que el servidor despierte y muestra su progreso.

Las salas viven en memoria en una sola instancia: un reinicio termina las
partidas. El servidor avisa a los clientes al recibir SIGTERM. El plan gratuito
puede suspenderse o reiniciarse; usarlo inicialmente para pruebas.

### Reconexión y revancha

El servidor reserva cada asiento durante 60 segundos tras una desconexión.
El cliente v3 intenta volver automáticamente mientras conserva abierta la
aplicación. La partida y los tiempos de reacción quedan pausados hasta que
regresen todas las personas. El código de sala no permite recuperar un asiento:
se requiere una clave privada aleatoria que solo recibe su propietario y que
se mantiene en memoria. Cerrar la aplicación pierde esa clave; un reinicio del
servidor pierde las salas. Salir voluntariamente termina la participación sin
esperar los 60 segundos.

Al terminar, todas las personas deben pulsar «QUIERO REVANCHA». El servidor
cuenta un solo voto por asiento y reparte una partida nueva dentro de la misma
sala. La interfaz conserva los nombres y limpia la mesa anterior.
