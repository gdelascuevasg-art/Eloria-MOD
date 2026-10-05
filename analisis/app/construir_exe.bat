@echo off
rem Crea analisis\Panel Eloria.exe a partir de panel_eloria.py (necesita: pip install pyinstaller pywebview).
rem Version: VERSION en panel_eloria.py y en ..\eloria.py + version_info.txt + ..\VERSIONES.txt
cd /d "%~dp0"
python -m PyInstaller --noconfirm --noconsole --onefile --name "Panel Eloria" --distpath .. --workpath build --specpath build --version-file ..\version_info.txt --icon ..\..\eloria.ico panel_eloria.py
pause
