"""Acceso a la base de datos SQLite: creación del esquema, guardado de eventos y consultas."""

from __future__ import annotations  # compatible con Python 3.9 (Amazon Linux)

import json
import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = Path(os.environ.get("JUEGO_DB", BASE_DIR / "juego.db"))
SCHEMA_PATH = BASE_DIR / "schema.sql"


@contextmanager
def conectar():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys = ON")
    try:
        yield con
        con.commit()
    except Exception:
        con.rollback()
        raise
    finally:
        con.close()


# Columnas que se agregaron después: si la BD ya existía, se añaden sin borrar datos.
_MIGRACIONES = [
    ("jugadores", "edad", "TEXT"), ("jugadores", "sexo", "TEXT"),
    ("jugadores", "lugar", "TEXT"), ("jugadores", "ingresos", "TEXT"),
    ("niveles_jugados", "plano", "TEXT"),
    ("eventos", "nivel_jugado_id", "INTEGER"), ("eventos", "t_nivel", "REAL"),
    ("eventos", "x", "REAL"), ("eventos", "z", "REAL"),
]

# Mismos niveles (y en el mismo orden) que Game.LEVELS en game.gd.
NIVELES = [
    ("forest", "Bosque Susurrante"), ("desert", "Desierto Ardiente"), ("swamp", "Pantano Brumoso"),
    ("meadow", "Pradera Dorada"), ("autumn", "Bosque Otoñal"), ("canyon", "Cañón Rojo"),
    ("tundra", "Tundra Helada"), ("summit", "Cumbre del Rey"),
]


def inicializar() -> None:
    with conectar() as con:
        con.execute("PRAGMA journal_mode = WAL")
        con.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
        for tabla, columna, tipo in _MIGRACIONES:
            existentes = {f["name"] for f in con.execute(f"PRAGMA table_info({tabla})")}
            if columna not in existentes:
                con.execute(f"ALTER TABLE {tabla} ADD COLUMN {columna} {tipo}")
        con.execute("CREATE INDEX IF NOT EXISTS ix_eventos_nj ON eventos(nivel_jugado_id)")


def ahora() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")


# ------------------------------------------------------------------ escritura

def _jugador_id(con, nombre: str) -> int:
    nombre = (nombre or "Jugador").strip()[:40] or "Jugador"
    fila = con.execute("SELECT id FROM jugadores WHERE nombre = ?", (nombre,)).fetchone()
    if fila:
        return fila["id"]
    cur = con.execute("INSERT INTO jugadores (nombre, creado) VALUES (?, ?)", (nombre, ahora()))
    return cur.lastrowid


def _asegurar_partida(con, partida_id: str, jugador_id: int, momento: str) -> None:
    con.execute(
        """INSERT OR IGNORE INTO partidas (id, jugador_id, inicio, actualizado)
           VALUES (?, ?, ?, ?)""",
        (partida_id, jugador_id, momento, momento),
    )


def _actualizar_estado(con, partida_id: str, estado: dict, momento: str) -> None:
    """Guarda el estado más reciente de la partida (dinero, tiempo, bellotas...)."""
    if not estado:
        return
    con.execute(
        """UPDATE partidas SET
               dinero          = ?,
               total_recaudado = MAX(total_recaudado, ?),
               proteccion      = ?,
               bellotas        = MAX(bellotas, ?),
               monedas         = MAX(monedas, ?),
               tiempo_seg      = MAX(tiempo_seg, ?),
               nivel_max       = MAX(nivel_max, ?),
               actualizado     = ?
           WHERE id = ? AND ? >= tiempo_seg""",
        (
            int(estado.get("dinero", 0)),
            int(estado.get("total_recaudado", 0)),
            int(estado.get("proteccion", 0)),
            int(estado.get("bellotas", 0)),
            int(estado.get("monedas", 0)),
            float(estado.get("tiempo_seg", 0)),
            int(estado.get("nivel_idx", 0)),
            momento,
            partida_id,
            float(estado.get("tiempo_seg", 0)),
        ),
    )


def guardar_eventos(eventos: list[dict]) -> dict:
    """Recibe la lista de eventos que manda el juego y los distribuye en las tablas."""
    nuevos = 0
    duplicados = 0
    with conectar() as con:
        for ev in eventos:
            partida_id = str(ev.get("partida_id", "")).strip()
            uid = str(ev.get("uid", "")).strip()
            tipo = str(ev.get("tipo", "")).strip()
            if not partida_id or not uid or not tipo:
                continue
            momento = str(ev.get("momento") or ahora())
            datos = ev.get("datos") or {}
            estado = ev.get("estado") or {}
            nivel_id = ev.get("nivel")

            if con.execute("SELECT 1 FROM eventos WHERE uid = ?", (uid,)).fetchone():
                duplicados += 1  # ya lo teníamos (el juego lo reenvió)
                continue

            jid = _jugador_id(con, ev.get("jugador", ""))
            _asegurar_partida(con, partida_id, jid, momento)

            # Intento de nivel al que pertenece el evento (para el mapa del recorrido).
            if tipo == "nivel_inicio":
                nj_id = _nuevo_nivel_jugado(con, partida_id, nivel_id, datos, momento)
            else:
                nj_id = _nivel_abierto(con, partida_id, nivel_id)

            con.execute(
                """INSERT INTO eventos (uid, partida_id, tipo, nivel_id, datos, momento, tiempo_juego,
                                        nivel_jugado_id, t_nivel, x, z)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (uid, partida_id, tipo, nivel_id,
                 json.dumps({k: v for k, v in datos.items() if k not in ("puntos", "plano")}, ensure_ascii=False),
                 momento, float(estado.get("tiempo_seg", 0)), nj_id,
                 _num(estado.get("t_nivel")), _num(estado.get("x")), _num(estado.get("z"))),
            )
            nuevos += 1
            _actualizar_estado(con, partida_id, estado, momento)
            _efectos_por_tipo(con, partida_id, jid, nj_id, tipo, nivel_id, datos, momento)
    return {"nuevos": nuevos, "duplicados": duplicados}


def _num(v):
    try:
        return None if v is None else float(v)
    except (TypeError, ValueError):
        return None


def _nuevo_nivel_jugado(con, partida_id, nivel_id, datos, momento) -> int:
    plano = datos.get("plano")
    cur = con.execute(
        """INSERT INTO niveles_jugados (partida_id, nivel_idx, nivel_id, nivel_nombre, inicio, dinero_entrada, plano)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (partida_id, int(datos.get("nivel_idx", 0)), nivel_id or "", datos.get("nivel_nombre", nivel_id or ""),
         momento, int(datos.get("dinero_entrada", 0)), json.dumps(plano) if plano else None),
    )
    return cur.lastrowid


def _nivel_abierto(con, partida_id, nivel_id):
    fila = con.execute(
        """SELECT id FROM niveles_jugados WHERE partida_id = ? AND nivel_id = ? AND fin IS NULL
           ORDER BY id DESC LIMIT 1""",
        (partida_id, nivel_id or ""),
    ).fetchone()
    return fila["id"] if fila else None


def _efectos_por_tipo(con, partida_id, jugador_id, nj_id, tipo, nivel_id, datos, momento) -> None:
    if tipo == "perfil":
        con.execute(
            "UPDATE jugadores SET edad = ?, sexo = ?, lugar = ?, ingresos = ? WHERE id = ?",
            tuple(str(datos.get(k) or "Prefiero no decir")[:40] for k in ("edad", "sexo", "lugar", "ingresos"))
            + (jugador_id,),
        )
    elif tipo == "trayectoria" and nj_id:
        idx = con.execute("SELECT nivel_idx FROM niveles_jugados WHERE id = ?", (nj_id,)).fetchone()["nivel_idx"]
        puntos = []
        for p in datos.get("puntos") or []:
            if isinstance(p, (list, tuple)) and len(p) >= 3:
                puntos.append((nj_id, partida_id, idx, float(p[0]), float(p[1]), float(p[2])))
        con.executemany(
            "INSERT INTO trayectorias (nivel_jugado_id, partida_id, nivel_idx, t, x, z) VALUES (?, ?, ?, ?, ?, ?)",
            puntos,
        )
    elif tipo == "nivel_fin":
        fila = {"id": nj_id} if nj_id else None
        if fila:
            con.execute(
                """UPDATE niveles_jugados SET fin = ?, duracion_seg = ?, dinero_salida = ?,
                       animales_pagaron = ?, animales_fallaron = ?, bellotas = ?, monedas = ?
                   WHERE id = ?""",
                (momento, float(datos.get("duracion_seg", 0)), int(datos.get("dinero_salida", 0)),
                 int(datos.get("animales_pagaron", 0)), int(datos.get("animales_fallaron", 0)),
                 int(datos.get("bellotas", 0)), int(datos.get("monedas", 0)), fila["id"]),
            )
    elif tipo in ("bellota", "moneda"):
        con.execute(
            """INSERT INTO coleccionables (partida_id, nivel_id, tipo, referencia, valor, momento)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (partida_id, nivel_id, tipo, str(datos.get("id", "")), int(datos.get("valor", 0)), momento),
        )
    elif tipo == "partida_fin":
        con.execute(
            "UPDATE partidas SET fin = ?, completada = ? WHERE id = ?",
            (momento, 1 if datos.get("completada", True) else 0, partida_id),
        )


# ------------------------------------------------------------------ consultas

CRITERIOS = {
    # clave: (título, ORDER BY, filtro extra)
    "recaudado": ("Más recaudado", "p.total_recaudado DESC, p.tiempo_seg ASC", ""),
    "tiempo": ("Recorrido más rápido", "p.tiempo_seg ASC", "AND p.completada = 1"),
    "bellotas": ("Más bellotas", "p.bellotas DESC, p.tiempo_seg ASC", ""),
}


def leaderboard(criterio: str = "recaudado", limite: int = 10) -> list[dict]:
    _, orden, filtro = CRITERIOS.get(criterio, CRITERIOS["recaudado"])
    with conectar() as con:
        filas = con.execute(
            f"""SELECT p.id, j.id AS jugador_id, j.nombre, p.total_recaudado, p.dinero, p.bellotas,
                       p.monedas, p.tiempo_seg, p.completada, p.nivel_max, p.inicio
                FROM partidas p JOIN jugadores j ON j.id = p.jugador_id
                WHERE p.tiempo_seg > 0 {filtro}
                ORDER BY {orden}
                LIMIT ?""",
            (limite,),
        ).fetchall()
    return [dict(f) for f in filas]


def jugadores() -> list[dict]:
    with conectar() as con:
        filas = con.execute(
            """SELECT j.id, j.nombre, j.creado,
                      COUNT(p.id)                       AS partidas,
                      COALESCE(SUM(p.completada), 0)    AS completadas,
                      COALESCE(MAX(p.total_recaudado),0) AS mejor_recaudado,
                      COALESCE(SUM(p.tiempo_seg), 0)    AS tiempo_total,
                      COALESCE(SUM(p.bellotas), 0)      AS bellotas,
                      MAX(p.actualizado)                AS ultima_vez
               FROM jugadores j LEFT JOIN partidas p ON p.jugador_id = j.id
               GROUP BY j.id ORDER BY ultima_vez DESC"""
        ).fetchall()
    return [dict(f) for f in filas]


def jugador(jugador_id: int) -> dict | None:
    with conectar() as con:
        j = con.execute("SELECT * FROM jugadores WHERE id = ?", (jugador_id,)).fetchone()
        if not j:
            return None
        partidas = con.execute(
            "SELECT * FROM partidas WHERE jugador_id = ? ORDER BY inicio DESC", (jugador_id,)
        ).fetchall()
    return {"jugador": dict(j), "partidas": [dict(p) for p in partidas]}


def partida(partida_id: str) -> dict | None:
    with conectar() as con:
        p = con.execute(
            """SELECT p.*, j.nombre FROM partidas p JOIN jugadores j ON j.id = p.jugador_id
               WHERE p.id = ?""",
            (partida_id,),
        ).fetchone()
        if not p:
            return None
        niveles = con.execute(
            "SELECT * FROM niveles_jugados WHERE partida_id = ? ORDER BY id", (partida_id,)
        ).fetchall()
        eventos = con.execute(
            "SELECT * FROM eventos WHERE partida_id = ? ORDER BY id", (partida_id,)
        ).fetchall()
        colecc = con.execute(
            """SELECT nivel_id, tipo, COUNT(*) AS cantidad, SUM(valor) AS valor
               FROM coleccionables WHERE partida_id = ? GROUP BY nivel_id, tipo""",
            (partida_id,),
        ).fetchall()
    evs = []
    for e in eventos:
        d = dict(e)
        d["datos"] = json.loads(d["datos"] or "{}")
        evs.append(d)
    return {
        "partida": dict(p),
        "niveles": [dict(n) for n in niveles],
        "eventos": evs,
        "coleccionables": [dict(c) for c in colecc],
    }


def estadisticas() -> dict:
    with conectar() as con:
        totales = dict(con.execute(
            """SELECT (SELECT COUNT(*) FROM jugadores)                  AS jugadores,
                      (SELECT COUNT(*) FROM partidas)                   AS partidas,
                      (SELECT COUNT(*) FROM partidas WHERE completada)  AS completadas,
                      (SELECT COUNT(*) FROM eventos)                    AS eventos,
                      (SELECT COALESCE(SUM(tiempo_seg),0) FROM partidas) AS tiempo_total,
                      (SELECT COALESCE(SUM(total_recaudado),0) FROM partidas) AS recaudado_total"""
        ).fetchone())
        acertijos = con.execute(
            """SELECT json_extract(datos, '$.animal')               AS animal,
                      COUNT(*)                                      AS intentos,
                      SUM(json_extract(datos, '$.correcta'))        AS aciertos,
                      AVG(json_extract(datos, '$.segundos'))        AS seg_promedio
               FROM eventos WHERE tipo = 'acertijo'
               GROUP BY animal ORDER BY intentos DESC"""
        ).fetchall()
        cobros = con.execute(
            """SELECT json_extract(datos, '$.animal') AS animal,
                      COUNT(*) AS visitas,
                      SUM(CASE WHEN json_extract(datos, '$.pagado') > 0 THEN 1 ELSE 0 END) AS pagaron,
                      COALESCE(SUM(json_extract(datos, '$.pagado')), 0) AS total
               FROM eventos WHERE tipo = 'cobro'
               GROUP BY animal ORDER BY total DESC"""
        ).fetchall()
        depredador = dict(con.execute(
            """SELECT COUNT(*) AS encuentros,
                      COALESCE(SUM(json_extract(datos, '$.correcta')), 0) AS aciertos,
                      COALESCE(SUM(json_extract(datos, '$.perdida')), 0)  AS robado
               FROM eventos WHERE tipo = 'depredador'"""
        ).fetchone())
        niveles = con.execute(
            """SELECT nivel_nombre, COUNT(*) AS veces,
                      SUM(CASE WHEN fin IS NOT NULL THEN 1 ELSE 0 END) AS terminados,
                      AVG(duracion_seg) AS duracion_prom,
                      AVG(bellotas) AS bellotas_prom,
                      AVG(monedas) AS monedas_prom
               FROM niveles_jugados GROUP BY nivel_idx, nivel_nombre ORDER BY nivel_idx"""
        ).fetchall()
        compras = con.execute(
            """SELECT json_extract(datos, '$.nombre') AS nombre, COUNT(*) AS veces,
                      SUM(json_extract(datos, '$.costo')) AS gastado
               FROM eventos WHERE tipo = 'compra' GROUP BY nombre ORDER BY veces DESC"""
        ).fetchall()
        tipos = con.execute(
            "SELECT tipo, COUNT(*) AS cantidad FROM eventos GROUP BY tipo ORDER BY cantidad DESC"
        ).fetchall()
    return {
        "totales": totales,
        "acertijos": [dict(a) for a in acertijos],
        "cobros": [dict(c) for c in cobros],
        "depredador": depredador,
        "niveles": [dict(n) for n in niveles],
        "compras": [dict(c) for c in compras],
        "tipos": [dict(t) for t in tipos],
    }


# ------------------------------------------------------------------ audiencia (día, hora, perfil)

DIAS_SEMANA = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
CAMPOS_PERFIL = {
    "edad": ["Menos de 12", "12–17", "18–24", "25–34", "35–44", "45 o más", "Prefiero no decir"],
    "sexo": ["Mujer", "Hombre", "Otro", "Prefiero no decir"],
    "ingresos": ["Sin ingresos propios", "Menos de $5,000", "$5,000–$10,000", "$10,000–$20,000",
                 "$20,000–$40,000", "Más de $40,000", "Prefiero no decir"],
}


def _local(iso: str) -> datetime:
    """Las fechas se guardan en UTC; para las gráficas se muestran en la hora local del servidor."""
    return datetime.fromisoformat(iso).replace(tzinfo=timezone.utc).astimezone()


def actividad(dias: int = 30) -> dict:
    with conectar() as con:
        filas = con.execute("SELECT jugador_id, inicio FROM partidas").fetchall()
    hoy = datetime.now().astimezone().date()
    por_dia = {}
    for i in range(dias - 1, -1, -1):
        d = hoy.fromordinal(hoy.toordinal() - i)
        por_dia[d] = {"fecha": d.strftime("%d/%m"), "jugadores": set(), "partidas": 0}
    calor = [[0] * 24 for _ in range(7)]
    for f in filas:
        dt = _local(f["inicio"])
        calor[dt.weekday()][dt.hour] += 1
        if dt.date() in por_dia:
            por_dia[dt.date()]["jugadores"].add(f["jugador_id"])
            por_dia[dt.date()]["partidas"] += 1
    serie = [{"fecha": v["fecha"], "jugadores": len(v["jugadores"]), "partidas": v["partidas"]}
             for v in por_dia.values()]
    por_hora = [sum(calor[d][h] for d in range(7)) for h in range(24)]
    return {
        "serie": serie,
        "max_dia": max([s["jugadores"] for s in serie] + [1]),
        "calor": calor,
        "max_calor": max([max(r) for r in calor] + [1]),
        "dias_semana": DIAS_SEMANA,
        "hora_pico": por_hora.index(max(por_hora)) if any(por_hora) else None,
        "total_partidas": len(filas),
    }


def demografia() -> dict:
    """Distribución de cada dato del perfil y su cruce con el desempeño en el juego."""
    with conectar() as con:
        filas = con.execute(
            """SELECT j.id, COALESCE(j.edad, 'Sin dato') AS edad, COALESCE(j.sexo, 'Sin dato') AS sexo,
                      COALESCE(j.lugar, 'Sin dato') AS lugar, COALESCE(j.ingresos, 'Sin dato') AS ingresos,
                      COUNT(p.id) AS partidas,
                      COALESCE(MAX(p.total_recaudado), 0) AS mejor,
                      COALESCE(MAX(p.nivel_max), 0) AS nivel_max,
                      COALESCE(SUM(p.tiempo_seg), 0) AS tiempo
               FROM jugadores j LEFT JOIN partidas p ON p.jugador_id = j.id
               GROUP BY j.id"""
        ).fetchall()
        aciertos = {r["jugador_id"]: (r["ok"] or 0, r["n"]) for r in con.execute(
            """SELECT p.jugador_id, COUNT(*) AS n, SUM(json_extract(e.datos, '$.correcta')) AS ok
               FROM eventos e JOIN partidas p ON p.id = e.partida_id
               WHERE e.tipo = 'acertijo' GROUP BY p.jugador_id""")}
    resultado = {}
    for campo in ("edad", "sexo", "lugar", "ingresos"):
        grupos = {}
        for f in filas:
            g = grupos.setdefault(f[campo], {"grupo": f[campo], "jugadores": 0, "partidas": 0, "mejor": 0,
                                             "nivel": 0, "tiempo": 0.0, "ok": 0, "n": 0})
            g["jugadores"] += 1
            g["partidas"] += f["partidas"]
            g["mejor"] += f["mejor"]
            g["nivel"] += f["nivel_max"] + (1 if f["partidas"] else 0)
            g["tiempo"] += f["tiempo"]
            ok, n = aciertos.get(f["id"], (0, 0))
            g["ok"] += ok
            g["n"] += n
        lista = []
        for g in grupos.values():
            j = g["jugadores"]
            lista.append({
                "grupo": g["grupo"], "jugadores": j, "partidas": g["partidas"],
                "mejor_prom": round(g["mejor"] / j) if j else 0,
                "nivel_prom": round(g["nivel"] / j, 1) if j else 0,
                "tiempo_prom": g["tiempo"] / j if j else 0,
                "acierto": round(100 * g["ok"] / g["n"]) if g["n"] else None,
            })
        orden = CAMPOS_PERFIL.get(campo)
        if orden:
            lista.sort(key=lambda x: orden.index(x["grupo"]) if x["grupo"] in orden else 99)
        else:
            lista.sort(key=lambda x: -x["jugadores"])
        resultado[campo] = lista
    resultado["total"] = len(filas)
    return resultado


# ------------------------------------------------------------------ dificultad por nivel

def dificultad() -> list[dict]:
    with conectar() as con:
        nj = {r["nivel_idx"]: dict(r) for r in con.execute(
            """SELECT nivel_idx, COUNT(*) AS intentos,
                      SUM(CASE WHEN fin IS NOT NULL THEN 1 ELSE 0 END) AS terminados,
                      AVG(CASE WHEN fin IS NOT NULL THEN duracion_seg END) AS tiempo,
                      COUNT(DISTINCT partida_id) AS partidas
               FROM niveles_jugados GROUP BY nivel_idx""")}
        ev = {}
        for r in con.execute(
            """SELECT n.nivel_idx, e.tipo, COUNT(*) AS n, SUM(json_extract(e.datos, '$.correcta')) AS ok
               FROM eventos e JOIN niveles_jugados n ON n.id = e.nivel_jugado_id
               WHERE e.tipo IN ('acertijo', 'depredador', 'nivel_reinicio', 'salida_menu')
               GROUP BY n.nivel_idx, e.tipo"""):
            ev.setdefault(r["nivel_idx"], {})[r["tipo"]] = (r["n"], r["ok"] or 0)
    filas = []
    for idx, (nid, nombre) in enumerate(NIVELES):
        d = nj.get(idx, {})
        e = ev.get(idx, {})
        intentos = d.get("intentos", 0)
        terminados = d.get("terminados", 0) or 0
        acert_n, acert_ok = e.get("acertijo", (0, 0))
        triv_n, triv_ok = e.get("depredador", (0, 0))
        reinicios = e.get("nivel_reinicio", (0, 0))[0]
        abandono = 100 * (1 - terminados / intentos) if intentos else None
        acierto = 100 * acert_ok / acert_n if acert_n else None
        trivia = 100 * triv_ok / triv_n if triv_n else None
        tiempo = d.get("tiempo")
        indice = None
        if intentos:
            # Índice 0-100: más alto = más difícil.
            indice = round(0.35 * (abandono or 0) + 0.35 * (100 - (acierto if acierto is not None else 100))
                           + 0.15 * (100 - (trivia if trivia is not None else 100))
                           + 0.15 * min(100, 100 * (tiempo or 0) / 600))
        filas.append({
            "idx": idx, "num": f"{idx + 1:02d}", "nivel": nombre, "intentos": intentos,
            "terminados": terminados, "abandono": abandono, "acierto": acierto, "trivia": trivia,
            "tiempo": tiempo, "reinicios": (reinicios / intentos) if intentos else None, "indice": indice,
        })
    return filas


# ------------------------------------------------------------------ mapas

def recorrido(nivel_jugado_id: int) -> dict | None:
    """Todo lo necesario para reproducir un intento de nivel en el mapa interactivo."""
    with conectar() as con:
        n = con.execute(
            """SELECT n.*, j.nombre AS jugador, p.jugador_id FROM niveles_jugados n
               JOIN partidas p ON p.id = n.partida_id JOIN jugadores j ON j.id = p.jugador_id
               WHERE n.id = ?""",
            (nivel_jugado_id,),
        ).fetchone()
        if not n:
            return None
        intento = con.execute(
            "SELECT COUNT(*) FROM niveles_jugados WHERE partida_id = ? AND nivel_idx = ? AND id <= ?",
            (n["partida_id"], n["nivel_idx"], n["id"]),
        ).fetchone()[0]
        puntos = [[r["t"], r["x"], r["z"]] for r in con.execute(
            "SELECT t, x, z FROM trayectorias WHERE nivel_jugado_id = ? ORDER BY t", (nivel_jugado_id,))]
        eventos = []
        for r in con.execute(
            """SELECT tipo, datos, t_nivel, x, z FROM eventos
               WHERE nivel_jugado_id = ? AND tipo NOT IN ('trayectoria', 'pausa') ORDER BY id""",
            (nivel_jugado_id,)):
            eventos.append({"tipo": r["tipo"], "datos": json.loads(r["datos"] or "{}"),
                            "t": r["t_nivel"], "x": r["x"], "z": r["z"]})
    d = dict(n)
    d["plano"] = json.loads(d["plano"]) if d.get("plano") else None
    return {"nivel": d, "intento": intento, "puntos": puntos, "eventos": eventos}


def recorridos_de_nivel(nivel_idx: int, limite: int = 30) -> list[dict]:
    with conectar() as con:
        filas = con.execute(
            """SELECT n.id, n.inicio, n.fin, n.duracion_seg, j.nombre,
                      (SELECT COUNT(*) FROM trayectorias t WHERE t.nivel_jugado_id = n.id) AS puntos
               FROM niveles_jugados n JOIN partidas p ON p.id = n.partida_id
               JOIN jugadores j ON j.id = p.jugador_id
               WHERE n.nivel_idx = ? ORDER BY n.id DESC LIMIT ?""",
            (nivel_idx, limite),
        ).fetchall()
    return [dict(f) for f in filas]


def mapa_calor(nivel_idx: int, celda: float = 2.0) -> dict:
    """Por dónde camina la gente en un nivel (todas las partidas) + qué bellotas se encuentran."""
    with conectar() as con:
        plano_fila = con.execute(
            "SELECT plano FROM niveles_jugados WHERE nivel_idx = ? AND plano IS NOT NULL ORDER BY id DESC LIMIT 1",
            (nivel_idx,),
        ).fetchone()
        celdas = [[r["cx"] * celda, r["cz"] * celda, r["n"]] for r in con.execute(
            """SELECT CAST(round(x / ?) AS INTEGER) AS cx, CAST(round(z / ?) AS INTEGER) AS cz, COUNT(*) AS n
               FROM trayectorias WHERE nivel_idx = ? GROUP BY cx, cz""",
            (celda, celda, nivel_idx))]
        intentos = con.execute("SELECT COUNT(*) FROM niveles_jugados WHERE nivel_idx = ?", (nivel_idx,)).fetchone()[0]
        bellotas = {r["referencia"]: r["n"] for r in con.execute(
            """SELECT c.referencia, COUNT(DISTINCT c.partida_id || '-' || c.momento) AS n
               FROM coleccionables c JOIN niveles_jugados n ON n.partida_id = c.partida_id AND n.nivel_id = c.nivel_id
               WHERE c.tipo = 'bellota' AND n.nivel_idx = ? GROUP BY c.referencia""",
            (nivel_idx,))}
        # Dónde se quedaron los que no terminaron (último punto de cada intento sin fin).
        abandonos = [[r["x"], r["z"]] for r in con.execute(
            """SELECT t.x, t.z FROM trayectorias t JOIN niveles_jugados n ON n.id = t.nivel_jugado_id
               WHERE n.nivel_idx = ? AND n.fin IS NULL
                 AND t.t = (SELECT MAX(t2.t) FROM trayectorias t2 WHERE t2.nivel_jugado_id = n.id)""",
            (nivel_idx,))]
    return {
        "plano": json.loads(plano_fila["plano"]) if plano_fila else None,
        "celdas": celdas, "celda": celda, "intentos": intentos,
        "bellotas": bellotas, "abandonos": abandonos,
        "max": max([c[2] for c in celdas] + [1]),
    }
