"""Eloria.exe: el panel de analisis en su propia ventana (sin navegador ni consola).

Arranca el servidor de eloria.py en segundo plano y abre una ventana con pywebview.
Al cerrar la ventana se cierra todo. Si ya habia un panel abierto, usa ese.

Construir el .exe (en Windows):  construir_exe.bat
"""
import os
import socket
import sys
import threading
from http.server import ThreadingHTTPServer

import webview

import eloria

# Junto al .exe (o a este archivo) estan web/, zonas.json y eloria.db; el cliente es la carpeta de arriba.
AQUI = os.path.dirname(os.path.abspath(sys.executable if getattr(sys, "frozen", False) else __file__))
eloria.AQUI = AQUI
eloria.CLIENTE = os.environ.get("ELORIA_CLIENTE") or os.path.dirname(AQUI)
eloria.DB = os.environ.get("ELORIA_DB") or os.path.join(AQUI, "eloria.db")
eloria.REGISTROS = os.path.join(eloria.CLIENTE, "mods_zalo", "datos", "registros")
eloria.ZONAS = os.path.join(AQUI, "zonas.json")
eloria.WEB = os.path.join(AQUI, "web")
URL = "http://127.0.0.1:%d/" % eloria.PUERTO


def puerto_ocupado():
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", eloria.PUERTO)) == 0


def arrancar_servidor():
    try:
        eloria.importar()
    except Exception as e:  # el panel abre aunque un archivo venga roto
        print("[importar] error:", e)
    threading.Thread(target=eloria.importar_cada_minuto, daemon=True).start()
    srv = ThreadingHTTPServer(("127.0.0.1", eloria.PUERTO), eloria.Panel)
    threading.Thread(target=srv.serve_forever, daemon=True).start()


def main():
    if not puerto_ocupado():
        arrancar_servidor()
    webview.create_window("Eloria · Análisis", URL, width=1280, height=860, min_size=(900, 600))
    webview.start(private_mode=False)


if __name__ == "__main__":
    main()
