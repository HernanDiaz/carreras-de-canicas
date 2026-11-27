# Carreras de Canicas

Juego de canicas en 3D isométrico para Android, hecho con **Godot 4.7**. La canica se controla inclinando el móvil.

## Idiomas

El juego está traducido a 15 idiomas: inglés, español, portugués (Brasil), francés, alemán, italiano, ruso, turco, indonesio, vietnamita, hindi, árabe, japonés, coreano y chino simplificado.

- Se elige solo según el idioma del móvil. Si no está en la lista, se usa el inglés.
- En el menú principal, el botón **Idioma** lo cambia a mano.
- El nombre bajo el icono de Android también se traduce ("Marble Races", "Course de Billes", "ビー玉レース"…). Está en `application/config/name_localized` de `project.godot`.
- **Textos:** todos están en `locale/translations.csv`, una fila por texto y una columna por idioma. Se puede abrir con Excel o LibreOffice (UTF-8). En el código se usan por su clave con `tr("CLAVE")`.
- **Añadir un idioma:** añade una columna con su código (por ejemplo `pl`) y su ruta `res://locale/translations.pl.translation` en `internationalization/locale/translations` de `project.godot`, y añade el código a `LANGUAGES` en `scripts/game_state.gd`.
- Conviene que una persona nativa revise las traducciones antes de publicar.
- **Comprobar** que no falta ninguna: `python tools/check_translations.py` avisa si una clave usada en el código no está en el CSV, si una celda está vacía o si los `%d`/`%.1f` de un idioma no coinciden con el inglés.
- Japonés, chino, coreano, hindi y árabe usan las fuentes del sistema: la fuente del juego solo tiene alfabeto latino. El árabe se muestra de derecha a izquierda, con la interfaz en espejo.

## Estructura

```
project.godot              Configuración (horizontal, renderer Mobile, física Jolt, autoload GameState)
scenes/menu.tscn           Menú principal (escena de inicio)
scenes/game.tscn           Partida: carga el nivel elegido
scenes/marble.tscn         La canica
scenes/environment.tres    Cielo, niebla y brillo (compartido por menú y partida)
scripts/game_state.gd      Autoload: lista de niveles, progreso guardado y opciones
scripts/menu.gd            Portada, selección de nivel y opciones
scripts/game.gd            Cuenta atrás, caídas, meta, pausa y fin de nivel
scripts/level.gd           Clase base Level con todas las piezas, trampas y enemigos
scripts/chaser.gd          Canica de acero enemiga
scripts/marble.gd          Control por inclinación, hielo y plataformas móviles
scripts/ui.gd              Tema visual y paneles de la interfaz
scripts/ghost.gd           Canica fantasma (graba y repite la mejor vuelta)
scripts/game_services.gd   Autoload: clasificaciones y logros de Game Center y Play Games
scripts/audio.gd           Autoload: efectos, música y vibración
sounds/                    Sonidos y músicas (generados con tools/make_sounds.py)
scripts/tilt_simulator.gd  Simula la inclinación con el ratón en el PC
shaders/track.gdshader     Material de las piezas (damero, flechas, franjas, bordes)
levels/level_01.gd ...     Un script por nivel
```

## Niveles

| # | Nombre | Novedad |
|---|--------|---------|
| 1 | Primeros pasos | Rampas, parachoques, puente estrecho, barredora |
| 2 | Hielo resbaladizo | Hielo, plataforma móvil, acelerador |
| 3 | Patrulla | Erizos que patrullan, pistones |
| 4 | Canicas de acero | Canicas enemigas que persiguen, trampillas, barredora doble |
| 5 | Caída libre | Baldosas que se hunden, péndulos, plataforma de salto |
| 6 | Charcos de ácido | Todo lo anterior y charcos de ácido |
| 7 | La fábrica | Cintas transportadoras, prensas, disco giratorio, gusanos, valle, baches, tobogán en espiral |
| 8 | Vendaval | Rachas de viento, balancines, cresta estrecha, laberinto |
| 9 | La gran torre | Barriles rodando, ascensor, torres, medio tubo y meta en un disco giratorio |
| 10 | Montaña rusa | Tobogán de bajada con curvas, trampolín sobre el vacío, catapulta, medio tubo y salto final a la meta |

Un nivel puede llevar un consejo (`tip` en `GameState.LEVELS`, una clave de traducción) que sale con el "¡Ya!" hasta que lo superas por primera vez. Lo llevan los niveles que estrenan un peligro: 2 (hielo), 4 (canicas de acero), 5 (baldosas que se hunden), 6 (ácido), 8 (viento) y 10 (trampolín). En la pausa el consejo sale siempre, debajo del nombre del nivel.

Superar un nivel desbloquea el siguiente. El progreso y los récords se guardan en `user://progreso.cfg`.

**Estrellas:** terminar da 1 estrella; bajar de los dos tiempos de `stars` de cada nivel (en `game_state.gd`) da la 2.ª y la 3.ª.
**Fantasma:** al batir un récord se guarda la vuelta en `user://fantasmas/nivel_N.bin` y en la siguiente partida en solitario corres contra ella (se desactiva en Opciones).
**Clasificaciones mundiales** (`scripts/game_services.gd`): una por nivel, solo partidas en solitario.
- iOS: Game Center, identificadores `level_1_time` … `level_9_time` (App Store Connect, tiempo en centésimas). El plugin GameCenterKit se compila en el workflow de iOS.
- Android: Servicios de Juegos de Google Play (plugin en `addons/GodotPlayGameServices`, exportación con gradle). Game ID `664147782635`; los ID de los marcadores están en `game_services.gd` (tiempo en milésimas).
- En el PC no hacen nada.

**Logros** (`ACHIEVEMENTS` en `scripts/game_services.gd`): primera meta, 3 estrellas en un nivel, mejorar un récord, nivel 5–9 sin perder la canica, meta con menos de 3 s, ganar una carrera Wi‑Fi, todos los niveles y todas las estrellas (se calcula con `GameState.LEVELS`: al añadir un nivel hay que actualizar la descripción en App Store Connect y Play Console). Un nivel sin ID de clasificación en `IOS_IDS`/`ANDROID_IDS` se juega igual, pero no envía tiempos y su tarjeta de Clasificaciones sale desactivada. Se guardan en el progreso y se envían al iniciar sesión (los que ya correspondían por el progreso se conceden solos). En iOS el ID es la clave; en Android, el que da Play Console. Iconos: `python tools/make_achievement_icons.py` → `icon/achievements/`.

**Progreso en la nube**: los récords, los logros y los reinicios del progreso se guardan también en iCloud (iOS, almacén clave-valor) y en los Juegos guardados de Play Juegos (Android, al iniciar sesión). Al abrir el juego se mezclan con los del aparato (el mejor tiempo de cada nivel y todos los logros), así que no se pierde nada al cambiar de móvil o reinstalar. Las opciones y los fantasmas no se suben. Código en `GameState.cloud_data()/merge_cloud()` y `GameServices`.

**Valoración en la tienda**: al superar por primera vez 3 niveles y al terminar los 9 se pide la valoración con la ventana del sistema (iOS y Google Play deciden si la muestran; en TestFlight y en pruebas internas puede no salir). En Android se usa la biblioteca `com.google.android.play:review`, que añade `addons/marble_extras` al exportar, desde GDScript con `JavaClassWrapper`. En iOS, `ios_native/` (clase `IosExtras`) se compila en el workflow junto al plugin de Game Center.

**Sonido:** `python tools/make_sounds.py` genera todos los efectos y las dos músicas por síntesis (sin grabaciones ajenas) en `sounds/`. El sonido de rodar y las músicas se importan con *Loop Mode: Forward*. Música, sonidos y vibración se pueden quitar en Opciones.

## Añadir un nivel

1. Crea `levels/level_10.gd`:

   ```gdscript
   extends Level

   func build() -> void:
       add_start()
       add_ramp(Vector3(0, 0, -3), Vector3(0, -2, -9), 4.0)
       add_platform(Vector3(0, -2, -13), Vector3(8, 2, 8))
       add_goal(Vector3(0, -2, -14))
   ```

2. Añádelo a la lista `LEVELS` de `scripts/game_state.gd` con su nombre y su tiempo límite.

Piezas disponibles en `Level`:
- **Pista:** `add_block`, `add_platform` (con punto de control), `add_ramp`, `add_ice_platform`, `make_icy`, `add_moving_platform`, `add_crumble`, `add_trapdoor`, `add_conveyor`, `add_turntable`, `add_seesaw`, `add_tower`.
- **Terreno:** `add_waves` (baches), `add_valley` (valle en V), `add_chute` y `add_spiral` (toboganes).
- **Elementos:** `add_bumper`, `add_spinner`, `add_boost`, `add_jump_pad`, `add_catapult` (te lanza a un punto con vuelo guiado), `add_acid`, `add_wind`, `add_goal`.
- **Enemigos:** `add_patroller`, `add_chaser`, `add_piston`, `add_pendulum`, `add_crusher`, `add_barrels`, `add_worm`.

Todas las posiciones de suelo son el centro de la cara superior. Se juega hacia `-z` y hacia `+x`.

## Probar en el PC

Godot 4.7.2 está instalado en `%LOCALAPPDATA%\Programs\Godot`.

- **Jugar.bat**: abre el juego directamente.
  - **Simular la inclinación**: mantén pulsado el botón izquierdo del ratón y arrastra. La distancia al punto donde pulsaste equivale a cuánto inclinas el móvil. Funciona con el mismo código que el sensor real (calibración, zona muerta y sensibilidad).
  - **Flechas del teclado o WASD**: control directo, sin simular el sensor.
  - **Esc** o el botón **II** pausan la partida.
  - **R** reinicia el nivel al momento (solo en partida individual).
  - **Mando**: stick izquierdo (analógico: poco stick, poco empuje) o cruceta para mover, **Start** pausa y **Select/Back** reinicia.
- **Abrir editor.bat**: abre el proyecto en el editor de Godot. Dentro, **F5** ejecuta el juego.

Si añades scripts nuevos con `class_name`, abre el proyecto una vez con **Abrir editor.bat** antes de usar **Jugar.bat**, para que Godot los registre.

**Prueba automática de los niveles** (`tools/smoke_test.tscn`): carga cada nivel, espera a la salida y comprueba que la canica se apoya en el suelo y no se cae ni reaparece sola. Además comprueba, sin guardar nada en disco:
- que los paneles (fin de nivel, tiempo agotado) y todas las pantallas del menú caben en 1280x720 en los 15 idiomas;
- los finales (récord, diferencia, siguiente estrella, botones, música más baja) y la pausa (al ir al fondo, al desconectar el mando, Esc para volver);
- el fantasma (grabar, guardar, cargar, descartar archivos rotos), la cámara, el contador, la meta, WASD, el stick analógico, R/mando y Esc en el menú;
- que un archivo guardado o de la nube con datos raros no rompe nada, y que «Continuar» sugiere el nivel correcto.

Escribe `SMOKE OK` o lo que falla:

```
Godot_v4.7.2-stable_win64.exe --headless --path . --fixed-fps 60 res://tools/smoke_test.tscn
```

## Probar en el móvil Android

Ya está todo configurado en este PC:
- **JDK 17** en `D:\Java\jdk-17`.
- **Android SDK** en `D:\AndroidSdk`.
- **Plantillas de Android** de Godot 4.7.2 en `%APPDATA%\Godot\export_templates`.
- **Clave de firma de depuración** en `%APPDATA%\Godot\keystores\debug.keystore`.
- **Preset "Android"** en `export_presets.cfg`, para arm64 (móviles) y x86_64 (emulador).

Pasos:
1. En el móvil, activa las *Opciones de desarrollador* (pulsa 7 veces "Número de compilación" en *Ajustes → Información del teléfono*) y dentro de ellas la *Depuración USB*.
2. Conecta el móvil por cable y acepta el aviso "¿Permitir depuración USB?".
3. Haz doble clic en **Instalar en Android.bat**: compila `build/CarrerasDeCanicas.apk`, lo instala y lo abre en el móvil.

También puedes copiar `build/CarrerasDeCanicas.apk` al móvil e instalarlo a mano; tendrás que permitir la instalación desde "orígenes desconocidos".

**Emulador:** el emulador de Android Studio necesita aceleración gráfica por hardware. Con gráficos por software (SwiftShader) Godot no encuentra Vulkan, pasa a OpenGL y la pantalla se queda en blanco. En el AVD, configura *Graphics: Hardware*.

**Identificador de la app:** `com.hernandiaz.carrerasdecanicas`, el mismo en Android e iOS. Una vez publicada en Google Play o en la App Store, ya no se puede cambiar.

El botón "atrás" de Android pausa la partida y, en el menú, vuelve a la pantalla anterior.

**Qué mirar en el móvil** (la prueba automática no lo puede comprobar en el PC):
- La cámara se adelanta hacia donde ruedas (`lead_time` / `max_lead` en `scripts/camera.gd`): ¿ayuda o marea?
- En los golpes fuertes la cámara tiembla un instante (`max_shake` / `shake_time`): ¿se nota sin molestar?
- La meta perdona botes cortos (`GOAL_GRACE` en `scripts/game.gd`) y vibra suave cada segundo de la cuenta de 3.
- En el nivel 1, la primera vez, sale «inclina el móvil…» y se lee entero.
- Sonidos: los 3 últimos segundos suenan más agudos; la música baja en la pausa y al terminar.
- La canica parpadea al reaparecer y el récord bajo el contador se apaga al pasarlo.
- Con pantallas de 90/120 Hz el juego va a 60 imágenes por segundo: debe verse igual de suave y gastar menos.

## iPhone / iPad (TestFlight, sin Mac)

El juego se compila para iOS en un Mac de GitHub (GitHub Actions) y se sube a **TestFlight**; desde ahí se instala en el iPhone. Para configurarlo (solo la primera vez):

1. **Apple Developer** (99 USD/año): date de alta en developer.apple.com o con la app *Apple Developer* del iPhone.
2. **Crear la app** en [App Store Connect](https://appstoreconnect.apple.com) → *Apps* → **+** → *Nueva app*:
   - Plataforma iOS, nombre "Carreras de Canicas" e idioma principal español.
   - ID de paquete (*Bundle ID*): `com.hernandiaz.carrerasdecanicas`. Si no aparece en la lista, créalo antes en developer.apple.com → *Identifiers* → **+** → *App IDs*.
   - SKU: cualquiera, por ejemplo `carreras-de-canicas`.
3. **Clave de API:** App Store Connect → *Usuarios y acceso* → *Integraciones* → *App Store Connect API* → **+**.
   - Rol **Admin**: lo necesita la firma automática para crear el certificado de distribución.
   - Descarga el archivo `AuthKey_XXXXXXXX.p8`. Solo se puede descargar una vez.
   - Apunta el **Key ID** y el **Issuer ID** que aparecen en esa página.
4. **Team ID:** developer.apple.com → *Account* → *Membership details* → *Team ID* (10 caracteres).
5. **Secretos en GitHub:** en el repositorio, *Settings* → *Secrets and variables* → *Actions* → *New repository secret*. Crea estos cuatro:

   | Nombre | Valor |
   |---|---|
   | `APPLE_TEAM_ID` | el Team ID |
   | `ASC_KEY_ID` | el Key ID |
   | `ASC_ISSUER_ID` | el Issuer ID |
   | `ASC_KEY_P8` | el contenido completo del `.p8` (ábrelo con el Bloc de notas y copia todo, incluidas las líneas `BEGIN`/`END`) |

Para compilar una versión: GitHub → *Actions* → **iOS (TestFlight)** → *Run workflow*. Tarda unos 20 minutos. Cuando termina, aparece en App Store Connect → *TestFlight*. Añádete como probador interno e instálala con la app **TestFlight** del iPhone.

Notas:
- **Minutos de GitHub:** en un repositorio privado, las máquinas Mac gastan minutos del plan x10. El plan gratuito da para unas 10 compilaciones al mes.
- **Búsqueda de partidas en iPhone:** "Unirse a …" necesita que Apple conceda el permiso *multicast* (`com.apple.developer.networking.multicast`), que se pide en developer.apple.com/contact/request/networking-multicast. Mientras tanto funciona **Unirse por IP**. iOS pedirá permiso de "red local" la primera vez.
- **Botón Salir:** en iOS no aparece, porque las apps no pueden cerrarse solas.
- **Ajustes de iOS:** están en el preset "iOS" de `export_presets.cfg`. El Team ID no se guarda en el repositorio: el workflow lo rellena desde el secreto.
- **Derechos (entitlements):** el archivo se compila sin firmar, así que el workflow firma el `.xcarchive` en local con los derechos que genera Godot (Game Center) más iCloud (`com.apple.developer.ubiquity-kvstore-identifier`) antes de exportarlo, y comprueba que el `.ipa` los lleva. La capacidad iCloud del App ID la activa `ios_native/enable_capability.py` con la clave de API.

## Icono

El icono se genera por código: `python tools/make_icon.py` crea los SVG en `icon/` y `godot --headless --path . -s res://tools/render_icons.gd` los convierte a PNG. Salen:
- **Android:** el icono clásico de 192 px y el adaptable (fondo, primer plano y versión monocroma).
- **iOS / App Store:** 1024 px, sin transparencias.

Si cambias el diseño, vuelve a ejecutar los dos comandos.

## Carrera Wi‑Fi (multijugador local)

De 2 a 4 jugadores, cada uno con su móvil, conectados a **la misma Wi‑Fi**.

1. Menú → **Carrera Wi‑Fi**. Escribe tu nombre.
2. Uno pulsa **Crear partida** y queda como anfitrión.
3. Los demás verán **"Unirse a …"** en la lista. Si no aparece (algunas redes bloquean la búsqueda), se puede usar **Unirse por IP** con la IP que muestra la sala del anfitrión (Intro también vale; la última IP usada queda escrita para la próxima vez).
4. El anfitrión elige el nivel con **< >** y pulsa **¡Empezar carrera!**.
5. Gana quien antes aguante 3 s en la meta.
6. Cuando terminas, pasas a **modo espectador**: la cámara sigue a quien sigue corriendo, cambias de jugador con **< >** (o las flechas en el PC) y ves la clasificación en directo.
7. Al final, el anfitrión puede pedir **Revancha**, **Siguiente nivel** o **Volver a la sala**.

**Salir de la sala** pide confirmación (pulsar dos veces) para no salir sin querer.

Cómo funciona:
- Cada móvil simula su canica y envía su posición 20 veces por segundo (puertos UDP 45123 para buscar partidas y 45124 para jugar).
- Las trampas con movimiento van sincronizadas con la salida.
- Las baldosas que se hunden son compartidas: cuando alguien pisa una, cae para todos.
- Las canicas de acero también son compartidas. Las simula el anfitrión, persiguen a la canica de jugador más cercana y los demás las ven por red.
- Las canicas chocan entre sí como bolas de billar: cada móvil calcula el rebote de la suya.
- En carrera no hay pausa: el botón **II** solo permite salir.

Código: `scripts/net.gd` (autoload `Net`: sala, búsqueda y clasificación), `scripts/remote_marble.gd` (canicas de los demás) y el modo carrera de `scripts/game.gd`.

Para jugar desde el PC contra un móvil, Windows puede pedir permiso en el cortafuegos la primera vez que creas o te unes a una partida: acéptalo para **redes privadas**.

## Controles y opciones

- Al empezar cada nivel hay una cuenta atrás. Cuando termina, la posición en la que sostienes el móvil cuenta como "plano". El botón **Recalibrar** vuelve a fijarla, y al salir de la pausa se recalibra sola.
- En **Opciones** puedes cambiar la sensibilidad (inclinación máxima), invertir cada eje, mostrar los datos del sensor y quitar la música, los sonidos, la vibración (también la del mando, si juegas con uno) o el temblor de cámara en los golpes fuertes (por si marea).
- La inclinación máxima es **automática** mientras no la cambies: 26° en móviles (menos de 7,5") y 20° en tablets. El botón **Auto** vuelve al valor recomendado.
- La respuesta a la inclinación es curva: los primeros grados empujan poco, para tener control fino, y la fuerza crece rápido hasta el máximo. Se ajusta con `response_exponent` en `scripts/marble.gd`.
- Si el móvil no tiene sensor de gravedad, se usa el acelerómetro con un filtro más fuerte contra el temblor de la mano. "Mostrar datos del sensor" indica qué sensor se está usando.
- En el móvil, hasta que superas el nivel 1, al salir aparece «inclina el móvil para mover la canica» (en el PC, la pista del ratón y el teclado).
- Para ganar hay que quedarse **3 segundos** sobre el damero de la meta. Un bote corto (menos de 0,25 s fuera) no reinicia la cuenta. Si el tiempo se acaba mientras aguantas en la meta, la cuenta termina igual (descuento); si sales, se acabó.
- Al reaparecer tras una caída, las canicas de acero y los gusanos te dejan en paz 1,5 s (`RESPAWN_PROTECTION` en `scripts/marble.gd`), para que te dé tiempo a apartarte.
- **Pausa** (botón **II**, Esc, Start del mando o atrás de Android; lo mismo la cierra): muestra el nivel, tu récord y el tiempo de la siguiente estrella, y baja la música. Si la app pasa a segundo plano (también durante la cuenta atrás) o se desconecta el mando, se pausa sola.
- Durante la partida, bajo el contador aparece tu **récord** del nivel (se apaga cuando el tiempo lo pasa); en los últimos 10 segundos el contador late y se pone rojo.
- Al reaparecer tras una caída la canica parpadea un momento.
- **Fin de nivel:** la música baja un poco (como en la pausa); tiempo, caídas, diferencia con tu récord anterior (`-0.84` si lo bates, `+1.20` si no) y el tiempo de la siguiente estrella contado desde tu mejor marca. Con 4 botones se colocan en dos columnas para que quepan en el móvil. Si se acaba el tiempo y el siguiente nivel ya estaba desbloqueado, también se ofrece **Siguiente nivel**.
- En el menú, **Esc** o **B** del mando vuelven a la pantalla anterior, como el atrás de Android. En Elegir nivel, las teclas **1-9** abren ese nivel (si está desbloqueado). Con más de 9 niveles, Elegir nivel y Clasificaciones se dividen en páginas de 9 (flechas **< >**, **LB/RB** del mando o **Re Pág/Av Pág**) y se abren en la página del nivel que toca. Cuando una actualización añade niveles, los nuevos salen con la marca **¡Nuevo!** la primera vez que abres Elegir nivel.
- **Continuar** (menú principal): entra directamente en el siguiente nivel por superar (con todos superados, en el primero al que le faltan estrellas). En **Elegir nivel** el foco empieza en ese mismo nivel.
- En el móvil el juego se limita a 60 imágenes por segundo (lo mismo que la física), para no gastar batería de más en pantallas de 90/120 Hz.
- Las opciones se guardan al salir de la pantalla de Opciones de cualquier forma (Volver, atrás de Android o cerrando la app).
