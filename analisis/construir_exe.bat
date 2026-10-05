@echo off
rem Construye Eloria.exe (ventana propia del panel) en esta carpeta. Solo hace falta repetirlo si cambia app.py o eloria.py.
cd /d "%~dp0"
set "PY=python"
where py >/dev/null 2>/dev/null && set "PY=py -3"
%PY% -m pip install --user --upgrade pywebview pyinstaller || goto :error
%PY% -m PyInstaller --noconfirm --clean --onefile --windowed --name Eloria --icon "%~dp0eloria.ico" --distpath . --workpath build_exe --specpath build_exe app.py || goto :error
rmdir /s /q build_exe
echo.
echo Listo: %~dp0Eloria.exe
exit /b 0
:error
echo Error al construir Eloria.exe
pause
exit /b 1
