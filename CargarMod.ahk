; =====================================================================
; CargarMod.ahk  (AutoHotkey v2)
; RePag (PgUp) en una ventana del cliente de Eloria = abre la consola
; (Ctrl+T), pega la linea que carga el mod, la ejecuta y cierra la consola.
; No toca nada del cliente: hace lo mismo que harias tu con el teclado.
;
; Uso: entra con el personaje (con la consola CERRADA) y pulsa RePag.
; Solo actua en la ventana activa si su titulo contiene "Eloria".
; Sale un aviso junto al raton para saber que ha funcionado.
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 2
SendMode "Event"          ; teclas de una en una (el cliente no se pierde ninguna)
SetKeyDelay 40, 40

LINEA := 'local f,e=loadstring(g_resources.readFileContents("/mods_zalo/expediciones/expediciones.lua"),"@expediciones") if f then f() else print(e) end'

Aviso(texto) {
    ToolTip texto
    SetTimer () => ToolTip(), -2000
}

; RePag solo se captura con el cliente de Eloria delante; en el resto de
; programas RePag sigue funcionando normal.
#HotIf WinActive("Eloria")
$PgUp:: {
    guardado := ClipboardAll()          ; guardar lo que tuvieras copiado
    A_Clipboard := LINEA
    if !ClipWait(2) {
        Aviso("CargarMod: no se pudo copiar la linea")
        return
    }
    Aviso("CargarMod: cargando el mod...")
    Send "^t"                           ; abrir la consola del cliente
    Sleep 600
    Send "^v"                           ; pegar la linea
    Sleep 300
    Send "{Enter}"                      ; ejecutarla
    Sleep 500
    Send "^t"                           ; cerrar la consola
    Sleep 200
    A_Clipboard := guardado             ; devolver tu portapapeles
}
#HotIf
