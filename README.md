# Recaudador del Bosque (prototipo 3D, Godot 4.7.2)

Abrir `project.godot` en Godot y pulsar F5. Controles: WASD mover, Shift correr, Espacio saltar, E hablar, ratón cámara, Esc libera el ratón.

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
