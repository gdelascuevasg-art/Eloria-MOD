#Requires AutoHotkey v2.0
; Carga la sonda de dungeons (solo lectura) SOLO en el cliente de Trafalgar Law.
; Copia de cargar_mod_nika.ahk + la comprobacion de consola abierta de cargar_lib.ahk
; (oscurecimiento de pantalla) para no escribir nunca la linea en el chat.
; Resultado en tools\cargar_sonda_law.log
SendMode "Event"
SetKeyDelay 40, 40
LINEA := 'local f,e=loadstring(g_resources.readFileContents("/mods_zalo/dungeon/sonda_dungeon.lua"),"@sonda_dungeon") if f then f() else print(e) end'
SetTitleMatchMode "RegEx"
win := "^Eloria - Trafalgar Law$"
ARCHIVO_LOG := A_ScriptDir "\cargar_sonda_law.log"

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
Fin(cerrada ? 0 : 7, cerrada ? "sonda cargada en Trafalgar Law" : "cargada, pero la consola parece seguir abierta")
