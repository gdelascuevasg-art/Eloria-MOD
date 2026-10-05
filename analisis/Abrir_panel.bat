@echo off
rem Abre el panel de analisis de Eloria en una ventana de Brave tipo aplicacion.
rem Esta ventana (minimizada) es el programa: cerrarla = cerrar el panel.
cd /d "%~dp0"
set "BRAVE=%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe"
if not exist "%BRAVE%" set "BRAVE=%LocalAppData%\BraveSoftware\Brave-Browser\Application\brave.exe"
if exist "%BRAVE%" (start "" cmd /c "timeout /t 3 >nul & start "" "%BRAVE%" --app=http://127.0.0.1:8765/") else (start "" cmd /c "timeout /t 3 >nul & start http://127.0.0.1:8765/")
where py >nul 2>nul && (py -3 eloria.py --sin-navegador) || (python eloria.py --sin-navegador)
pause
