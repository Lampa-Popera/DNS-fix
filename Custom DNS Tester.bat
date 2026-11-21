@echo off
setlocal
chcp 65001 >nul 2>&1
title Custom DNS Tester

echo =======================================================
echo         ТЕСТИРОВАНИЕ DNS ДЛЯ КОНКРЕТНОГО РЕСУРСА
echo =======================================================
echo.
set /p "TARGET_SITE=Введите домен (например, rutracker.org или vk.com): "

if "%TARGET_SITE%"=="" (
    echo [X] Вы ничего не ввели. Выход.
    pause
    exit /b
)

set "TARGET_SITE=%TARGET_SITE:http://=%"
set "TARGET_SITE=%TARGET_SITE:https://=%"
set "TARGET_SITE=%TARGET_SITE:/=%"

echo.
echo [i] Домен принят: %TARGET_SITE%
echo [i] Запуск DNS-fix 0.2.bat...
timeout /t 2 >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~dp0DNS-fix 0.2.bat' -ArgumentList '-Domain', '%TARGET_SITE%'"

echo.
echo [i] Скрипт запущен в отдельном окне.
timeout /t 3 >nul
exit