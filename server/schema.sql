-- Esquema de la base de datos del juego "Recaudador del Bosque".
-- SQLite. Se crea automáticamente al iniciar el servidor (ver db.py).

PRAGMA foreign_keys = ON;

-- Cada persona que juega (se identifica por el nombre que escribe en "Nueva partida").
CREATE TABLE IF NOT EXISTS jugadores (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre    TEXT    NOT NULL UNIQUE COLLATE NOCASE,
    creado    TEXT    NOT NULL,
    -- Perfil opcional que el jugador llena en "Nueva partida" (rangos, no datos exactos).
    edad      TEXT,
    sexo      TEXT,
    lugar     TEXT,
    ingresos  TEXT
);

-- Una partida = desde "Nueva partida" hasta terminar el recorrido (o abandonarla).
-- Las columnas de estado se actualizan con cada evento que llega (snapshot más reciente).
CREATE TABLE IF NOT EXISTS partidas (
    id               TEXT    PRIMARY KEY,          -- id generado por el juego
    jugador_id       INTEGER NOT NULL REFERENCES jugadores(id),
    inicio           TEXT    NOT NULL,
    fin              TEXT,
    completada       INTEGER NOT NULL DEFAULT 0,
    nivel_max        INTEGER NOT NULL DEFAULT 0,   -- índice del nivel más avanzado alcanzado
    dinero           INTEGER NOT NULL DEFAULT 0,   -- dinero en mano
    total_recaudado  INTEGER NOT NULL DEFAULT 0,   -- todo lo ganado (impuestos + monedas)
    proteccion       INTEGER NOT NULL DEFAULT 0,
    bellotas         INTEGER NOT NULL DEFAULT 0,
    monedas          INTEGER NOT NULL DEFAULT 0,
    tiempo_seg       REAL    NOT NULL DEFAULT 0,   -- tiempo jugado
    actualizado      TEXT    NOT NULL
);

-- Cada vez que el jugador entra a una zona (Bosque, Desierto...).
CREATE TABLE IF NOT EXISTS niveles_jugados (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    partida_id         TEXT    NOT NULL REFERENCES partidas(id),
    nivel_idx          INTEGER NOT NULL,
    nivel_id           TEXT    NOT NULL,
    nivel_nombre       TEXT    NOT NULL,
    inicio             TEXT    NOT NULL,
    fin                TEXT,
    duracion_seg       REAL,
    dinero_entrada     INTEGER,
    dinero_salida      INTEGER,
    animales_pagaron   INTEGER,
    animales_fallaron  INTEGER,
    bellotas           INTEGER,
    monedas            INTEGER,
    plano              TEXT      -- JSON con la posición de animales, bellotas, plataformas... (para el mapa)
);

-- Objetos recogidos: bellotas doradas y monedas.
CREATE TABLE IF NOT EXISTS coleccionables (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    partida_id  TEXT    NOT NULL REFERENCES partidas(id),
    nivel_id    TEXT,
    tipo        TEXT    NOT NULL,     -- 'bellota' | 'moneda'
    referencia  TEXT,                 -- id de la bellota o valor de la moneda
    valor       INTEGER NOT NULL DEFAULT 0,
    momento     TEXT    NOT NULL
);

-- Bitácora completa: TODO lo que hace el jugador queda aquí.
-- 'datos' es JSON con el detalle de cada tipo de evento.
CREATE TABLE IF NOT EXISTS eventos (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    uid           TEXT    NOT NULL UNIQUE,   -- evita duplicados si el juego reenvía
    partida_id    TEXT    NOT NULL REFERENCES partidas(id),
    tipo          TEXT    NOT NULL,
    nivel_id      TEXT,
    datos         TEXT    NOT NULL DEFAULT '{}',
    momento       TEXT    NOT NULL,
    tiempo_juego  REAL    NOT NULL DEFAULT 0,
    nivel_jugado_id INTEGER,          -- en qué intento de nivel ocurrió
    t_nivel       REAL,               -- segundos desde que empezó ese nivel
    x             REAL,               -- posición del jugador al ocurrir
    z             REAL
);

-- Recorrido del jugador: una posición por segundo en cada intento de nivel (para el mapa).
CREATE TABLE IF NOT EXISTS trayectorias (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    nivel_jugado_id  INTEGER NOT NULL REFERENCES niveles_jugados(id),
    partida_id       TEXT    NOT NULL REFERENCES partidas(id),
    nivel_idx        INTEGER NOT NULL,
    t                REAL    NOT NULL,
    x                REAL    NOT NULL,
    z                REAL    NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_eventos_partida ON eventos(partida_id, id);
CREATE INDEX IF NOT EXISTS ix_eventos_tipo    ON eventos(tipo);
CREATE INDEX IF NOT EXISTS ix_partidas_score  ON partidas(total_recaudado DESC);
CREATE INDEX IF NOT EXISTS ix_niveles_partida ON niveles_jugados(partida_id);
CREATE INDEX IF NOT EXISTS ix_tray_nivel ON trayectorias(nivel_jugado_id, t);
CREATE INDEX IF NOT EXISTS ix_tray_idx ON trayectorias(nivel_idx);
