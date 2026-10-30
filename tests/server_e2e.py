"""Prueba de punta a punta del servidor (no toca server/juego.db).
Uso (desde la carpeta del proyecto):  py tests/server_e2e.py
Levanta el servidor en el puerto 8011 con una BD temporal, manda eventos como lo hace el juego
y revisa API, leaderboard y todas las páginas de la web (incluido mapa.js con soporte táctil).
"""
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

SERVER = Path(__file__).resolve().parent.parent / "server"
PORT = 8011
BASE = f"http://127.0.0.1:{PORT}"
fallas = []


def ok(nombre, cond, info=""):
    print(("PASS  " if cond else "FAIL  ") + nombre + ("  " + info if info else ""))
    if not cond:
        fallas.append(nombre)


def get(path):
    with urllib.request.urlopen(BASE + path, timeout=5) as r:
        return r.status, r.read().decode("utf-8")


def post(path, data):
    req = urllib.request.Request(BASE + path, data=json.dumps(data).encode(), method="POST",
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return r.status, json.loads(r.read())


def ev(i, tipo, datos, nivel="forest", t=0.0):
    return {"uid": f"e2e-{i}", "partida_id": "e2e1", "jugador": "Prueba Movil", "tipo": tipo, "nivel": nivel,
            "momento": "2026-10-28T20:00:%02d" % (i % 60), "datos": datos,
            "estado": {"dinero": 50 * i, "total_recaudado": 60 * i, "proteccion": 0, "bellotas": 1, "monedas": i,
                       "tiempo_seg": 10.0 * i, "nivel_idx": 0, "t_nivel": t, "x": 0.0, "z": -float(i)}}


def main():
    tmp = Path(tempfile.mkdtemp()) / "e2e.db"
    env = dict(os.environ, JUEGO_DB=str(tmp), PORT=str(PORT), HOST="127.0.0.1")
    proc = subprocess.Popen([sys.executable, "run.py"], cwd=SERVER, env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(40):
            try:
                get("/api/ping")
                break
            except Exception:
                time.sleep(0.25)
        ok("ping", get("/api/ping")[0] == 200)
        eventos = [
            ev(1, "partida_inicio", {}),
            ev(2, "perfil", {"edad": "18-24", "sexo": "Hombre", "lugar": "Jalisco", "ingresos": "Prefiero no decir"}),
            ev(3, "nivel_inicio", {"nivel_nombre": "Bosque Susurrante", "dinero_entrada": 0,
                                    "plano": {"largo": 80, "ancho": 20}}),
            ev(4, "trayectoria", {"puntos": [[1.0, 0.0, -1.0], [2.0, 0.5, -3.0], [3.0, 1.0, -6.0]]}, t=3.0),
            ev(5, "acertijo", {"animal": "Shiba", "pregunta": "?", "respuesta": "Una nuez", "correcta": True,
                                "intento": 1, "segundos": 4.2}),
            ev(6, "cobro", {"animal": "Shiba", "impuesto": 40, "pagado": 40}),
            ev(7, "moneda", {"valor": 5}),
            ev(8, "nivel_fin", {"nivel_nombre": "Bosque Susurrante", "duracion_seg": 95, "dinero_salida": 45,
                                 "animales_pagaron": 1, "animales_fallaron": 0, "bellotas": 1, "monedas": 1}, t=95),
        ]
        st, r = post("/api/eventos", {"eventos": eventos})
        ok("POST eventos", st == 200, json.dumps(r))
        st, r = post("/api/eventos", {"eventos": eventos})  # reenvío: no debe duplicar
        st, lb = get("/api/leaderboard?criterio=recaudado")
        top = json.loads(lb).get("top", [])
        ok("leaderboard", len(top) == 1 and top[0].get("nombre") == "Prueba Movil", lb[:160])
        for path in ["/", "/jugadores", "/estadisticas", "/audiencia", "/dificultad", "/mapas?nivel=0",
                     "/partidas/e2e1", "/api/estadisticas", "/api/demografia", "/api/dificultad",
                     "/api/actividad", "/api/mapa-calor/0", "/static/mapa.js", "/static/style.css"]:
            try:
                st, body = get(path)
                ok("GET " + path, st == 200, f"{len(body)} bytes")
            except Exception as e:
                ok("GET " + path, False, str(e))
        st, js = get("/static/mapa.js")
        ok("mapa.js con pellizco táctil", "pointercancel" in js and "pellizco" in js)
        st, css = get("/static/style.css")
        ok("touch-action en el mapa", "touch-action: none" in css)
        st, home = get("/")
        ok("viewport móvil", 'name="viewport"' in home)
    finally:
        proc.terminate()
        proc.wait(timeout=10)
    print("RESULT:", "ALL PASS" if not fallas else "FAILURES: " + ", ".join(fallas))
    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
