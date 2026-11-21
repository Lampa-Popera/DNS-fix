@echo off
setlocal
chcp 65001 >nul 2>&1
title DNS Restore - Возврат в норму

:: Проверка прав администратора
whoami /groups 2>nul | findstr /C:"S-1-16-12288" >nul
if not errorlevel 1 goto :admin

echo [!] Требуются права администратора. Запрашиваем...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b

:admin
cls
echo =======================================================
echo               ВОЗВРАТ DNS В АВТОМАТИЧЕСКИЙ РЕЖИМ
echo =======================================================
echo.
echo Ищем активные сетевые адаптеры...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$adapters = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4Address };" ^
  "if (-not $adapters) { Write-Host '[X] Нет активных адаптеров с IPv4.' -ForegroundColor Red; exit 1 };" ^
  "foreach ($a in $adapters) {" ^
  "  Write-Host ('  Сброс на DHCP для: ' + $a.InterfaceAlias) -ForegroundColor Cyan;" ^
  "  try { Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ResetServerAddresses -ErrorAction Stop; Write-Host '    Успешно.' -ForegroundColor Green }" ^
  "  catch { Write-Host ('    Ошибка: ' + $_.Exception.Message) -ForegroundColor Red }" ^
  "};" ^
  "Clear-DnsClientCache;" ^
  "ipconfig /flushdns | Out-Null;" ^
  "Write-Host '';" ^
  "Write-Host 'Кэш DNS очищен. Все настройки сброшены.' -ForegroundColor Green;"

echo.
echo Готово. Нажмите Enter, чтобы закрыть окно.
pause >nul