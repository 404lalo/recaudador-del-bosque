"""Arranca el servidor:  python run.py
Variables opcionales:
    HOST=0.0.0.0  -> para que otras PCs de la red (o la EC2) puedan conectarse
    PORT=8000
"""
import os

import uvicorn

if __name__ == "__main__":
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8000"))
    print(f"\n  Web:  http://{'localhost' if host in ('127.0.0.1', '0.0.0.0') else host}:{port}")
    print(f"  API:  http://localhost:{port}/docs\n")
    uvicorn.run("app:app", host=host, port=port, reload=False)
