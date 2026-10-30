# Recaudador del Bosque (prototipo 3D, Godot 4.7.2)

Abrir `project.godot` en Godot y pulsar F5. Controles PC: WASD mover, Shift correr, **Q dash**, Espacio saltar, E hablar, ratón cámara, Esc libera el ratón, P pausa, F12 captura. También funciona con **gamepad** y **pantalla táctil** (ver *Soporte móvil*).

- `scripts/game.gd`: autoload con dinero, protección, niveles y **especies** (aquí se cambia el modelo/escala/impuesto/diálogo de cada animal).
- `scripts/level.gd`: construye cada nivel por código (suelo, props, madrigueras, depredador, tienda).
- Los modelos de animales son placeholders (zorro real; el resto sustitutos del pack Ultimate Animated Animals).
- Atajos de desarrollo: `godot --path . scenes/level.tscn -- --desert --z=-20`.

## Audio y plataformas
- `scripts/sfx.gd` (autoload `Sfx`): sonidos y música sintetizados por código (saltos, pasos, monedas, UI, depredador, música por zona + viento). `Sfx.play("coin")`, `Sfx.music("forest")`.
- Jugador: doble salto, coyote time, buffer de salto y salto variable (`scripts/player.gd`).
- `level.gd` → `_build_platforms()`: escaleras de plataformas (alguna móvil) con monedas y una moneda BONUS en la cima; tiras y arcos de monedas en el camino.

## Base de datos, leaderboard y web
- `server/`: servidor en Python (FastAPI + SQLite). Ver `server/README.md`. Para correrlo: `cd server`, `py -m pip install -r requirements.txt` (una vez) y `py run.py`. Web en http://localhost:8000.
- `scripts/api.gd` (autoload `Api`): manda cada acción del jugador al servidor en lotes; si no hay servidor guarda la cola y la reenvía después.
- `api_config.cfg`: URL del servidor (cambiarla si el servidor corre en otra PC o en la EC2).
- Coleccionables: 5 **bellotas doradas** escondidas en las orillas de cada nivel (`level.gd` → `_build_acorns()`), además de las monedas.
- Menú: "Nueva partida" pide el nombre del jugador; botón "Leaderboard" consulta el top 10.
- Pausa: tecla **P** (o Esc para cerrar) en niveles y tutorial → Continuar / Reiniciar zona / Salir al menú (`scripts/pause_menu.gd`). Al salir, la partida queda guardada desde el inicio de la zona.
- Partidas: 3 ranuras de guardado (`Game.MAX_SLOTS` en `game.gd`), cada una con su jugador y progreso (`user://save_slot_N.json`). Menú → "Partidas" para continuar, empezar o borrar; "Continuar" retoma la más reciente.

## Soporte móvil (práctica 6 · rama `practice-6/mobile-support`)

El juego se puede jugar completo en pantalla táctil (Android) sin perder teclado, ratón ni gamepad.

### Capa de entrada unificada
El personaje (`scripts/player.gd`) **solo lee acciones del Input Map**; no sabe qué dispositivo se usa.
Las acciones y sus botones se definen en `scripts/game.gd` → `KEYS`, `PAD_BUTTONS`, `PAD_AXES`.

| Acción | Teclado | Gamepad | Táctil |
|---|---|---|---|
| `move_*` | WASD / flechas | stick izq. / cruceta | joystick virtual (`Input.action_press(acción, fuerza)`) |
| `look_*` | ratón | stick der. | arrastrar el dedo en la mitad derecha |
| `jump` | Espacio | A | botón **SALTAR** (`TouchScreenButton.action`) |
| `dash` | Q | B | botón **DASH** |
| `sprint` | Shift | LB / L3 | joystick empujado a fondo |
| `interact` | E | X | botón **HABLAR** (se ilumina si hay un animal cerca) |
| `pause` | P | Start | botón **II** (arriba a la derecha) |
| `skip_tutorial` | Tab | Back | botón "Saltar tutorial" |

### Controles táctiles (`scripts/touch_controls.gd`, autoload `Touch`)
- Joystick **flotante**: aparece donde cae el pulgar izquierdo; la zona muerta se dibuja como anillo interior.
- **Multitouch**: cada dedo se sigue por su `index` → moverse + saltar/dash + girar la cámara a la vez.
- Se muestran solo si `DisplayServer.is_touchscreen_available()`; se ocultan en diálogos, menús y pausa.
- **Modo depuración en PC**: tecla **F3** o *Ajustes → Controles táctiles → Siempre*. Con
  *Emulate Touch From Mouse* activado, el ratón hace de dedo.
- Ergonomía: joystick en la esquina inferior izquierda, SALTAR (el más grande) en la inferior derecha,
  DASH a su izquierda y HABLAR encima; nada en el centro para no tapar la acción.

### Parámetros usados

| Parámetro | Valor usado | Dónde se cambia |
|---|---|---|
| Radio del joystick | 100 px (× tamaño) | `touch_controls.gd` → `JOY_RADIUS` |
| Zona muerta | 0.20 (ajustable 0 – 0.5) | Ajustes · `Game.deadzone` (Input Map: joystick táctil y sticks) |
| Correr con joystick | ≥ 0.92 de recorrido | `SPRINT_AT` |
| Botón SALTAR | 140 px | `JUMP_SIZE` |
| Botones DASH / HABLAR / pausa | 108 / 108 / 96 px (≥ 96 px ≈ 9 mm) | `ACTION_SIZE`, `PAUSE_SIZE` |
| Tamaño de controles | × 1.0 (ajustable 0.6 – 1.6) | Ajustes · `Game.touch_scale` |
| Opacidad de controles | 0.55 (ajustable 0.2 – 1.0) | Ajustes · `Game.touch_opacity` |
| Margen con el borde | 28 px + safe area | `EDGE`, `Game.safe_margins()` |
| Sensibilidad de cámara táctil | 0.006 rad/px × ajuste | `player.gd` → `TOUCH_LOOK_SENS` |
| Vibración | 15 ms (botón), 30 ms (moneda), 50 ms (cobro/bellota), 30 – 80 ms (daño, según intensidad del shake) | `Game.VIBRATION_MS`, `Game.shake()` |
| Dash | 22 m/s · 0.16 s · cooldown 0.7 s | `player.gd` → `DASH_*` |
| Orientación y stretch | Sensor landscape · `canvas_items` + `expand` · base 1280×720 | Project Settings |

### Game feel con táctil
- **Input buffering y coyote time** funcionan igual porque los botones disparan la acción `jump`
  (probado en `tests/touch_test.gd`).
- **Screenshake** sin cambios; ahora `Game.shake()` también **vibra** (`Input.vibrate_handheld`).
- Vibración en: daño del lobo, acierto/fallo, cobro, monedas, bellotas y dash. Se apaga en Ajustes.

### Ajustes
Menú principal → **Ajustes** (también desde la pausa): modo táctil, opacidad, tamaño, zona muerta,
sensibilidad de cámara, vibración y **URL del servidor** (con botón *Probar*).
Se guardan en `user://settings.cfg`, sección `[controles]` y `[api]`.

### Adaptación de pantalla
- Stretch `canvas_items` + `expand`: la UI escala y en pantallas 20:9 se ensancha en lugar de deformarse.
- HUD, diálogos, tutorial y controles respetan la **safe area** (`DisplayServer.get_display_safe_area()`).
- En táctil los botones de diálogos/menús miden al menos 56 px de alto.

### Jugar en el celular con la base de datos
1. En la PC: `cd server` y `$env:HOST="0.0.0.0"; py run.py`. La consola muestra la IP para el celular.
2. Permitir Python en el Firewall de Windows (red privada) si lo pregunta.
3. En el celular (misma WiFi): Ajustes → Servidor → `http://IP_DE_LA_PC:8000` → **Probar**.
   Sin conexión el juego sigue funcionando y manda los eventos cuando vuelva.

### Exportar a Android (APK)
Preset incluido en `export_presets.cfg` (arm64, landscape, permisos INTERNET y VIBRATE).
1. Godot → *Editor → Manage Export Templates* → **Download and Install** (4.7.2).
2. Instalar **JDK 17** y el **Android SDK** (Android Studio o command-line tools con
   `platform-tools`, `build-tools` y una plataforma).
3. *Editor → Editor Settings → Export → Android*: rutas de **Java SDK** y **Android SDK**
   (el keystore de depuración lo crea Godot).
4. *Project → Export → Android → Export Project* → `exports/4TNature.apk` (o depuración USB con el botón de Android).

### Pruebas automáticas (`tests/`)
- `godot --path . -- --test=touch`: joystick, zona muerta, correr, multitouch, cámara, buffer y coyote con botón táctil, dash.
- `godot --path . --resolution 1600x720 -- --test=shots`: capturas del menú, ajustes y HUD en formato 20:9.
- `py tests/server_e2e.py`: servidor, BD, leaderboard y todas las páginas web con una BD temporal.

### Limitaciones conocidas
- **Web local en el celular**: funciona abriendo `http://IP_DE_LA_PC:8000` en la misma WiFi
  (el servidor debe correr con `HOST=0.0.0.0`). El mapa se mueve con un dedo y hace zoom con pellizco;
  los tooltips aparecen al **tocar** (no hay *hover*). Las tablas anchas se desplazan de lado.
- `127.0.0.1` en el celular es el propio celular: hay que poner la IP de la PC (o la EC2) en Ajustes.
- Vibración: solo Android (en PC no hace nada). No se exporta a iOS (requiere Mac).
- El juego no tiene ataque; el botón de acción es el **dash**.
