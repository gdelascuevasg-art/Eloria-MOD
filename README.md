# Eloria: análisis y automatización

Programa para analizar las cazas de los personajes de Eloria (eloria.pl) y automatizar el cliente.
La estructura del repositorio es la misma que la de la carpeta del cliente
(`%APPDATA%\Eloria Client\EloriaClient\`): cada archivo va en el mismo sitio allí.

## Piezas

| Ruta | Qué hace |
| --- | --- |
| `mods_zalo/datos/zalo_datos.lua` | Recolector. Corre en la consola del cliente (Ctrl+T) y escribe cada 30 s lo que pasa en `mods_zalo/datos/registros/<Personaje>_<fecha>.jsonl`: XP, RAW, kills, nivel, posición, vida y maná, daño recibido por elemento y por monstruo, monstruos en pantalla, muertes, pociones. Solo lee el juego. |
| `mods_zalo/expediciones/expediciones.lua` | Mod de expediciones. **Generado**: no se edita a mano. Ahora también carga el recolector. |
| `tools/gen_expeditions_mod.py` | Generador del mod (`python gen_expeditions_mod.py` dentro de `tools/`). |
| `tools/vigia_clientes.ahk` | AutoHotkey v2. Carga el mod solo en cada cliente que arranca o se reinicia (una vez por proceso). |
| `analisis/eloria.py` | Importa los registros (y los `xp_*.txt` antiguos) a `analisis/eloria.db` y sirve el panel en http://127.0.0.1:8765. Solo usa la biblioteca estándar de Python 3. |
| `analisis/Abrir_panel.bat` | Doble clic = abre el panel. |
| `analisis/zonas.json` | Rectángulos con nombre para agrupar las sesiones por zona. Editable. |

## Uso

1. `tools\vigia_clientes.ahk` en el arranque de Windows (como `CargarMod.ahk`), o pulsar RePag en cada cliente.
2. `analisis\Abrir_panel.bat`. El panel se actualiza solo cada minuto.
3. `python analisis\eloria.py sesiones` imprime las últimas sesiones en la consola.

## Reglas

- Nunca leer ni subir `config.otml`: guarda la cuenta y la contraseña.
- `characterdata\characters\<pj>\helper.json` está en Windows-1252 y el cliente lo reescribe al cerrar: editarlo con el cliente cerrado.
- Tras cambiar el generador: regenerar, comprobar la sintaxis con `luaparser` y `tools/upcount.py`.
