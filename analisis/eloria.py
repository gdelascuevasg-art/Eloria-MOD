"""Programa de analisis de Eloria (solo biblioteca estandar de Python 3).

    python eloria.py            importa los datos y abre el panel en http://127.0.0.1:8765
    python eloria.py importar   solo importa (y dice cuanto)
    python eloria.py sesiones   imprime las ultimas sesiones de caza

Lee, desde la carpeta del cliente (la de arriba de esta):
  - mods_zalo/datos/registros/*.jsonl   lo que escribe el recolector zalo_datos.lua
  - xp_*.txt                            logs antiguos del xp_logger (Nika)
y lo guarda en eloria.db (SQLite), junto a este archivo.
Nunca lee config.otml (guarda la cuenta y la contrasena).
"""
import glob
import json
import os
import re
import sqlite3
import sys
import threading
import time
import webbrowser
from collections import Counter, defaultdict
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

AQUI = os.path.dirname(os.path.abspath(__file__))
CLIENTE = os.environ.get("ELORIA_CLIENTE") or os.path.dirname(AQUI)
DB = os.environ.get("ELORIA_DB") or os.path.join(AQUI, "eloria.db")
REGISTROS = os.path.join(CLIENTE, "mods_zalo", "datos", "registros")
ZONAS = os.path.join(AQUI, "zonas.json")
WEB = os.path.join(AQUI, "web")
PUERTO = 8765
LEGACY_PJ = "Nika"          # los xp_*.txt antiguos son todos de Nika
PAUSA_MAX = 300             # mas de 5 min sin kills = otra sesion
TICK = 30

ELEMENTOS = {"0": "physical", "1": "fire", "2": "earth", "3": "energy", "4": "ice",
             "5": "holy", "6": "death", "8": "drown", "9": "lifedrain"}

ESQUEMA = """
CREATE TABLE IF NOT EXISTS archivos (ruta TEXT PRIMARY KEY, lineas INTEGER, mtime REAL);
CREATE TABLE IF NOT EXISTS ticks (
  pj TEXT, t INTEGER, fuente TEXT, nivel INTEGER, exp REAL, raw REAL, xp REAL, kills INTEGER,
  x INTEGER, y INTEGER, z INTEGER, hp INTEGER, mp INTEGER, dout REAL,
  din TEXT, src TEXT, mobs TEXT, PRIMARY KEY (pj, t, fuente));
CREATE TABLE IF NOT EXISTS eventos (pj TEXT, t INTEGER, ev TEXT, datos TEXT, PRIMARY KEY (pj, t, ev, datos));
CREATE INDEX IF NOT EXISTS ticks_t ON ticks (t);
"""


def conectar():
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    con.executescript(ESQUEMA)
    return con


# ------------------------------------------------------------------ importar
def _leer_lineas(ruta):
    with open(ruta, "rb") as f:
        datos = f.read()
    texto = datos.decode("utf-8", errors="replace")
    return [l for l in texto.split("\n") if l.strip()]


def _importar_jsonl(con, ruta, desde):
    lineas = _leer_lineas(ruta)
    nuevas = 0
    # la ultima linea puede estar a medio escribir: solo se cuenta si es JSON valido
    for i, l in enumerate(lineas[desde:], start=desde):
        try:
            d = json.loads(l)
        except ValueError:
            return i, nuevas
        pj, t, ev = d.pop("pj", None), d.pop("t", None), d.pop("ev", None)
        if not pj or t is None:
            continue
        if ev == "tick":
            con.execute(
                "INSERT OR IGNORE INTO ticks VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (pj, t, "recolector", d.get("nivel"), d.get("exp"), d.get("raw", 0), d.get("xp", 0),
                 d.get("kills", 0), d.get("x"), d.get("y"), d.get("z"), d.get("hp"), d.get("mp"),
                 d.get("dout", 0), json.dumps(d.get("din") or {}), json.dumps(d.get("src") or {}),
                 json.dumps(d.get("mobs") or {})))
        else:
            con.execute("INSERT OR IGNORE INTO eventos VALUES (?,?,?,?)",
                        (pj, t, ev, json.dumps(d, sort_keys=True, ensure_ascii=False)))
        nuevas += 1
    return len(lineas), nuevas


def _importar_xp_antiguo(con, ruta):
    """xp_*.txt: seg,raw_acum,final_acum,kills_acum[,nivel,epoch] cada 30 s."""
    filas = []
    for l in _leer_lineas(ruta):
        p = l.strip().split(",")
        try:
            filas.append([float(v) for v in p])
        except ValueError:
            continue
    if not filas:
        return 0
    if len(filas[-1]) >= 6:
        inicio = filas[-1][5] - filas[-1][0]
    else:
        inicio = os.path.getmtime(ruta) - filas[-1][0]
    prev = [0, 0, 0, 0]
    n = 0
    for f in filas:
        seg, raw, xp, kills = f[:4]
        if raw < prev[1] or kills < prev[3]:      # el logger se reinicio dentro del archivo
            prev = [seg, 0, 0, 0]
        t = int(f[5]) if len(f) >= 6 else int(round(inicio + seg))
        nivel = int(f[4]) if len(f) >= 5 and f[4] > 0 else None
        con.execute(
            "INSERT OR IGNORE INTO ticks (pj,t,fuente,nivel,raw,xp,kills,din,src,mobs) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (LEGACY_PJ, t, "xp_logger", nivel, raw - prev[1], xp - prev[2], int(kills - prev[3]), "{}", "{}", "{}"))
        prev = [seg, raw, xp, kills]
        n += 1
    return n


def importar(con=None, verbose=False):
    propia = con is None
    con = con or conectar()
    total = 0
    vistos = {r["ruta"]: (r["lineas"], r["mtime"]) for r in con.execute("SELECT * FROM archivos")}
    for ruta in sorted(glob.glob(os.path.join(REGISTROS, "*.jsonl"))):
        mt = os.path.getmtime(ruta)
        lineas, mt0 = vistos.get(ruta, (0, None))
        if mt0 == mt:
            continue
        hechas, nuevas = _importar_jsonl(con, ruta, lineas or 0)
        con.execute("INSERT OR REPLACE INTO archivos VALUES (?,?,?)", (ruta, hechas, mt))
        total += nuevas
    for ruta in sorted(glob.glob(os.path.join(CLIENTE, "xp_*.txt"))):
        mt = os.path.getmtime(ruta)
        if vistos.get(ruta, (0, None))[1] == mt:
            continue
        n = _importar_xp_antiguo(con, ruta)
        con.execute("INSERT OR REPLACE INTO archivos VALUES (?,?,?)", (ruta, n, mt))
        total += n
    con.commit()
    if verbose:
        print("importadas %d lineas nuevas" % total)
    if propia:
        con.close()
    return total


# ------------------------------------------------------------------ zonas
ZONAS_POR_DEFECTO = [
    {"nombre": "Venomfen / Wildroot", "x": [15435, 15616], "y": [20154, 20266], "z": [0, 0]},
    {"nombre": "Cinderfall Abyss", "x": [15684, 15856], "y": [20374, 20521], "z": [0, 0]},
    {"nombre": "Prismheart Caverns", "x": [15414, 15721], "y": [20277, 20504], "z": [0, 0]},
    {"nombre": "Echo Monolith", "x": [15600, 15780], "y": [13620, 13800], "z": [0, 0]},
    {"nombre": "Eternum (NPC)", "x": [15800, 15880], "y": [19480, 19560], "z": [7, 7]},
]


def cargar_zonas():
    if not os.path.exists(ZONAS):
        with open(ZONAS, "w", encoding="utf-8") as f:
            json.dump(ZONAS_POR_DEFECTO, f, ensure_ascii=False, indent=2)
    with open(ZONAS, encoding="utf-8") as f:
        return json.load(f)


def zona_de(zonas, x, y, z):
    if x is None:
        return "sin posición (log antiguo)"
    for zn in zonas:
        if zn["x"][0] <= x <= zn["x"][1] and zn["y"][0] <= y <= zn["y"][1] and zn["z"][0] <= z <= zn["z"][1]:
            return zn["nombre"]
    return "sector %d,%d,%d" % (x // 128 * 128, y // 128 * 128, z)


# ------------------------------------------------------------------ analisis
def ticks_de(con, pj, desde=0, hasta=None):
    hasta = hasta or int(time.time()) + 3600
    filas = [dict(r) for r in con.execute(
        "SELECT * FROM ticks WHERE pj=? AND t>=? AND t<=? ORDER BY t", (pj, desde, hasta))]
    # si el recolector y el logger antiguo grabaron a la vez, manda el recolector
    rec = [r["t"] for r in filas if r["fuente"] == "recolector"]
    if rec:
        import bisect
        out = []
        for r in filas:
            if r["fuente"] != "recolector":
                i = bisect.bisect_left(rec, r["t"] - 60)
                if i < len(rec) and rec[i] <= r["t"] + 60:
                    continue
            out.append(r)
        filas = out
    return filas


def personajes(con):
    return [r[0] for r in con.execute("SELECT pj FROM ticks UNION SELECT pj FROM eventos ORDER BY 1")]


def sesiones(con, pj, desde=0, hasta=None, zonas=None):
    zonas = zonas if zonas is not None else cargar_zonas()
    ticks = ticks_de(con, pj, desde, hasta)
    muertes = [r["t"] for r in con.execute(
        "SELECT t FROM eventos WHERE pj=? AND ev='death' AND t>=? ORDER BY t", (pj, desde))]
    out, cur = [], None
    for r in ticks:
        if not r["kills"]:
            continue
        if cur and r["t"] - cur["fin"] <= PAUSA_MAX:
            cur["ticks"].append(r)
            cur["fin"] = r["t"]
        else:
            cur = {"ticks": [r], "inicio": r["t"] - TICK, "fin": r["t"]}
            out.append(cur)
    res = []
    for s in out:
        tk = s["ticks"]
        dur = max(s["fin"] - s["inicio"], TICK)
        activo = len(tk) * TICK
        raw = sum(r["raw"] or 0 for r in tk)
        xp = sum(r["xp"] or 0 for r in tk)
        kills = sum(r["kills"] or 0 for r in tk)
        niveles = [r["nivel"] for r in tk if r["nivel"]]
        zn = Counter(zona_de(zonas, r["x"], r["y"], r["z"]) for r in tk).most_common(1)[0][0]
        res.append({
            "pj": pj, "inicio": s["inicio"], "fin": s["fin"], "duracion": dur, "activo": activo,
            "zona": zn, "raw": raw, "xp": xp, "kills": kills,
            "xp_h": xp * 3600 / dur, "raw_h": raw * 3600 / dur, "kills_min": kills * 60 / dur,
            "xp_h_activo": xp * 3600 / activo, "mult": (xp / raw) if raw else None,
            "nivel_ini": niveles[0] if niveles else None, "nivel_fin": niveles[-1] if niveles else None,
            "muertes": sum(1 for m in muertes if s["inicio"] <= m <= s["fin"] + 60),
            "fuente": tk[-1]["fuente"],
        })
    return res


def serie(con, pj, desde, paso=600):
    cubos = defaultdict(lambda: {"raw": 0, "xp": 0, "kills": 0, "nivel": None, "n": 0})
    for r in ticks_de(con, pj, desde):
        c = cubos[r["t"] // paso * paso]
        c["raw"] += r["raw"] or 0
        c["xp"] += r["xp"] or 0
        c["kills"] += r["kills"] or 0
        c["n"] += 1
        if r["nivel"]:
            c["nivel"] = r["nivel"]
    return [{"t": t, "xp_h": c["xp"] * 3600 / paso, "raw_h": c["raw"] * 3600 / paso,
             "kills_min": c["kills"] * 60 / paso, "nivel": c["nivel"]} for t, c in sorted(cubos.items())]


def dano(con, pj, desde, hasta=None):
    el, src, total, hecho = Counter(), Counter(), 0, 0
    for r in ticks_de(con, pj, desde, hasta):
        for k, v in json.loads(r["din"] or "{}").items():
            el[ELEMENTOS.get(k, "tipo " + k)] += v
            total += v
        for k, v in json.loads(r["src"] or "{}").items():
            src[k] += v
        hecho += r["dout"] or 0
    return {"total": total, "hecho": hecho,
            "elementos": [{"nombre": k, "valor": v} for k, v in el.most_common()],
            "origenes": [{"nombre": k, "valor": v} for k, v in src.most_common(15)]}


def resumen(con):
    ahora = int(time.time())
    zonas = cargar_zonas()
    out = []
    for pj in personajes(con):
        ult = con.execute("SELECT * FROM ticks WHERE pj=? ORDER BY t DESC LIMIT 1", (pj,)).fetchone()
        nivel = con.execute("SELECT nivel FROM ticks WHERE pj=? AND nivel IS NOT NULL ORDER BY t DESC LIMIT 1",
                            (pj,)).fetchone()
        ses = sesiones(con, pj, ahora - 86400, zonas=zonas)
        hora = ticks_de(con, pj, ahora - 3600)
        out.append({
            "pj": pj, "ultimo": ult["t"] if ult else None, "nivel": nivel[0] if nivel else None,
            "zona": zona_de(zonas, ult["x"], ult["y"], ult["z"]) if ult else None,
            "xp_h_1h": sum(r["xp"] or 0 for r in hora),
            "raw_h_1h": sum(r["raw"] or 0 for r in hora),
            "xp_24h": sum(s["xp"] for s in ses),
            "caza_24h": sum(s["duracion"] for s in ses),
            "muertes_24h": con.execute("SELECT COUNT(*) FROM eventos WHERE pj=? AND ev='death' AND t>=?",
                                       (pj, ahora - 86400)).fetchone()[0],
        })
    return out


def conclusiones(con, dias=7):
    """Recomendaciones sencillas a partir de las sesiones (solo lectura)."""
    desde = int(time.time()) - dias * 86400
    zonas = cargar_zonas()
    out = []
    for pj in personajes(con):
        ses = [s for s in sesiones(con, pj, desde, zonas=zonas) if s["duracion"] >= 900]
        if not ses:
            continue
        por_zona = defaultdict(lambda: [0, 0, 0])
        for s in ses:
            z = por_zona[s["zona"]]
            z[0] += s["xp"]
            z[1] += s["duracion"]
            z[2] += s["muertes"]
        if len(por_zona) > 1:
            mejor = max(por_zona.items(), key=lambda kv: kv[1][0] / kv[1][1])
            out.append("%s: la zona que más XP/h le da es %s (%s XP/h de media)."
                       % (pj, mejor[0], corto(mejor[1][0] * 3600 / mejor[1][1])))
        muertes = sum(s["muertes"] for s in ses)
        if muertes:
            peor = max(por_zona.items(), key=lambda kv: kv[1][2])
            out.append("%s: %d %s en %d días; la mayoría en %s."
                       % (pj, muertes, "muerte" if muertes == 1 else "muertes", dias, peor[0]))
        caza = sum(s["duracion"] for s in ses)
        activo = sum(s["activo"] for s in ses)
        if caza and activo / caza < 0.85:
            out.append("%s: el %d%% del tiempo de caza pasa sin kills (pausas de hasta 5 min)."
                       % (pj, round(100 - activo * 100 / caza)))
    return out


def corto(n):
    n = float(n or 0)
    for div, suf in ((1e9, "kkk"), (1e6, "kk"), (1e3, "k")):
        if abs(n) >= div:
            return ("%.1f" % (n / div)).rstrip("0").rstrip(".") + suf
    return "%.0f" % n


def ventanas_abiertas():
    """Nombres de las ventanas "Eloria - <Nombre>" abiertas ahora (solo Windows)."""
    if os.name != "nt":
        return []
    import ctypes
    from ctypes import wintypes
    user32 = ctypes.windll.user32
    nombres = []

    def cada(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            largo = user32.GetWindowTextLengthW(hwnd)
            if largo:
                buf = ctypes.create_unicode_buffer(largo + 1)
                user32.GetWindowTextW(hwnd, buf, largo + 1)
                m = re.match(r"^Eloria - (.+)$", buf.value)
                if m:
                    nombres.append(m.group(1).strip())
        return True

    proto = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows(proto(cada), 0)
    return sorted(set(nombres))


def clientes(con):
    """Clientes con los que se puede enlazar el panel: ventanas abiertas y personajes con datos."""
    ahora = int(time.time())
    abiertas = ventanas_abiertas()
    out = []
    for pj in sorted(set(abiertas) | set(personajes(con))):
        ult = con.execute("SELECT MAX(t) FROM ticks WHERE pj=?", (pj,)).fetchone()[0]
        out.append({"pj": pj, "abierto": pj in abiertas, "ultimo": ult,
                    "grabando": bool(ult and ahora - ult < 120)})
    out.sort(key=lambda c: (not c["abierto"], not c["grabando"], c["pj"]))
    return {"clientes": out, "detecta_ventanas": os.name == "nt", "ahora": ahora}


# ------------------------------------------------------------------ servidor
class Panel(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=WEB, **kw)

    def log_message(self, *a):
        pass

    def _json(self, datos, codigo=200):
        cuerpo = json.dumps(datos, ensure_ascii=False).encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(cuerpo)))
        self.end_headers()
        self.wfile.write(cuerpo)

    def do_POST(self):
        if urlparse(self.path).path == "/api/importar":
            with conectar() as con:
                return self._json({"nuevas": importar(con)})
        self.send_error(404)

    def do_GET(self):
        u = urlparse(self.path)
        if not u.path.startswith("/api/"):
            return super().do_GET()
        q = {k: v[0] for k, v in parse_qs(u.query).items()}
        ahora = int(time.time())
        desde = int(q.get("desde") or ahora - float(q.get("horas", 24)) * 3600)
        pj = q.get("pj")
        con = conectar()
        try:
            ruta = u.path[5:]
            if ruta == "resumen":
                return self._json({"personajes": resumen(con), "conclusiones": conclusiones(con),
                                   "ahora": ahora})
            if ruta == "clientes":
                return self._json(clientes(con))
            if ruta == "sesiones":
                lista = []
                for p in ([pj] if pj else personajes(con)):
                    lista += sesiones(con, p, desde)
                lista.sort(key=lambda s: s["inicio"], reverse=True)
                return self._json(lista)
            if ruta == "serie" and pj:
                return self._json(serie(con, pj, desde, int(q.get("paso", 600))))
            if ruta == "dano" and pj:
                return self._json(dano(con, pj, desde, int(q["hasta"]) if q.get("hasta") else None))
            if ruta == "muertes":
                filas = con.execute("SELECT pj,t,datos FROM eventos WHERE ev='death' AND t>=? AND pj LIKE ? ORDER BY t DESC",
                                    (desde, pj or "%")).fetchall()
                zonas = cargar_zonas()
                out = []
                for r in filas:
                    d = json.loads(r["datos"])
                    out.append({"pj": r["pj"], "t": r["t"], "nivel": d.get("nivel"),
                                "zona": zona_de(zonas, d.get("x"), d.get("y"), d.get("z"))})
                return self._json(out)
            if ruta == "buffs":
                filas = con.execute("SELECT pj,t,datos FROM eventos WHERE ev='buff' AND t>=? AND pj LIKE ? ORDER BY t DESC",
                                    (desde, pj or "%")).fetchall()
                return self._json([dict(pj=r["pj"], t=r["t"], **json.loads(r["datos"])) for r in filas])
            self._json({"error": "no existe"}, 404)
        finally:
            con.close()


def importar_cada_minuto():
    while True:
        time.sleep(60)
        try:
            importar()
        except Exception as e:  # el panel sigue aunque un archivo venga roto
            print("[importar] error:", e)


def servir():
    importar(verbose=True)
    threading.Thread(target=importar_cada_minuto, daemon=True).start()
    srv = ThreadingHTTPServer(("127.0.0.1", PUERTO), Panel)
    url = "http://127.0.0.1:%d/" % PUERTO
    print("Panel en", url, "(Ctrl+C para cerrar)")
    if "--sin-navegador" not in sys.argv:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else ""
    if arg == "importar":
        importar(verbose=True)
    elif arg == "sesiones":
        con = conectar()
        importar(con)
        for p in personajes(con):
            for s in sesiones(con, p)[-10:]:
                print("%s  %-14s %-22s %5.1f h  XP/h %8s  RAW/h %7s  kills/min %4.0f  muertes %d" % (
                    time.strftime("%d/%m %H:%M", time.localtime(s["inicio"])), p, s["zona"][:22],
                    s["duracion"] / 3600, corto(s["xp_h"]), corto(s["raw_h"]), s["kills_min"], s["muertes"]))
    else:
        servir()


if __name__ == "__main__":
    main()
