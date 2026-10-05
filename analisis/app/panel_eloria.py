"""Panel Eloria como aplicacion de escritorio (ventana propia, sin navegador ni consola).

Se empaqueta con PyInstaller (ver construir_exe.bat). El .exe se deja en analisis\\ junto a
eloria.py y carga ese eloria.py desde disco al arrancar, asi los cambios del programa se
aplican sin tener que volver a crear el .exe.
Cerrar la ventana = cerrar el programa.
"""
import importlib.util
import os
import sys
import threading

# Modulos que usa eloria.py: se importan aqui para que PyInstaller los meta en el .exe.
import bisect, glob, json, re, sqlite3, time, webbrowser, ctypes  # noqa: E401,F401
from collections import Counter, defaultdict  # noqa: F401
from ctypes import wintypes  # noqa: F401
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse  # noqa: F401

import webview

VERSION = "0.1"
TITULO = "Panel Eloria v" + VERSION


def carpeta():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def error(texto):
    ctypes.windll.user32.MessageBoxW(None, texto, TITULO, 0x10)
    sys.exit(1)


def cargar_eloria():
    ruta = os.path.join(carpeta(), "eloria.py")
    if not os.path.exists(ruta):
        error("No encuentro eloria.py en:\n" + carpeta() + "\n\nEl .exe tiene que estar en la carpeta analisis.")
    spec = importlib.util.spec_from_file_location("eloria", ruta)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["eloria"] = mod
    spec.loader.exec_module(mod)
    return mod


def main():
    el = cargar_eloria()
    url = "http://127.0.0.1:%d/" % el.PUERTO
    try:
        srv = ThreadingHTTPServer(("127.0.0.1", el.PUERTO), el.Panel)
    except OSError:
        srv = None  # ya hay un panel abierto: esta ventana usa ese
    if srv:
        try:
            el.importar()
        except Exception as e:
            print("[importar] error:", e)
        threading.Thread(target=el.importar_cada_minuto, daemon=True).start()
        threading.Thread(target=srv.serve_forever, daemon=True).start()
    webview.create_window(TITULO, url, width=1300, height=880, min_size=(900, 600))
    webview.start()
    if srv:
        srv.shutdown()


if __name__ == "__main__":
    main()
