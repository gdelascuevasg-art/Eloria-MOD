#Requires AutoHotkey v2.0
; Dungeon Runner en el cliente de Trafalgar Law (mods_zalo\dungeon\dungeon_auto.lua).
; Uso:  cargar_dungeon_law.ahk empezar   carga el script y hace UNA dungeon
;       cargar_dungeon_law.ahk repetir   carga y repite mientras pueda entrar
;       cargar_dungeon_law.ahk parar     para el Dungeon Runner
; Misma comprobacion de consola abierta que cargar_sonda_law.ahk (oscurecimiento
; de pantalla) para no escribir nunca la linea en el chat.
; Resultado en tools\cargar_dungeon_law.log; lo que hace dentro, en
; mods_zalo\dungeon\auto_Trafalgar Law.log
SendMode "Event"
SetKeyDelay 40, 40
CARGA := 'local f,e=loadstring(g_resources.readFileContents("/mods_zalo/dungeon/dungeon_auto.lua"),"@dungeon_auto") if f then f() else print(e) end'
modo := A_Args.Length ? A_Args[1] : "empezar"
if modo = "parar"
    LINEA := 'if DungeonAuto then DungeonAuto.stop() end'
else if modo = "repetir"
    LINEA := CARGA ' DungeonAuto.start(true)'
else
    LINEA := CARGA ' DungeonAuto.start()'
SetTitleMatchMode "RegEx"
win := "^Eloria - Trafalgar Law$"
ARCHIVO_LOG := A_ScriptDir "\cargar_dungeon_law.log"

Fin(codigo, texto) {
    try FileAppend FormatTime(, "yyyy-MM-dd HH:mm:ss") " " texto "`n", ARCHIVO_LOG, "UTF-8"
    ExitApp codigo
}

BrilloCliente(hwnd) {
    CoordMode "Pixel", "Client"
    WinGetClientPos(, , &w, &h, hwnd)
    total := 0, n := 0
    loop 8 {
        x := Round(w * (0.18 + 0.07 * (A_Index - 1)))
        loop 6 {
            y := Round(h * (0.08 + 0.11 * (A_Index - 1)))
            c := PixelGetColor(x, y)
            total += ((c >> 16) & 0xFF) * 0.299 + ((c >> 8) & 0xFF) * 0.587 + (c & 0xFF) * 0.114
            n++
        }
    }
    return total / n
}

hwnd := WinExist(win)
if !hwnd {
    lista := ""
    for h in WinGetList("^Eloria - ")
        lista .= "[" WinGetTitle(h) "] "
    Fin(2, "no existe la ventana 'Eloria - Trafalgar Law'. Ventanas: " lista)
}
prev := WinExist("A")
guardado := ClipboardAll()
A_Clipboard := LINEA
if !ClipWait(2)
    Fin(4, "no pude usar el portapapeles")
WinActivate hwnd
if !WinWaitActive(hwnd, , 3) {
    A_Clipboard := guardado
    Fin(3, "no pude activar la ventana")
}
Sleep 400
antes := BrilloCliente(hwnd)
if antes < 20 {
    A_Clipboard := guardado
    Fin(5, "pantalla demasiado oscura para comprobar la consola (" Round(antes) ")")
}
Send "^t"
abierta := false
loop 10 {
    Sleep 250
    if BrilloCliente(hwnd) < antes * 0.72 {
        abierta := true
        break
    }
}
if !abierta {
    A_Clipboard := guardado
    Fin(6, "la consola no se abrio (no he pegado nada)")
}
Sleep 250
Send "^v"
Sleep 300
Send "{Enter}"
Sleep 700
Send "^t"
cerrada := false
loop 10 {
    Sleep 250
    if BrilloCliente(hwnd) > antes * 0.85 {
        cerrada := true
        break
    }
}
A_Clipboard := guardado
if prev && prev != hwnd
    try WinActivate prev
Fin(cerrada ? 0 : 7, cerrada ? "dungeon (" modo ") enviado a Trafalgar Law" : "cargada, pero la consola parece seguir abierta")
