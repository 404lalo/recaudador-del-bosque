"""Servidor del juego: API que recibe los eventos de Godot + sitio web para consultarlos.

API (JSON):
    GET  /api/ping                  -> el juego revisa si hay servidor
    POST /api/eventos               -> el juego manda un lote de eventos
    GET  /api/leaderboard           -> top 10 (?criterio=recaudado|tiempo|bellotas)
    GET  /api/jugadores             -> lista de jugadores
    GET  /api/partidas/{id}         -> detalle de una partida
    GET  /api/estadisticas          -> estadísticas generales
Web (HTML):
    /  /jugadores  /jugadores/{id}  /partidas/{id}  /estadisticas
Documentación interactiva de la API: /docs
"""

from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field

import db

BASE_DIR = Path(__file__).resolve().parent

@asynccontextmanager
async def lifespan(_app):
    db.inicializar()  # crea juego.db y las tablas si no existen
    yield


app = FastAPI(
    lifespan=lifespan,
    title="Recaudador del Bosque — API",
    description="Registra todo lo que hace el jugador y sirve el leaderboard.",
    version="1.0",
)
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")
templates = Jinja2Templates(directory=BASE_DIR / "templates")


# ------------------------------------------------------------------ filtros para las plantillas

def _tiempo(seg) -> str:
    seg = int(seg or 0)
    h, resto = divmod(seg, 3600)
    m, s = divmod(resto, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def _fecha(iso) -> str:
    if not iso:
        return "—"
    try:
        dt = datetime.fromisoformat(str(iso)).replace(tzinfo=timezone.utc).astimezone()
        return dt.strftime("%d/%m/%Y %H:%M")
    except ValueError:
        return str(iso)


def _pct(a, b) -> int:
    return round(100 * (a or 0) / b) if b else 0


templates.env.filters["tiempo"] = _tiempo
templates.env.filters["minutos"] = lambda seg: f"{(seg or 0) / 60:.1f} min"
templates.env.filters["fecha"] = _fecha
templates.env.globals["pct"] = _pct
templates.env.globals["NIVELES"] = {  # mismos nombres que Game.LEVELS en game.gd
    0: "Bosque Susurrante", 1: "Desierto Ardiente", 2: "Pantano Brumoso", 3: "Pradera Dorada",
    4: "Bosque Otoñal", 5: "Cañón Rojo", 6: "Tundra Helada", 7: "Cumbre del Rey",
}


# ------------------------------------------------------------------ API

class Evento(BaseModel):
    uid: str
    partida_id: str
    jugador: str = "Jugador"
    tipo: str
    nivel: Optional[str] = None
    momento: Optional[str] = None
    datos: dict[str, Any] = Field(default_factory=dict)
    estado: dict[str, Any] = Field(default_factory=dict)


class LoteEventos(BaseModel):
    eventos: list[Evento]


@app.get("/api/ping", tags=["juego"])
def ping():
    return {"ok": True, "hora": db.ahora()}


@app.post("/api/eventos", tags=["juego"])
def recibir_eventos(lote: LoteEventos):
    return db.guardar_eventos([e.model_dump() for e in lote.eventos])


@app.get("/api/leaderboard", tags=["consultas"])
def api_leaderboard(criterio: str = "recaudado", limite: int = 10):
    return {"criterio": criterio, "top": db.leaderboard(criterio, max(1, min(limite, 100)))}


@app.get("/api/jugadores", tags=["consultas"])
def api_jugadores():
    return db.jugadores()


@app.get("/api/partidas/{partida_id}", tags=["consultas"])
def api_partida(partida_id: str):
    p = db.partida(partida_id)
    if not p:
        raise HTTPException(404, "Partida no encontrada")
    return p


@app.get("/api/estadisticas", tags=["consultas"])
def api_estadisticas():
    return db.estadisticas()


# ------------------------------------------------------------------ Web

@app.get("/", response_class=HTMLResponse, include_in_schema=False)
def web_leaderboard(request: Request, criterio: str = "recaudado"):
    if criterio not in db.CRITERIOS:
        criterio = "recaudado"
    return templates.TemplateResponse(request, "leaderboard.html", {
        "seccion": "leaderboard",
        "criterio": criterio,
        "criterios": {k: v[0] for k, v in db.CRITERIOS.items()},
        "top": db.leaderboard(criterio, 20),
    })


@app.get("/jugadores", response_class=HTMLResponse, include_in_schema=False)
def web_jugadores(request: Request):
    return templates.TemplateResponse(request, "jugadores.html", {
        "seccion": "jugadores", "jugadores": db.jugadores(),
    })


@app.get("/jugadores/{jugador_id}", response_class=HTMLResponse, include_in_schema=False)
def web_jugador(request: Request, jugador_id: int):
    data = db.jugador(jugador_id)
    if not data:
        raise HTTPException(404, "Jugador no encontrado")
    return templates.TemplateResponse(request, "jugador.html", {"seccion": "jugadores", **data})


@app.get("/partidas/{partida_id}", response_class=HTMLResponse, include_in_schema=False)
def web_partida(request: Request, partida_id: str):
    data = db.partida(partida_id)
    if not data:
        raise HTTPException(404, "Partida no encontrada")
    return templates.TemplateResponse(request, "partida.html", {"seccion": "jugadores", **data})


@app.get("/estadisticas", response_class=HTMLResponse, include_in_schema=False)
def web_estadisticas(request: Request):
    return templates.TemplateResponse(request, "estadisticas.html", {
        "seccion": "estadisticas", **db.estadisticas(),
    })


# ------------------------------------------------------------------ audiencia, dificultad y mapas

@app.get("/api/actividad", tags=["consultas"])
def api_actividad(dias: int = 30):
    return db.actividad(max(7, min(dias, 120)))


@app.get("/api/demografia", tags=["consultas"])
def api_demografia():
    return db.demografia()


@app.get("/api/dificultad", tags=["consultas"])
def api_dificultad():
    return db.dificultad()


@app.get("/api/recorridos/{nivel_jugado_id}", tags=["consultas"])
def api_recorrido(nivel_jugado_id: int):
    r = db.recorrido(nivel_jugado_id)
    if not r:
        raise HTTPException(404, "Recorrido no encontrado")
    return r


@app.get("/api/mapa-calor/{nivel_idx}", tags=["consultas"])
def api_mapa_calor(nivel_idx: int):
    return db.mapa_calor(nivel_idx)


@app.get("/audiencia", response_class=HTMLResponse, include_in_schema=False)
def web_audiencia(request: Request, dias: int = 30):
    dias = 14 if dias == 14 else 30
    return templates.TemplateResponse(request, "audiencia.html", {
        "seccion": "audiencia", "dias": dias, "act": db.actividad(dias), "demo": db.demografia(),
    })


METRICAS = {
    "indice": ("Índice de dificultad", "0 a 100, más alto = más difícil"),
    "abandono": ("% de abandono", "intentos que no se terminaron"),
    "acierto": ("% de acierto en acertijos", "más bajo = acertijos más difíciles"),
    "trivia": ("% de acierto con el depredador", "cultura general"),
    "tiempo": ("Tiempo promedio", "minutos para terminar el nivel"),
    "reinicios": ("Reinicios por intento", "veces que reiniciaron la zona"),
}


@app.get("/dificultad", response_class=HTMLResponse, include_in_schema=False)
def web_dificultad(request: Request, m: str = "indice"):
    if m not in METRICAS:
        m = "indice"
    filas = db.dificultad()
    valores = [f[m] for f in filas if f[m] is not None]
    return templates.TemplateResponse(request, "dificultad.html", {
        "seccion": "dificultad", "m": m, "metricas": METRICAS, "filas": filas,
        "maximo": max(valores + [1]),
    })


@app.get("/mapas", response_class=HTMLResponse, include_in_schema=False)
def web_mapas(request: Request, nivel: int = 0):
    nivel = max(0, min(nivel, len(db.NIVELES) - 1))
    return templates.TemplateResponse(request, "mapas.html", {
        "seccion": "mapas", "nivel": nivel, "niveles": db.NIVELES,
        "calor": db.mapa_calor(nivel), "recorridos": db.recorridos_de_nivel(nivel),
    })


@app.get("/recorridos/{nivel_jugado_id}", response_class=HTMLResponse, include_in_schema=False)
def web_recorrido(request: Request, nivel_jugado_id: int):
    r = db.recorrido(nivel_jugado_id)
    if not r:
        raise HTTPException(404, "Recorrido no encontrado")
    return templates.TemplateResponse(request, "recorrido.html", {"seccion": "mapas", **r})
