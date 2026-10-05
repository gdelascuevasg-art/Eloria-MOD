#Requires AutoHotkey v2.0
SendMode "Event"
SetKeyDelay 40, 40
LINEA := 'local f,e=loadstring(g_resources.readFileContents("/mods_zalo/xp_logger.lua"),"@xp_logger") if f then f() else print(e) end'
SetTitleMatchMode "RegEx"
win := "^Eloria - Nika$"
if !WinExist(win)
    ExitApp 2
prev := WinExist("A")
guardado := ClipboardAll()
A_Clipboard := LINEA
ClipWait 2
WinActivate win
if !WinWaitActive(win, , 3)
    ExitApp 3
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
if prev
    try WinActivate prev
ExitApp 0
