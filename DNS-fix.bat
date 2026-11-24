@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
title DNS-fix: System Console

if not exist "%~dp0core" (
    echo [X] Критическая ошибка: папка core не найдена!
    pause
    exit /b
)

whoami /groups 2>nul | findstr /C:"S-1-16-12288" >nul
if not errorlevel 1 goto :menu

echo [i] Запрос прав администратора...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b

:menu
cls
echo =======================================================
echo                  DNS-FIX SYSTEM v0.3
echo =======================================================
echo.
echo  Выберите вашу операционную систему:
echo  [1] Windows 10
echo  [2] Windows 11
echo  [3] Выход
echo.
set /p "OS_CHOICE=Ваш выбор [1-3]: "

if "%OS_CHOICE%"=="1" set "OS_VER=win10" & goto :mode_menu
if "%OS_CHOICE%"=="2" set "OS_VER=win11" & goto :mode_menu
if "%OS_CHOICE%"=="3" exit
goto :menu

:mode_menu
cls
echo =======================================================
echo                  DNS-FIX SYSTEM v0.3
echo =======================================================
echo  ОС: %OS_VER%
echo -------------------------------------------------------
echo.
echo  Выберите режим тестирования:
echo  [1] Быстрый (7 самых популярных DNS)
echo  [2] Расширенный (20 DNS для максимальной надежности)
echo  [3] Вернуть настройки DNS как было (DHCP)
echo  [4] Назад в меню
echo.
set /p "MODE_CHOICE=Ваш выбор [1-4]: "

if "%MODE_CHOICE%"=="1" set "CONFIG_FILE=%~dp0modules\%OS_VER%_fast.txt"
if "%MODE_CHOICE%"=="2" set "CONFIG_FILE=%~dp0modules\%OS_VER%_full.txt"
if "%MODE_CHOICE%"=="3" goto :reset_dns
if "%MODE_CHOICE%"=="4" goto :menu

if "%MODE_CHOICE%"=="1" goto :ask_domain
if "%MODE_CHOICE%"=="2" goto :ask_domain
goto :mode_menu

:ask_domain
cls
echo =======================================================
echo  Выберите цель для починки:
echo  [1] YouTube (по умолчанию)
echo  [2] Другой сайт
echo.
set /p "SITE_CHOICE=Ваш выбор [1-2]: "

if "%SITE_CHOICE%"=="1" (
    set "TARGET_DOMAIN=youtube.com"
    goto :run_test
)
if "%SITE_CHOICE%"=="2" (
    echo.
    set /p "TARGET_DOMAIN=Введите домен (например, rutracker.org): "
    if "!TARGET_DOMAIN!"=="" goto :ask_domain
    set "TARGET_DOMAIN=!TARGET_DOMAIN:http://=!"
    set "TARGET_DOMAIN=!TARGET_DOMAIN:https://=!"
    set "TARGET_DOMAIN=!TARGET_DOMAIN:/=!"
    goto :run_test
)
goto :ask_domain

:run_test
cls
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0core\engine.ps1" -Config "%CONFIG_FILE%" -Domain "%TARGET_DOMAIN%"
echo.
pause
goto :mode_menu

:reset_dns
cls
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0core\engine.ps1" -Reset
echo.
pause
goto :mode_menu