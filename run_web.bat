@echo off
title Vendix Multi-Platform Launcher
cls
echo ========================================================
echo             VENDIX MULTI-PLATFORM LAUNCHER             
echo ========================================================
echo.
echo Donde deseas ejecutar la aplicacion?
echo.
echo   --- NAVEGADORES WEB ---
echo   [1] Google Chrome
echo   [2] Microsoft Edge
echo   [3] Brave Browser
echo.
echo   --- ANDROID (DISPOSITIVOS Y EMULADORES) ---
echo   [4] Telefono fisico Android (conectado por cable USB)
echo   [5] Emulador MuMuPlayer (conectado por ADB)
echo.
set /p opcion="Elige una opcion (1, 2, 3, 4 o 5) y presiona ENTER: "

cd /d "%~dp0"

:: Opcion 4: Telefono Android por USB
if "%opcion%"=="4" goto lanzar_android_fisico

:: Opcion 5: Emulador MuMuPlayer
if "%opcion%"=="5" goto lanzar_mumu

:: Opciones Web (1, 2, 3)
echo.
set /p recompilar="Deseas compilar los ultimos cambios de Flutter Web? (S/N) [por defecto S]: "
if /i "%recompilar%"=="N" goto iniciar_servidor_web

echo.
echo [1/2] Compilando aplicacion web... (esto toma ~1 minuto)
call flutter build web
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Hubo un problema al compilar para la web.
    pause
    exit /b
)

:iniciar_servidor_web
echo.
echo [2/2] Iniciando servidor en http://localhost:5000 ...

if "%opcion%"=="1" (
    echo Abriendo en Google Chrome...
    start "" powershell -NoProfile -Command "Start-Sleep -Seconds 1; Start-Process 'chrome.exe' 'http://localhost:5000'"
) else if "%opcion%"=="2" (
    echo Abriendo en Microsoft Edge...
    start "" powershell -NoProfile -Command "Start-Sleep -Seconds 1; Start-Process 'msedge.exe' 'http://localhost:5000'"
) else if "%opcion%"=="3" (
    echo Abriendo en Brave...
    start "" powershell -NoProfile -Command "Start-Sleep -Seconds 1; $brave1 = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\Application\brave.exe'; $brave2 = 'C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe'; if (Test-Path $brave1) { Start-Process $brave1 'http://localhost:5000' } elseif (Test-Path $brave2) { Start-Process $brave2 'http://localhost:5000' } else { Start-Process 'brave.exe' 'http://localhost:5000' }"
) else (
    echo Opcion no reconocida. Abriendo en navegador predeterminado...
    start "" powershell -NoProfile -Command "Start-Sleep -Seconds 1; Start-Process 'http://localhost:5000'"
)

echo.
echo ========================================================
echo  Servidor ACTIVO en http://localhost:5000
echo  (Para detener la aplicacion, solo cierra esta ventana)
echo ========================================================
echo.

powershell -NoProfile -Command "$server = [System.Net.HttpListener]::new(); $server.Prefixes.Add('http://localhost:5000/'); $server.Start(); while ($server.IsListening) { try { $ctx = $server.GetContext(); $ctx.Response.Headers.Add('Cache-Control', 'no-store, no-cache, must-revalidate'); $p = Join-Path 'build\web' ($ctx.Request.Url.LocalPath.TrimStart('/')); if (-not (Test-Path $p) -or (Get-Item $p).PSIsContainer) { $p = 'build\web\index.html' }; $b = [System.IO.File]::ReadAllBytes($p); $ext = [System.IO.Path]::GetExtension($p); $mime = switch ($ext) { '.html' {'text/html'} '.js' {'application/javascript'} '.json' {'application/json'} '.wasm' {'application/wasm'} '.css' {'text/css'} '.png' {'image/png'} default {'application/octet-stream'} }; $ctx.Response.ContentType = $mime; $ctx.Response.OutputStream.Write($b, 0, $b.Length); $ctx.Response.Close() } catch {} }"
exit /b

:lanzar_android_fisico
echo.
echo ========================================================
echo       LANZANDO EN TU TELEFONO ANDROID (CABLE USB)       
echo ========================================================
echo.
echo Conectando con dispositivo fisico...
call flutter run -d nrk7v8x47pibhyjj
if %errorlevel% neq 0 (
    echo.
    echo Intentando con el identificador secundario...
    call flutter run -d 21061110AG
)
goto fin

:lanzar_mumu
echo.
echo ========================================================
echo            LANZANDO EN EMULADOR MUMUPLAYER              
echo ========================================================
echo.
echo Conectando ADB al puerto de MuMuPlayer...
powershell -NoProfile -Command "$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'; if (Test-Path $adb) { & $adb connect 127.0.0.1:16384; & $adb connect 127.0.0.1:7555 } else { adb connect 127.0.0.1:16384; adb connect 127.0.0.1:7555 }"
echo.
echo Lanzando aplicacion en el emulador MuMuPlayer...
echo (La primera vez demora unos momentos mientras compila el APK).
echo.
call flutter run -d 127.0.0.1:16384
if %errorlevel% neq 0 (
    echo.
    echo Intentando por el puerto secundario de MuMu...
    call flutter run -d 127.0.0.1:7555
)

:fin
echo.
echo ========================================================
echo  Sesion finalizada. Presiona una tecla para cerrar.
echo ========================================================
pause
