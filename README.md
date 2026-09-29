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

Superar un nivel desbloquea el siguiente. El progreso y los récords se guardan en `user://progreso.cfg`.

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
- **Elementos:** `add_bumper`, `add_spinner`, `add_boost`, `add_jump_pad`, `add_acid`, `add_wind`, `add_goal`.
- **Enemigos:** `add_patroller`, `add_chaser`, `add_piston`, `add_pendulum`, `add_crusher`, `add_barrels`, `add_worm`.

Todas las posiciones de suelo son el centro de la cara superior. Se juega hacia `-z` y hacia `+x`.

## Probar en el PC

Godot 4.7.2 está instalado en `%LOCALAPPDATA%\Programs\Godot`.

- **Jugar.bat**: abre el juego directamente.
  - **Simular la inclinación**: mantén pulsado el botón izquierdo del ratón y arrastra. La distancia al punto donde pulsaste equivale a cuánto inclinas el móvil. Funciona con el mismo código que el sensor real (calibración, zona muerta y sensibilidad).
  - **Flechas del teclado**: control directo, sin simular el sensor.
  - **Esc** o el botón **II** pausan la partida.
- **Abrir editor.bat**: abre el proyecto en el editor de Godot. Dentro, **F5** ejecuta el juego.

Si añades scripts nuevos con `class_name`, abre el proyecto una vez con **Abrir editor.bat** antes de usar **Jugar.bat**, para que Godot los registre.

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

## Icono

El icono se genera por código: `python tools/make_icon.py` crea los SVG en `icon/` y `godot --headless --path . -s res://tools/render_icons.gd` los convierte a PNG. Salen:
- **Android:** el icono clásico de 192 px y el adaptable (fondo, primer plano y versión monocroma).
- **iOS / App Store:** 1024 px, sin transparencias.

Si cambias el diseño, vuelve a ejecutar los dos comandos.

## Carrera Wi‑Fi (multijugador local)

De 2 a 4 jugadores, cada uno con su móvil, conectados a **la misma Wi‑Fi**.

1. Menú → **Carrera Wi‑Fi**. Escribe tu nombre.
2. Uno pulsa **Crear partida** y queda como anfitrión.
3. Los demás verán **"Unirse a …"** en la lista. Si no aparece (algunas redes bloquean la búsqueda), se puede usar **Unirse por IP** con la IP que muestra la sala del anfitrión.
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
- En **Opciones** puedes cambiar la sensibilidad (inclinación máxima), invertir cada eje y mostrar los datos del sensor.
- La inclinación máxima es **automática** mientras no la cambies: 26° en móviles (menos de 7,5") y 20° en tablets. El botón **Auto** vuelve al valor recomendado.
- La respuesta a la inclinación es curva: los primeros grados empujan poco, para tener control fino, y la fuerza crece rápido hasta el máximo. Se ajusta con `response_exponent` en `scripts/marble.gd`.
- Si el móvil no tiene sensor de gravedad, se usa el acelerómetro con un filtro más fuerte contra el temblor de la mano. "Mostrar datos del sensor" indica qué sensor se está usando.
- Para ganar hay que quedarse **3 segundos** sobre el damero de la meta.
