"""Genera datos DE PRUEBA en una base aparte (demo.db) para ver el dashboard lleno.

    py seed_demo.py                 -> crea server/demo.db
    $env:JUEGO_DB="demo.db"; py run.py   (PowerShell)   -> abre la web con esos datos

Los jugadores se llaman "Demo ..." para que nunca se confundan con datos reales.
No toca juego.db.
"""
import math
import os
import random
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

BASE = Path(__file__).resolve().parent
os.environ["JUEGO_DB"] = str(BASE / "demo.db")
import db  # noqa: E402  (después de fijar JUEGO_DB)

ANIMALES = {
    "forest": ["Zorro", "Perrito Shiba", "Venado", "Cervatillo", "Ciervo"],
    "desert": ["Burro", "Alpaca", "Caballo", "Potro", "Toro"],
    "swamp": ["Burro", "Vaca", "Ternero", "Zorro", "Venado", "Cervatillo"],
    "meadow": ["Caballo", "Potro", "Vaca", "Ternero", "Burro", "Alpaca"],
    "autumn": ["Venado", "Cervatillo", "Ciervo", "Zorro", "Perrito Shiba", "Husky", "Toro"],
    "canyon": ["Toro", "Burro", "Alpaca", "Caballo", "Zorro", "Perrito Shiba", "Potro"],
    "tundra": ["Husky", "Perro de Trineo", "Yegua Blanca", "Ciervo", "Ciervo Real", "Zorro", "Venado", "Caballo"],
    "summit": ["Ciervo Real", "Yegua Blanca", "Toro", "Perro de Trineo", "Alpaca", "Caballo", "Ciervo", "Vaca"],
}
DIFICULTAD = [0.92, 0.88, 0.75, 0.7, 0.62, 0.5, 0.42, 0.35]  # prob. de acertar por nivel
NOMBRES = ["Ana", "Beto", "Caro", "Dani", "Eli", "Fer", "Gabo", "Hugo", "Iris", "Javi", "Karla", "Leo",
           "Mau", "Nadia", "Omar", "Pau", "Quique", "Rosa", "Santi", "Tere", "Uri", "Vale", "Wendy", "Ximena"]
PERFIL = {
    "edad": (["12–17", "18–24", "25–34", "35–44", "45 o más", "Prefiero no decir"], [3, 9, 5, 2, 1, 1]),
    "sexo": (["Mujer", "Hombre", "Otro", "Prefiero no decir"], [10, 11, 1, 2]),
    "lugar": (["Jalisco", "Ciudad de México", "Nuevo León", "Michoacán", "Guanajuato", "Colima", "Fuera de México"],
              [12, 4, 3, 2, 2, 1, 1]),
    "ingresos": (["Sin ingresos propios", "Menos de $5,000", "$5,000–$10,000", "$10,000–$20,000",
                  "$20,000–$40,000", "Prefiero no decir"], [8, 5, 4, 3, 1, 3]),
}


def plano(nivel_id: str) -> dict:
    n = len(ANIMALES[nivel_id])
    end_z = -(22 + 24 * n + 10)
    animales, plataformas = [], []
    for i, nombre in enumerate(ANIMALES[nivel_id]):
        side = -1 if i % 2 == 0 else 1
        animales.append({"id": nombre.lower(), "nombre": nombre, "x": side * 6.5, "z": -(22 + 24 * i)})
        zc, pside, steps = -(22 + 24 * (i + 0.5)), -side, 3 + i % 3
        z0 = zc + (steps - 1) * 3.4 / 2
        for s in range(steps):
            plataformas.append({"x": pside * 7, "z": z0 - s * 3.4, "w": 2.6, "d": 2.6, "h": 1.3 * (s + 1),
                                "movil": i % 3 == 2 and s == steps - 2})
    bellotas = [{"id": f"{nivel_id}_{i}", "x": (-1 if i % 2 == 0 else 1) * random.uniform(11, 13),
                 "z": -8 - (abs(end_z) - 16) * (i + 0.5) / 5} for i in range(5)]
    return {"start_z": 6, "end_z": end_z, "half": 14, "path_w": 4, "animales": animales,
            "bellotas": bellotas, "plataformas": plataformas,
            "depredador_z": -(22 + 24 * (n - 1) / 2 + 12)}


def simular():
    if Path(db.DB_PATH).exists():
        Path(db.DB_PATH).unlink()
    db.inicializar()
    ahora = datetime.now(timezone.utc)
    for j, nombre in enumerate(NOMBRES):
        jugador = f"Demo {nombre}"
        perfil = {k: random.choices(v[0], v[1])[0] for k, v in PERFIL.items()}
        habilidad = random.uniform(-0.12, 0.1)
        for _ in range(random.choice([1, 1, 2, 2, 3])):
            dia = random.randint(0, 20)
            hora = random.choices(range(24), [1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 9, 8, 6, 4, 2])[0]
            t0 = (ahora - timedelta(days=dia)).replace(hour=hora, minute=random.randint(0, 59)) + timedelta(hours=6)
            pid = uuid.uuid4().hex[:16]
            st = {"dinero": 0, "total_recaudado": 0, "proteccion": 0, "bellotas": 0, "monedas": 0, "tiempo_seg": 0.0,
                  "nivel_idx": 0, "t_nivel": 0, "x": 0, "z": 6}
            evs = []

            def ev(tipo, datos, nivel=None, t=None):
                st["t_nivel"] = round(t or 0, 1)
                evs.append({"uid": uuid.uuid4().hex, "partida_id": pid, "jugador": jugador, "tipo": tipo,
                            "nivel": nivel, "datos": datos, "estado": dict(st),
                            "momento": (t0 + timedelta(seconds=st["tiempo_seg"])).strftime("%Y-%m-%dT%H:%M:%S")})

            ev("partida_inicio", {})
            ev("perfil", perfil)
            completo = True
            for idx, (nid, nnombre) in enumerate(db.NIVELES):
                pl = plano(nid)
                st["nivel_idx"] = idx
                entrada = st["dinero"]
                ev("nivel_inicio", {"nivel_idx": idx, "nivel_nombre": nnombre, "dinero_entrada": entrada, "plano": pl}, nid, 0)
                t, x, z = 0.0, 0.0, 6.0
                puntos, pagaron, fallaron, bell = [], 0, 0, 0
                abandona_en = random.random() < (0.08 + idx * 0.07 - habilidad)
                objetivos = []
                for a in pl["animales"]:
                    objetivos.append(("animal", a))
                for b in pl["bellotas"]:
                    if random.random() < 0.35 + habilidad:
                        objetivos.append(("bellota", b))
                objetivos.sort(key=lambda o: -o[1]["z"])
                objetivos.append(("fin", {"x": 0, "z": pl["end_z"] - 2}))
                pred_hecho = False

                def caminar(tx, tz):
                    nonlocal t, x, z
                    while math.hypot(tx - x, tz - z) > 1.2:
                        d = math.hypot(tx - x, tz - z)
                        paso = random.uniform(5, 9)
                        k = min(1.0, paso / d)
                        x += (tx - x) * k + random.uniform(-0.6, 0.6)
                        z += (tz - z) * k
                        x = max(-13.5, min(13.5, x))
                        t += 1.0
                        puntos.append([round(t, 1), round(x, 2), round(z, 2)])
                        st["x"], st["z"] = x, z

                abandono = False
                for k, (tipo_o, o) in enumerate(objetivos):
                    if abandona_en and tipo_o != "fin" and k >= len(objetivos) // 2:
                        abandono = True
                        break
                    caminar(o["x"] * 0.85, o["z"] + 1.5)
                    if not pred_hecho and z < pl["depredador_z"]:
                        pred_hecho = True
                        ok = random.random() < DIFICULTAD[idx] + 0.05 + habilidad
                        perdida = 0 if ok else int(st["dinero"] * 0.4 * [1, .6, .3, 0][st["proteccion"]])
                        st["dinero"] -= perdida
                        t += 6
                        ev("depredador", {"depredador": "Lobo", "pregunta": "¿?", "respuesta": "…", "correcta": ok,
                                          "perdida": perdida}, nid, t)
                    if tipo_o == "animal":
                        imp = int((20 + idx * 15) * (1 + idx * 0.13))
                        pagado = 0
                        for intento in (1, 2):
                            t += random.uniform(4, 15 + idx * 3)
                            ok = random.random() < DIFICULTAD[idx] + habilidad
                            ev("acertijo", {"animal": o["nombre"], "respuesta": "…", "correcta": ok, "intento": intento,
                                            "segundos": round(random.uniform(3, 12 + idx * 2), 1)}, nid, t)
                            if ok:
                                pagado = imp if intento == 1 else int(imp * 0.5)
                                break
                        st["dinero"] += pagado
                        st["total_recaudado"] += pagado
                        pagaron += 1 if pagado else 0
                        fallaron += 0 if pagado else 1
                        t += 2
                        ev("cobro", {"animal": o["nombre"], "impuesto": imp, "pagado": pagado, "ok": bool(pagado)}, nid, t)
                    elif tipo_o == "bellota":
                        bell += 1
                        st["bellotas"] += 1
                        ev("bellota", {"id": o["id"], "en_nivel": bell, "total_nivel": 5}, nid, t)
                    if random.random() < 0.5:
                        st["monedas"] += 3
                        st["dinero"] += 9
                        st["total_recaudado"] += 9
                    if len(puntos) >= 10:
                        ev("trayectoria", {"puntos": puntos}, nid, t)
                        puntos = []
                st["tiempo_seg"] += t
                if puntos:
                    ev("trayectoria", {"puntos": puntos}, nid, t)
                if abandono:
                    ev("salida_menu", {"nivel_nombre": nnombre, "segundos_en_nivel": t}, nid, t)
                    completo = False
                    break
                ev("nivel_fin", {"nivel_idx": idx, "nivel_nombre": nnombre, "duracion_seg": round(t, 1),
                                 "dinero_entrada": entrada, "dinero_salida": st["dinero"], "animales_pagaron": pagaron,
                                 "animales_fallaron": fallaron, "bellotas": bell, "monedas": 0}, nid, t)
                if st["proteccion"] < 3 and st["dinero"] > [60, 150, 300][st["proteccion"]] and random.random() < 0.4:
                    costo = [60, 150, 300][st["proteccion"]]
                    st["dinero"] -= costo
                    st["proteccion"] += 1
                    ev("compra", {"nombre": ["Silbato de alarma", "Perro guardián", "Escolta armada"][st["proteccion"] - 1],
                                  "costo": costo, "proteccion": st["proteccion"]}, nid, t)
            if completo:
                ev("partida_fin", {"completada": True}, None, 0)
            db.guardar_eventos(evs)
    print("Listo:", db.DB_PATH)


if __name__ == "__main__":
    random.seed(7)
    simular()
