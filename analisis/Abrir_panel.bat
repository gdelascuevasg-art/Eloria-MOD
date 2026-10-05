@echo off
rem Abre el panel de analisis de Eloria (http://127.0.0.1:8765). Cerrar esta ventana = cerrar el panel.
cd /d "%~dp0"
where py >nul 2>nul && (py -3 eloria.py) || (python eloria.py)
pause
