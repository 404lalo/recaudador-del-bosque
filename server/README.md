# Servidor del juego (API + base de datos + web)

Guarda en una base de datos **todo lo que hace el jugador** (tiempos, monedas, bellotas, cobros,
acertijos, depredador, compras…), arma el **leaderboard** y tiene una **web local** para consultarlo.

```
[Godot]  --HTTP/JSON-->  [FastAPI (app.py)]  -->  [SQLite (juego.db)]
                                  |
                          [Web: leaderboard, jugadores, partidas, estadísticas]
```

## Cómo correrlo (Windows)

```powershell
cd server
py -m pip install -r requirements.txt     # solo la primera vez
py run.py
```

En Linux/Mac: `python3 -m pip install -r requirements.txt` y `python3 run.py`.

Luego:

| Qué | Dónde |
|---|---|
| Web (leaderboard, jugadores, estadísticas) | http://localhost:8000 |
| Documentación interactiva de la API | http://localhost:8000/docs |
| Base de datos | `server/juego.db` (se crea sola) |

Con el servidor prendido, abre el juego, dale **Nueva partida**, escribe tu nombre y juega.
Los datos aparecen en la web en unos segundos. Si el servidor está apagado el juego funciona
igual: guarda los eventos y los manda cuando el servidor vuelve.

## Páginas del dashboard

| Página | Qué muestra |
|---|---|
| `/` Leaderboard | Top por recaudado, tiempo y bellotas |
| `/jugadores` | Jugadores, sus partidas y su perfil |
| `/audiencia` | Jugadores por día, mapa de calor día × hora, edad / sexo / lugar / ingresos y su cruce con el desempeño |
| `/dificultad` | Índice de dificultad, % de abandono, % de acierto, tiempo y reinicios por nivel |
| `/mapas` | Mapa de calor de por dónde camina la gente en cada nivel, % de cada bellota encontrada, dónde abandonan |
| `/recorridos/{id}` | Mapa interactivo de un intento: ruta, acciones, animales cobrados, reproductor con barra de tiempo |
| `/estadisticas` | Resumen general |

El perfil (edad, sexo, lugar, ingresos) es **opcional y por rangos**; el jugador lo llena en "Nueva partida".
El mapa usa la posición del jugador cada segundo (tabla `trayectorias`) y el plano de cada nivel
(`niveles_jugados.plano`), que el juego manda al entrar a la zona.

## Datos de prueba para la demo

```powershell
py seed_demo.py                       # crea demo.db con 24 jugadores "Demo ..." (no toca juego.db)
$env:JUEGO_DB="demo.db"; py run.py    # abre la web con esos datos
```
Para volver a los datos reales cierra esa terminal y corre `py run.py` normal.

## Archivos

| Archivo | Para qué |
|---|---|
| `schema.sql` | Tablas de la BD: `jugadores`, `partidas`, `niveles_jugados`, `coleccionables`, `eventos` |
| `db.py` | Conexión a SQLite, guardado de eventos y todas las consultas SQL (leaderboard, estadísticas) |
| `app.py` | Rutas de la API (`/api/...`) y de la web |
| `templates/` | Páginas HTML (Jinja2) |
| `static/style.css` | Estilos de la web |
| `run.py` | Arranca el servidor |

## Qué guarda

Cada acción del juego llega como un **evento** a `POST /api/eventos`:

| Evento | Datos |
|---|---|
| `partida_inicio` | jugador |
| `nivel_inicio` / `nivel_fin` | nivel, duración, dinero al entrar/salir, animales que pagaron/no pagaron, bellotas, monedas |
| `cobro` / `cobro_pospuesto` | animal, impuesto, cuánto pagó |
| `acertijo` | animal, pregunta, respuesta, si fue correcta, intento, segundos en responder |
| `depredador` | pregunta de cultura general, respuesta, si acertó, dinero robado |
| `compra` | protección comprada y costo |
| `moneda` / `bellota` | coleccionable recogido |
| `partida_fin` | terminó el recorrido |

Todos van a la tabla `eventos` (bitácora completa) y además actualizan las tablas resumen
(`partidas`, `niveles_jugados`, `coleccionables`). Cada evento trae un `uid` único, así que si el
juego reenvía algo no se duplica.

## Usarlo desde otra PC o desde la EC2

1. En la máquina servidor: `HOST=0.0.0.0 python3 run.py` (en PowerShell: `$env:HOST="0.0.0.0"; py run.py`)
   y abrir el puerto 8000 (firewall de Windows o Security Group de AWS).
2. En el juego, editar `api_config.cfg` (raíz del proyecto):
   ```
   [api]
   url="http://IP_DEL_SERVIDOR:8000"
   ```

## Ver la BD directamente

Con cualquier visor de SQLite (por ejemplo *DB Browser for SQLite*) abre `server/juego.db`,
o desde Python:

```python
import sqlite3
con = sqlite3.connect("juego.db")
print(con.execute("SELECT nombre, total_recaudado FROM partidas JOIN jugadores ON jugadores.id = jugador_id ORDER BY total_recaudado DESC").fetchall())
```
