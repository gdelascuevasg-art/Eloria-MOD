# Genera la lista para "Ranged Monster Names" de EloriaBot (Targeting):
# "<bicho> [1]" ... "<bicho> [10]" para cada bicho que ataca A DISTANCIA.
#   python gen_ranged_list.py   -> ranged_monsters_eternum.txt (una sola linea, separada por comas)
#
# De donde salen los bichos:
# - Si existe mods_zalo/monstruos_vistos.txt (lo apunta el mod mientras juegas: nombre,
#   niveles vistos y golpes recibidos a distancia / pegado), se usan los que te han
#   pegado a distancia (MIN_FAR golpes o mas y al menos FAR_RATIO de sus golpes).
# - Si no, la lista fija RANGED de abajo (bichos de distancia de Tibia, con "eternum").
import os

LEVELS = range(1, 11)  # niveles 1 a 10
MIN_FAR, FAR_RATIO = 3, 0.3

RANGED = [
    # distancia (lanzas, flechas, piedras)
    "amazon", "valkyrie", "hunter", "elf scout", "orc spearman", "dwarf soldier",
    "minotaur archer", "goblin scavenger", "goblin assassin", "pirate marauder",
    # magos / hechiceros
    "minotaur mage", "orc shaman", "dwarf geomancer", "elf arcanist", "dark apprentice",
    "dark magician", "necromancer", "priestess", "witch", "ice witch", "warlock",
    "bonelord", "elder bonelord", "lich", "banshee", "serpent spawn", "medusa",
    # dragones y similares (atacan de lejos)
    "dragon", "dragon lord", "frost dragon", "wyvern", "hydra",
]
PREFIX = "eternum"

HERE = os.path.dirname(os.path.abspath(__file__))
SEEN = os.path.join(HERE, '..', 'mods_zalo', 'monstruos_vistos.txt')
OUT = os.path.join(HERE, '..', 'ranged_monsters_eternum.txt')

bases = None
if os.path.exists(SEEN):
    bases = []
    for line in open(SEEN, encoding='utf-8'):
        parts = line.strip().split('|')
        if len(parts) != 4:
            continue
        name, lv, far, near = parts[0], parts[1], int(parts[2]), int(parts[3])
        if far >= MIN_FAR and far >= FAR_RATIO * (far + near):
            bases.append(name)
            print(f"  distancia: {name}  (niveles vistos: {lv or '-'}; golpes lejos {far} / pegado {near})")
    if not bases:
        print("monstruos_vistos.txt aun no tiene bichos de distancia: uso la lista fija")
        bases = None
if bases is None:
    bases = [f"{PREFIX} {m}" for m in RANGED]

names = [f"{b} [{lv}]" for b in sorted(set(bases)) for lv in LEVELS]
text = ", ".join(names)
open(OUT, 'w', encoding='utf-8').write(text)
print(len(set(bases)), "bichos x", len(LEVELS), "niveles =", len(names), "nombres,", len(text), "caracteres")
print("ok", os.path.normpath(OUT))
