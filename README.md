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

## La habitación reacciona (0.3.0)

Cuando tus recuerdos quedan a un ajuste de la salida, los retratos de los
rivales locales se vuelven hostiles, la luz cambia lentamente y suena un latido
suave. Al tener 6/7, el ambiente se intensifica. Los diálogos tienen prioridad
breve, un intervalo mínimo de 12 segundos y un máximo de tres por partida.
El efecto visual respira una vez y queda estático; no mantiene una animación
infinita ni tapa los controles. Volumen, silencio y movimiento reducido se respetan.

La atmósfera y los **Guiños al dispositivo** están activos por defecto, también
al actualizar desde una versión sin esa opción. Podés desactivarlos por separado
en Ajustes; una elección guardada de desactivación se respeta. Los guiños usan únicamente el
sistema/plataforma, el idioma elegido dentro del juego y la hora local para
frases de cuarta pared. No consultan archivos, nombres de usuario, contactos,
ubicación, micrófono, cámara ni identificadores. El contexto se calcula solo
al aparecer un diálogo con la opción activa; no se manda por red. En web,
la plataforma se presenta simplemente como Web. Online, habla la habitación,
sin atribuir frases a otros jugadores ni consultar sus recuerdos ocultos.

## Confirmación y navegación (0.2.2)

Elegir una carta abre sus objetivos y una confirmación final antes de gastar
la carta o la lucidez. Podés cancelar en cualquiera de esos pasos; Atrás también
cierra la selección. Una jugada ya confirmada y resuelta no se deshace.

Atrás o el botón de salida durante una partida piden confirmación. La mesa
local se pausa mientras elegís; una partida online continúa para el resto.
El resultado queda visible hasta elegir jugar otra partida o volver al inicio,
con una protección breve contra toques accidentales al aparecer. En historia
se conserva la opción de leer el desenlace y el progreso de la victoria.
Los cambios se comparten entre Android, Linux y web; GameMonetize no se actualiza.

## Audio (0.2.1)

Corrige los efectos silenciosos en Android: SoundPool no emite la confirmación
que espera `seek(0)`, por lo que nunca se ejecutaba la reproducción. Los efectos
ahora reinician con `stop` y `resume`, conservando el sonido precargado. La carga
concurrente se comparte, una reproducción temprana espera la carga y los archivos
que fallen pueden reintentarse. El cambio se aplica a Android, Linux y web;
el silencio por volumen cero o publicidad sigue respetándose. La corrección
no se publica automáticamente en GameMonetize.

## Edición Pulso (0.2.0, prueba)

Clásico e historia usan el catálogo revisado: Parálisis cuesta 3 de lucidez,
El reflejo sube en 1 un recuerdo propio y baja el otro en 1, e Insomnio solo
se usa una vez por turno. Los bots conservan lo que han visto con La mirilla
hasta que ese recuerdo cambia y evalúan combinaciones de dos cartas.

Al cerrar tu turno ganás una carga de Pulso, hasta 3. Anclaje consume las tres
para ajustar un recuerdo propio en +1 o −1, sin gastar lucidez. No se puede
activar congelado o después de Parálisis. Al comenzar con mano llena podés
cambiar una carta antes de actuar, una vez por turno. Rápido tiene 3 de lucidez;
Farol permite un solo intento de salida por turno. La revancha rota el inicio.

Cada partida completada da 30 puntos por ganar o 10 por perder. Los marcos
Ámbar y Eco se desbloquean con 40 y 100 puntos; son cosméticos y no alteran
las cartas. El progreso se guarda localmente. Hay nuevos sonidos originales,
retratos que parpadean, respuesta al pulsar cartas y una puerta al ganar.
Las opciones de volumen y movimiento reducido siguen disponibles.

El protocolo distingue ediciones: clientes antiguos mantienen las reglas
originales; las salas Pulso requieren clientes compatibles. La actualización
del servidor público se realiza aparte de estos paquetes de prueba. No se
sustituye el ZIP ni se modifica la revisión pendiente de GameMonetize.

## Reglas

Jugás contra tres rivales sin conexión. Las cartas modifican dos recuerdos
numéricos; necesitás un 6 y un 7 para intentar salir. Cada turno recuperás
lucidez para jugar cartas o responder a los demás. Incluye modos Clásico,
Rápido y Farol.

## Estado

Primera versión jugable con escenario, retratos, cartas y textos nuevos.
Incluye un primer capítulo con progreso local, partida libre y salas privadas online. Más capítulos y persistencia de partidas en curso siguen pendientes.

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

### Idioma, comodidad y guía de cartas

El selector «Español / English» está en el menú y en ajustes. Cambia la interfaz,
las cartas, los diálogos, la historia y la guía sin reiniciar la partida.
La elección se guarda localmente: cada persona online puede jugar en su propio
idioma. Los nombres escritos por los jugadores, los identificadores de cartas y
las reglas compartidas con el servidor se conservan. El nombre del juego y los
nombres propios de los personajes mantienen su forma original.

Las traducciones están en `lib/l10n/english_messages.dart`; `catalog.dart` resuelve
los mensajes variables de la mesa. Los nuevos textos visibles deben añadirse al
catálogo y renderizarse con `GameText` o `context.tr`; los nombres de jugadores
se renderizan con `translate: false`.

«AJUSTES Y GUÍA DE CARTAS», en el menú y en la mesa, permite regular volumen,
ampliar la lectura y reducir movimiento. Esta última opción elimina los
principales destellos, sacudidas, confeti, entrada de cartas y escritura
progresiva; las ventanas de reacción mantienen su duración. Se respeta también
la preferencia de movimiento reducido del sistema.

En Linux, los ajustes se guardan localmente en
`$XDG_CONFIG_HOME/la_ultima_mano/preferences.json`, o en
`$HOME/.config/la_ultima_mano/preferences.json` si XDG_CONFIG_HOME no está definido.
No se envían al servidor. Si no se puede guardar, la pantalla avisa y los cambios
siguen activos durante esa sesión.

La guía contiene las 20 cartas con sus efectos y costes del mismo catálogo que
usa el motor; permite buscar sin tildes y filtrar por familia. Abrirla no pausa
la partida. El menú se desplaza cuando el texto grande necesita más espacio.

### Historia · Capítulo 01

El menú conserva la partida libre y añade un recorrido singleplayer opcional:
una decisión inicial (el nombre o la puerta), una mesa de práctica sin rivales,
una introducción a los tres desconocidos y una partida Clásica normal. La
práctica enseña a formar el 6 y el 7 y a gastar lucidez; se puede reiniciar sin
consecuencias. No modifica los repartos ni las decisiones de los bots de la
partida real.

Al finalizar, «LEER DESENLACE» vuelve al capítulo. La victoria desbloquea un cierre
que depende de la decisión inicial; la derrota ofrece reintentar. Abandonar no
completa el capítulo. Se guardan la decisión, el tutorial completado y el cierre
desbloqueado en `story-progress.json`, junto a las preferencias locales. Una
partida a mitad de camino no se conserva; volver a la primera mesa inicia otra.
Un fallo de guardado se muestra en pantalla y permite continuar en la sesión.

### Web / GameMonetize

La aplicación compila también para navegador. Los sockets usan
`web_socket_channel`, la espera de salud usa `http` y el guardado local elige
archivos en Linux o `localStorage` en web. Si el navegador bloquea el guardado,
se puede jugar y la interfaz explica que el avance solo dura esa sesión.

El GameId público se configura en `web/portal-config.js`. El SDK oficial se
carga desde `https://api.gamemonetize.com/sdk.js`; no se incluyen claves de la
cuenta. Se solicitan anuncios solo antes de una partida local o al repetirla,
nunca por temporizador ni durante una sesión online. SDK_GAME_PAUSE bloquea
entradas, pausa el motor local y silencia sonido; SDK_GAME_START reanuda y
restaura el volumen elegido. Sin SDK disponible se puede seguir jugando.

```bash
flutter pub get
node tool/portal_bridge_test.cjs
flutter build web --release --no-web-resources-cdn --dart-define=ONLINE_SERVER_URL=wss://la-ultima-mano.onrender.com/ws
python3 tool/package_gamemonetize.py --output LaUltimaMano-GameMonetize.zip
```

El ZIP coloca `index.html` en la raíz y usa rutas relativas para funcionar en
el subdirectorio del portal. CanvasKit y las fuentes viajan en el paquete.
Incluye créditos y la licencia de Pixelify. El servidor debe desplegar la
cabecera CORS de `/health` incluida en este cambio para admitir la comprobación
de disponibilidad desde navegadores. El backend continúa alojado en Render;
no se sube un iframe de otra web dentro del juego.

La ficha del juego se prepara en GameMonetize con descripción, controles y tres
portadas JPG (512×384, 512×512 y 512×340). La verificación real de SDK y la
activación se comprueban desde su panel; una compilación aprobada no equivale
a aprobación editorial. El trabajo del portal no incorpora una licencia
general nueva al código heredado.

### Android (APK para pruebas)

El proyecto Android usa el identificador `com.gokuexe.la_ultima_mano`, nombre
«La Última Mano», icono propio y pantalla inicial oscura. Incluye partida local,
Capítulo 01, español/inglés y salas privadas por WSS. Los ajustes y el progreso
se guardan en el directorio privado de la app, obtenido desde Android; no pide
acceso a los archivos del teléfono. Las conexiones sin cifrar no están habilitadas.
El SDK de anuncios de GameMonetize pertenece a la edición web; esta APK no
integra un SDK de publicidad Android.

Con Flutter, Java y el SDK Android instalados:

```bash
flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=ONLINE_SERVER_URL=wss://la-ultima-mano.onrender.com/ws
```

La APK ARM64 está en `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
Para mantener bajo el consumo local se compila una arquitectura por vez, con
dos trabajadores y un heap de Gradle limitado a 2 GiB. Ejecutar las pruebas con
`flutter test --concurrency=1`; no iniciar un emulador mientras se compila. Esta primera
compilación optimizada usa firma de desarrollo para instalar y probar. Antes de
publicarla en Google Play hay que configurar una clave de subida privada y
preparar un AAB; no subir claves ni `key.properties` al repositorio. Las APK
creadas en máquinas distintas pueden usar firmas de desarrollo distintas.
GitHub Actions guarda una APK de prueba en cada ejecución del job Android.

Prueba automatizada en un emulador o teléfono Android de desarrollo:

```bash
flutter test integration_test/android_smoke_test.dart -d DEVICE_ID
# Opcional: probar también el servidor público y cerrar ambas conexiones al terminar.
flutter test integration_test/android_smoke_test.dart -d DEVICE_ID --dart-define=TEST_ONLINE=true --dart-define=ONLINE_SERVER_URL=wss://la-ultima-mano.onrender.com/ws
```

La prueba de integración está preparada para comprobar el guardado privado,
el idioma tras volver a cargar los ajustes, el progreso y la apertura de una
mesa local con lectura ampliada. Requiere un dispositivo Android y se ejecuta
por separado de la compilación; la preparación del test no implica que se haya
probado en un teléfono físico.
La comprobación opcional online crea una sala y conecta dos clientes por TLS.

### Lectura y pantallas pequeñas

La interfaz usa el tamaño real disponible, sin reducir un lienzo fijo de
480×960 ni imponer un tablero de 1.000 píxeles. Respeta las barras del sistema
y los recortes de pantalla. Los botones de turno permanecen visibles; el
contenido adicional se desplaza verticalmente y la mano horizontalmente.

Los textos y números usan Liberation Sans (regular y negrita, SIL OFL incluida)
con un mínimo de 14 píxeles lógicos; las explicaciones usan 16. El título conserva
Pixelify como elemento de marca. Las fuentes viajan dentro de cada compilación,
sin descargarse al abrir el juego. Los números mantienen anchura tabular.
Las cartas y los diálogos se adaptan al tamaño de lectura; las respuestas y los
desenlaces permiten desplazar el contenido con letras grandes.

Las pruebas de regresión montan la app completa en 320×568, 360×640, 390×844 y
412×915, con zonas seguras, ambos idiomas y escala de sistema 1,0 y 1,4.
Comprueban que terminar turno sea pulsable antes de desplazar, y revisan las
20 cartas y sus reversos. Para renderizar capturas sin emulador:

```bash
flutter test tool/render_mobile_preview.dart --concurrency=1 --dart-define=MOBILE_PREVIEW_OUTPUT=/ruta/absoluta/capturas
```

### Diagnóstico de balance reproducible

`tool/balance_audit.dart` ejecuta el motor real y su política actual de bots con
semillas de RNG fijas y temporizadores virtuales. No abre una ventana ni usa un
emulador. Requiere haber ejecutado `flutter pub get`:

```bash
dart run tool/balance_audit.dart 1000 /ruta/absoluta/balance-audit.json
```

Ejecuta 1.000 partidas por escenario: Clásico, Rápido y Farol originales,
Clásico y Rápido de la edición Pulso, más tres
experimentos aislados: Rápido con 3 de lucidez, Rápido con 3 de lucidez y
recambio aleatorio al comenzar con mano llena, y Clásico con ese recambio. El límite es de 400 turnos globales por partida.
Los casos que llegan al límite se informan aparte: no se cuentan como victorias
ni se incluyen en la duración media/mediana de las partidas completadas.
La duración usa turnos, no segundos reales.

Las frecuencias de uso reflejan la heurística de los bots; no son una medida
directa de fuerza de las cartas ni de victorias de jugadores humanos. Los
experimentos con recambio aleatorio no están habilitados en la app ni en el servidor;
la edición Pulso usa el recambio elegido y validado por el motor. También enumera
estados para comprobar la simetría de El reflejo y el alcance numérico de La
otra versión, y reproduce intentos repetidos de salida en Farol, acumulación
de Insomnio e información de La mirilla para bots.

El parámetro opcional `random` de GameEngine permite repetir estas pruebas;
al omitirlo se conserva la generación aleatoria habitual. El chequeo no cambia
el catálogo, los costes ni las reglas de ninguna versión publicada.
