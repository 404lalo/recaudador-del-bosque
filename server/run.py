"""Arranca el servidor:  python run.py
Variables opcionales:
    HOST=0.0.0.0  -> para que el celular u otras PCs de la red (o la EC2) puedan conectarse
    PORT=8000
"""
import os
import socket

import uvicorn


def ip_local() -> str:
    """IP de esta PC en la red WiFi/LAN (la que hay que poner en Ajustes > Servidor del celular)."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))  # no manda nada: solo elige la interfaz de salida
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


if __name__ == "__main__":
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8000"))
    print(f"\n  Web:  http://{'localhost' if host in ('127.0.0.1', '0.0.0.0') else host}:{port}")
    print(f"  API:  http://localhost:{port}/docs")
    if host == "0.0.0.0":
        print(f"  Celular (misma WiFi):  http://{ip_local()}:{port}   <- ponlo en Ajustes > Servidor")
    print()
    uvicorn.run("app:app", host=host, port=port, reload=False)
