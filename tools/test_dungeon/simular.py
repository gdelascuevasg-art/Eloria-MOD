"""Simula una dungeon con el mapa grabado por la sonda y ejecuta dungeon_auto.lua.

Uso: python3 simular.py [casillas.txt] [--modal] [--semilla N]   (por defecto casillas_ejemplo.txt)
Comprueba que el script entra, encuentra los 3 totems, espera a los jefes,
encuentra el boss final y sale. No necesita el juego.
"""
import sys, random, collections, os
from lupa import luajit21 as lupa

AQUI = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(AQUI, '..', '..', 'mods_zalo', 'dungeon', 'dungeon_auto.lua')

args = sys.argv[1:]
casillas = args[0] if args and not args[0].startswith('--') else os.path.join(AQUI, 'casillas_ejemplo.txt')
MODAL = '--modal' in args
seed = int(args[args.index('--semilla') + 1]) if '--semilla' in args else 1
rng = random.Random(seed)

WALK = set()
for l in open(casillas):
    p = l.strip().split(',')
    if len(p) >= 4 and p[2] == '7' and p[3] == '1':
        WALK.add((int(p[0]), int(p[1])))

STATUE = (14232, 19348, 3)
LOBBY = (14232, 19349, 3)
ENTRY = (33703, 1036, 7)

class S: pass
s = S()
s.t = 0.0
s.pos = list(LOBBY)
s.path = []
s.hp = 100
s.texts = []        # (t, text) pendientes
s.modal_open = None
s.creatures = {}    # id -> dict(nombre, pos, hp, tipo)
s.nextid = 1000
s.globals = 0
s.final_spawned = False
s.done = False
s.log = []

def add(nombre, pos, extra=None):
    s.nextid += 1
    d = dict(nombre=nombre, pos=list(pos), hp=100, near=0.0)
    d.update(extra or {})
    s.creatures[s.nextid] = d
    return s.nextid

def setup_dungeon():
    s.creatures.clear()
    add('Ward Totem', (33756, 1043, 7), dict(totem='One Eyed Giant'))
    add('Ward Totem', (33692, 1065, 7), dict(totem='Gravekeeper Zorvath'))
    for q in [(33761, 1061, 7), (33761, 1063, 7), (33766, 1064, 7)]:
        add('Abyssal Rift', q, dict(totem='Elder Wyrm Zygramor', grupo='rift'))
    # algunos monstruos normales repartidos por el camino
    cells = sorted(WALK)
    for _ in range(25):
        x, y = rng.choice(cells)
        add(rng.choice(['Bayle the Dread [27]', 'One Eyed Giant [27]']), (x, y, 7), dict(mob=True))

L = lupa.LuaRuntime(unpack_returned_tuples=True)
G = L.globals()

def cheb(a, b):
    if a[2] != b[2]: return 99999
    return max(abs(a[0]-b[0]), abs(a[1]-b[1]))

def P(t):  # tabla lua -> tupla
    return (int(t['x']), int(t['y']), int(t['z']))

def walkable(x, y, z):
    if z == 7: return (x, y) in WALK
    return (x, y, z) == LOBBY or (z == 3 and abs(x-14232) < 10 and abs(y-19349) < 10 and (x, y, z) != STATUE)

def lt(d): return L.table_from(d)

def get_tile(pos):
    x, y, z = P(pos)
    if z == 7 and (x, y) not in WALK:
        return None
    if z == 3 and (x, y, z) == STATUE:
        return lt({'isWalkable': lambda self, *a: False, 'getTopUseThing': lambda self: lt({'statue': True})})
    w = walkable(x, y, z)
    if not w and z != 7:
        return None
    return lt({'isWalkable': lambda self, *a: w, 'getTopUseThing': lambda self: None})

DIRS = {(0,-1):0,(1,0):1,(0,1):2,(-1,0):3,(1,-1):4,(1,1):5,(-1,1):6,(-1,-1):7}
INV = {v: k for k, v in DIRS.items()}

def find_path(frm, to, *a):
    f, t = P(frm), P(to)
    if f[2] != t[2]: return L.table_from([])
    occupied = {tuple(c['pos'][:2]) for c in s.creatures.values() if not c.get('mob')}
    q = collections.deque([f[:2]]); prev = {f[:2]: None}
    while q:
        c = q.popleft()
        if c == t[:2]: break
        for d in DIRS:
            n = (c[0]+d[0], c[1]+d[1])
            if n not in prev and walkable(n[0], n[1], f[2]) and n not in occupied:
                prev[n] = c; q.append(n)
    if t[:2] not in prev: return L.table_from([])
    out = []; c = t[:2]
    while prev[c] is not None:
        p = prev[c]; out.append(DIRS[(c[0]-p[0], c[1]-p[1])]); c = p
    return L.table_from(list(reversed(out)))

def auto_walk(dirs, *a):
    s.path = [dirs[i] for i in range(1, len(dirs)+1)]
    return True

def game_use(th):
    if th['statue'] and cheb(s.pos, STATUE) <= 1 + 10:
        if MODAL:
            s.modal_open = True
            s.pending_modal = s.t + 0.5
        else:
            s.teleport = s.t + 1.0

def answer_modal(mid, btn, choice):
    s.log.append(f'{s.t:.1f} modal respondido btn={btn} choice={choice}')
    if s.modal_stage == 1:
        s.modal_stage = 2; s.pending_modal = s.t + 0.5
    else:
        s.modal_open = None; s.teleport = s.t + 1.0

s.modal_stage = 1
s.pending_modal = None
s.teleport = None
s.exit_at = None

def creature_obj(cid):
    c = s.creatures[cid]
    return lt({
        'isMonster': lambda self: True,
        'getName': lambda self: c['nombre'],
        'getPosition': lambda self: lt({'x': c['pos'][0], 'y': c['pos'][1], 'z': c['pos'][2]}),
        'getHealthPercent': lambda self: c['hp'],
        'getId': lambda self: cid,
    })

def spectators(pos, *a):
    p = P(pos)
    out = [creature_obj(i) for i, c in s.creatures.items()
           if c['pos'][2] == p[2] and abs(c['pos'][0]-p[0]) <= 8 and abs(c['pos'][1]-p[1]) <= 6]
    return L.table_from(out)

player = lt({
    'getPosition': lambda self: lt({'x': s.pos[0], 'y': s.pos[1], 'z': s.pos[2]}),
    'getName': lambda self: 'Test',
    'getHealthPercent': lambda self: s.hp,
    'autoWalk': lambda self, to: auto_walk(find_path(lt({'x': s.pos[0], 'y': s.pos[1], 'z': s.pos[2]}), to)),
})

handlers = {}
events = []
def connect(obj, t):
    for k, v in t.items(): handlers.setdefault(k, []).append(v)
def disconnect(obj, t):
    for k, v in t.items():
        if v in handlers.get(k, []): handlers[k].remove(v)
def cycle_event(fn, ms):
    events.append([fn, ms / 1000.0, 0.0]); return len(events)
def remove_event(e):
    if e and e <= len(events): events[e-1][0] = None

G.g_clock = lt({'millis': lambda: int(s.t * 1000)})
G.g_game = lt({'isOnline': lambda: True, 'getLocalPlayer': lambda: player,
               'autoWalk': auto_walk, 'stop': lambda: s.path.clear(), 'use': game_use,
               'answerModalDialog': answer_modal})
G.g_map = lt({'getTile': get_tile, 'findPath': find_path, 'getSpectators': spectators})
LOGS = []
G.g_resources = lt({'writeFileContents': lambda f, txt: LOGS.__setitem__(slice(None), [txt])})
G.connect = connect; G.disconnect = disconnect
G.cycleEvent = cycle_event; G.removeEvent = remove_event
G.print = lambda *a: None
G.modules = lt({})

L.execute(open(LUA).read())
DA = G.DungeonAuto

def text(t):
    for h in list(handlers.get('onTextMessage', [])): h(19, t)

def step(dt):
    s.t += dt
    # movimiento: 1 casilla cada 0.15 s
    s.movebudget = getattr(s, 'movebudget', 0) + dt
    while s.path and s.movebudget >= 0.15:
        s.movebudget -= 0.15
        d = INV[s.path.pop(0)]
        n = (s.pos[0]+d[0], s.pos[1]+d[1])
        if walkable(n[0], n[1], s.pos[2]): s.pos[0], s.pos[1] = n
        else: s.path.clear()
    if not s.path: s.movebudget = 0
    if s.pending_modal and s.t >= s.pending_modal:
        s.pending_modal = None
        if s.modal_stage == 1:
            ch = L.table_from([L.table_from([1, 'EldKar [CD: 01:00:00]']), L.table_from([2, 'Random Dungeon'])])
            bt = L.table_from([L.table_from([3, 'Enter']), L.table_from([4, 'Close'])])
            for h in list(handlers.get('onModalDialog', [])): h(7, 'Solo Dungeon System', 'Choose', bt, 3, 4, ch)
        else:
            bt = L.table_from([L.table_from([1, 'Enter Now']), L.table_from([2, 'Cancel'])])
            for h in list(handlers.get('onModalDialog', [])): h(8, 'Confirm Entry', 'Sure?', bt, 1, 2, L.table_from([]))
    if s.teleport and s.t >= s.teleport:
        s.teleport = None; s.pos = list(ENTRY); s.path.clear(); setup_dungeon()
        s.log.append(f'{s.t:.1f} teletransporte a la dungeon')
    # criaturas
    for cid, c in list(s.creatures.items()):
        d = cheb(s.pos, c['pos'])
        if c.get('mob'):
            if d <= 3:
                c['near'] += dt
                c['hp'] = max(0, 100 - int(c['near'] * 40))
                if c['hp'] == 0:
                    del s.creatures[cid]; text(f"You gained 1 experience points for killing {c['nombre'].split(' [')[0]}.")
        elif 'totem' in c:
            if d <= 3:
                c['near'] += dt
                if c['near'] > 6:
                    boss = c['totem']
                    grp = c.get('grupo')
                    for k in [k for k, o in s.creatures.items() if o.get('totem') == boss]:
                        del s.creatures[k]
                    bpos = (33766, 1066, 7) if grp else c['pos']
                    add(boss + ' [127]', bpos, dict(boss=boss))
                    s.log.append(f'{s.t:.1f} sale {boss}')
                    break
        elif 'boss' in c:
            if d <= 4:
                c['near'] += dt
                c['hp'] = max(0, 100 - int(c['near'] * 15))
                if c['hp'] == 0:
                    del s.creatures[cid]
                    text(f"You gained 1 experience points for killing {c['boss']}.")
                    s.log.append(f"{s.t:.1f} muere {c['boss']}")
                    if c['boss'] == 'Eloriak the Blighted':
                        s.exit_at = s.t + 3
                    else:
                        s.globals += 1
                        if s.globals == 3 and not s.final_spawned:
                            s.final_spawned = True
                            add('Eloriak the Blighted [127]', (33731, 1001, 7), dict(boss='Eloriak the Blighted'))
    if s.exit_at and s.t >= s.exit_at:
        s.exit_at = None
        text('{3415|[COMPLETED]} {3003|You escaped the dungeon.}')
        s.pos = list(LOBBY); s.path.clear(); s.done = True
        s.log.append(f'{s.t:.1f} fuera')
    for e in events:
        if e[0] is None: continue
        e[2] += dt
        if e[2] >= e[1]:
            e[2] = 0; e[0]()

DA.start()
last = None
while s.t < 1200:
    step(0.1)
    if DA.estado != last:
        last = DA.estado
    if DA.estado == 'OFF': break

print('\n'.join(s.log))
print('--- log del script (ultimas 60 lineas)')
print('\n'.join(LOGS[0].strip().split('\n')[-60:]) if LOGS else '(vacio)')
print(f'RESULTADO: terminada={s.done} globales={s.globals} tiempo={s.t:.0f}s estado={DA.estado}')
sys.exit(0 if s.done and s.globals == 3 else 1)
