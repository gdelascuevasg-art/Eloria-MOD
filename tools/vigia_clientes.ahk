; =====================================================================
; vigia_clientes.ahk  (AutoHotkey v2)
; Vigila las ventanas del cliente de Eloria. Cuando aparece una ventana
; nueva de personaje ("Eloria - <Nombre>") o el cliente se ha reiniciado
; (proceso nuevo), espera a que el personaje este dentro y carga el mod de
; expediciones, que a su vez carga el recolector de datos (zalo_datos.lua).
;
; Hace lo mismo que la tecla RePag de CargarMod.ahk, pero solo y una vez por
; arranque de cada cliente. Si estas usando el teclado o el raton, espera a
; que lleves 3 s sin tocarlos para no meterse en medio.
; Registro: tools\vigia.log
; Ponerlo en el arranque de Windows igual que CargarMod.ahk.
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode "RegEx"
SendMode "Event"
SetKeyDelay 40, 40

LINEA := 'local f,e=loadstring(g_resources.readFileContents("/mods_zalo/expediciones/expediciones.lua"),"@expediciones") if f then f() else print(e) end'
ESPERA_MS := 20000         ; tiempo desde que aparece la ventana hasta cargar
ARCHIVO_LOG := A_ScriptDir "\vigia.log"

cargados := Map()          ; pid -> nombre del personaje ya cargado
vistos := Map()            ; pid -> A_TickCount en que se vio por primera vez

Apunta(texto) {
    try FileAppend FormatTime(, "yyyy-MM-dd HH:mm:ss") " " texto "`n", ARCHIVO_LOG, "UTF-8"
}

Cargar(hwnd, nombre) {
    prev := WinExist("A")
    guardado := ClipboardAll()
    A_Clipboard := LINEA
    if !ClipWait(2)
        return false
    WinActivate hwnd
    if !WinWaitActive(hwnd, , 3) {
        A_Clipboard := guardado
        return false
    }
    Sleep 300
    Send "^t"
    Sleep 700
    Send "^v"
    Sleep 300
    Send "{Enter}"
    Sleep 600
    Send "^t"
    Sleep 300
    A_Clipboard := guardado
    if prev && prev != hwnd
        try WinActivate prev
    return true
}

Revisar() {
    global cargados, vistos
    vivos := Map()
    for hwnd in WinGetList("^Eloria - .+$") {
        try {
            pid := WinGetPID(hwnd)
            titulo := WinGetTitle(hwnd)
        } catch {
            continue
        }
        nombre := RegExReplace(titulo, "^Eloria - ")
        vivos[pid] := true
        ; mismo proceso pero otro personaje = hay que cargar otra vez
        if cargados.Has(pid) && cargados[pid] = nombre
            continue
        if !vistos.Has(pid) || (cargados.Has(pid) && cargados[pid] != nombre) {
            vistos[pid] := A_TickCount
            if cargados.Has(pid)
                cargados.Delete(pid)
            continue
        }
        if A_TickCount - vistos[pid] < ESPERA_MS || A_TimeIdlePhysical < 3000
            continue
        if Cargar(hwnd, nombre) {
            cargados[pid] := nombre
            Apunta("cargado el mod en " nombre " (pid " pid ")")
            TrayTip "Mod cargado en " nombre, "Eloria", "Mute"
        }
    }
    ; olvidar procesos cerrados
    for pid in [cargados*]
        if !vivos.Has(pid)
            cargados.Delete(pid)
    for pid in [vistos*]
        if !vivos.Has(pid)
            vistos.Delete(pid)
}

Apunta("vigia arrancado")
SetTimer Revisar, 5000
