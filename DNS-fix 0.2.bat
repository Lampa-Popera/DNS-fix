@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1

set "SELF=%~f0"
set "ARGS=%*"
set "TMPPS=%TEMP%\fixdns_%RANDOM%_%RANDOM%.ps1"
set "FIXDNS_LOG=%~dp0fix-dns.log"

whoami /groups 2>nul | findstr /C:"S-1-16-12288" >nul
if not errorlevel 1 goto :go

set "PASSARGS="
if defined ARGS set "PASSARGS=-ArgumentList $env:ARGS"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:SELF -Verb RunAs %PASSARGS%"
exit /b

:go
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$src=[IO.File]::ReadAllText($env:SELF); $k='#@#CORE#@#'; $p=$src.LastIndexOf($k); if($p -lt 0){exit 3}; $body=$src.Substring($p+$k.Length); [IO.File]::WriteAllText($env:TMPPS,$body,(New-Object Text.UTF8Encoding($true)))"

if errorlevel 1 (
    echo [X] Ошибка распаковки.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMPPS%" %*
set "RC=%ERRORLEVEL%"
del /f /q "%TMPPS%" >nul 2>&1

echo.
echo [i] Готово. Код возврата: %RC%
echo [i] Лог: %FIXDNS_LOG%
pause
exit /b %RC%

#@#CORE#@#
[CmdletBinding()]
param(
    [ValidateSet('auto','yandex','adguard','quad9','google','cloudflare','opendns','comss','cleanbrowsing','dns4eu','dns0','mullvad','libredns','hostux','wikimedia','uncensored','dnssb','alidns')]
    [string]$Provider = 'auto',
    [string]$Domain = 'youtube.com',
    [switch]$Reset,
    [switch]$OnlyTest,
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'
$script:LogFile = if ($env:FIXDNS_LOG) { $env:FIXDNS_LOG } else { Join-Path $env:TEMP 'fix-dns.log' }

function Write-Line {
    param([string]$Text, [string]$Tone = 'Gray')
    try { Write-Host $Text -ForegroundColor $Tone } catch { Write-Host $Text }
    try {
        $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        [IO.File]::AppendAllText($script:LogFile, "[$stamp] $Text`r`n", (New-Object Text.UTF8Encoding($true)))
    } catch { }
}

function Write-TestRow {
    param([string]$Title, [string]$Primary, [string]$Mode, [bool]$Ok, [int]$Ms, [int]$IpHits, [string]$Reason)
    $tag = if ($Mode -eq 'DoH') { '[DoH]' } else { '[UDP]' }
    if ($Ok) {
        Write-Host ('{0,6} ms  {1} [OK, {2} IP]' -f $Ms, $tag, $IpHits) -ForegroundColor Green
        $statusText = ('OK ({0} IP, {1} ms)' -f $IpHits, $Ms)
    } else {
        Write-Host ('{0,6} ms  {1} [FAIL: {2}]' -f $Ms, $tag, $Reason) -ForegroundColor Red
        $statusText = ('FAIL: {0} ({1} ms)' -f $Reason, $Ms)
    }
    try {
        $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $logLine = '[{0}]   {1,-20} {2,-15} {3} {4}' -f $stamp, $Title, $Primary, $tag, $statusText
        [IO.File]::AppendAllText($script:LogFile, $logLine + "`r`n", (New-Object Text.UTF8Encoding($true)))
    } catch { }
}

function Read-Enter {
    if ($Quiet) { return }
    try { Write-Host ''; [void](Read-Host 'Enter - закрыть') } catch { }
}

function Get-DnsAnswerSafe {
    param([Parameter(Mandatory)][string]$Fqdn, [Parameter(Mandatory)][string]$Via, [int]$TimeoutSec = 5)
    $job = Start-Job -ScriptBlock {
        param($fqdn, $server)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $r = Resolve-DnsName -Name $fqdn -Type A -Server $server -DnsOnly -ErrorAction Stop
            $ips = @($r | Where-Object { $_.Type -eq 'A' -and $_.IPAddress } | ForEach-Object { $_.IPAddress })
            $sw.Stop()
            return [pscustomobject]@{ Ips = $ips; Ms = [int]$sw.ElapsedMilliseconds; Ok = $true }
        } catch {
            $sw.Stop()
            return [pscustomobject]@{ Ips = @(); Ms = [int]$sw.ElapsedMilliseconds; Ok = $false }
        }
    } -ArgumentList $Fqdn, $Via

    $done = Wait-Job -Job $job -Timeout $TimeoutSec
    if (-not $done) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Ips = @(); Ms = ($TimeoutSec * 1000); Ok = $false }
    }
    $res = @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    if ($res.Count -eq 0) { return [pscustomobject]@{ Ips = @(); Ms = 0; Ok = $false } }
    return $res[0]
}

$privateRanges = @('^0\.', '^127\.', '^10\.', '^192\.168\.', '^172\.(1[6-9]|2[0-9]|3[01])\.', '^169\.254\.')

function Test-PrivateOrFake {
    param([string]$addr)
    if ([string]::IsNullOrWhiteSpace($addr)) { return $true }
    foreach ($rx in $privateRanges) { if ($addr -match $rx) { return $true } }
    return $false
}

function Test-DnsFull {
    param([Parameter(Mandatory)][string]$Dns)
    
    $names = @("www.$Domain", $Domain)
    if ($Domain -eq 'youtube.com') {
        $names += @('youtu.be','i.ytimg.com') 
    }

    $totalMs = 0
    $totalIps = 0

    foreach ($n in $names) {
        $ans = Get-DnsAnswerSafe -Fqdn $n -Via $Dns -TimeoutSec 5
        $totalMs += $ans.Ms
        if (-not $ans.Ok -or $ans.Ips.Count -eq 0) {
            return [pscustomobject]@{ Ok = $false; Ms = $totalMs; Reason = ('нет ответа на ' + $n); IpHits = $totalIps }
        }
        $real = @($ans.Ips | Where-Object { -not (Test-PrivateOrFake -addr $_) })
        if ($real.Count -eq 0) {
            return [pscustomobject]@{ Ok = $false; Ms = $totalMs; Reason = ('подмена на ' + $n); IpHits = $totalIps }
        }
        $totalIps += $real.Count
    }
    return [pscustomobject]@{ Ok = $true; Ms = $totalMs; Reason = 'ok'; IpHits = $totalIps }
}

$allDns = [ordered]@{
    'yandex'        = @{ Title = 'Yandex DNS';        Primary = '77.88.8.8';       Secondary = '77.88.8.1';      Doh = $null }
    'yandex2'       = @{ Title = 'Yandex DNS (2)';    Primary = '77.88.8.2';       Secondary = '77.88.8.8';      Doh = $null }
    'adguard'       = @{ Title = 'AdGuard DNS';       Primary = '94.140.14.14';    Secondary = '94.140.15.15';   Doh = 'https://dns.adguard-dns.com/dns-query' }
    'adguard-unf'   = @{ Title = 'AdGuard Unfiltered'; Primary = '94.140.14.140';  Secondary = '94.140.14.141';  Doh = 'https://unfiltered.adguard-dns.com/dns-query' }
    'quad9'         = @{ Title = 'Quad9';             Primary = '9.9.9.9';         Secondary = '149.112.112.112'; Doh = 'https://dns.quad9.net/dns-query' }
    'quad9sec'      = @{ Title = 'Quad9 (secure)';    Primary = '9.9.9.10';        Secondary = '149.112.112.10'; Doh = 'https://dns.quad9.net/dns-query' }
    'cleanbrowsing' = @{ Title = 'CleanBrowsing';     Primary = '185.228.168.9';   Secondary = '185.228.169.9';  Doh = 'https://security-filter-dns.cleanbrowsing.org/dns-query' }
    'cloudflare'    = @{ Title = 'Cloudflare';        Primary = '1.1.1.1';         Secondary = '1.0.0.1';        Doh = 'https://cloudflare-dns.com/dns-query' }
    'google'        = @{ Title = 'Google DNS';        Primary = '8.8.8.8';         Secondary = '8.8.4.4';        Doh = 'https://dns.google/dns-query' }
    'opendns'       = @{ Title = 'OpenDNS';           Primary = '208.67.222.222';  Secondary = '208.67.220.220'; Doh = 'https://doh.opendns.com/dns-query' }
    'comss'         = @{ Title = 'Comss DNS';         Primary = '83.220.169.155';  Secondary = '212.109.195.93'; Doh = $null }
    'dns4eu'        = @{ Title = 'DNS4EU';            Primary = '86.54.11.100';    Secondary = '86.54.11.200';   Doh = 'https://unfiltered.joindns4.eu/dns-query' }
    'dns0'          = @{ Title = 'dns0.eu';           Primary = '193.110.81.0';    Secondary = '185.253.5.0';    Doh = 'https://open.dns0.eu' }
    'mullvad'       = @{ Title = 'Mullvad DNS';       Primary = '194.242.2.2';     Secondary = '194.242.2.3';    Doh = 'https://dns.mullvad.net/dns-query' }
    'libredns'      = @{ Title = 'LibreDNS';          Primary = '116.202.176.26';  Secondary = '116.202.176.27'; Doh = 'https://doh.libredns.gr/dns-query' }
    'hostux'        = @{ Title = 'Hostux DNS';        Primary = '185.213.155.10';  Secondary = '185.213.155.11'; Doh = 'https://dns.hostux.net/dns-query' }
    'wikimedia'     = @{ Title = 'Wikimedia DNS';     Primary = '208.80.153.153';  Secondary = '208.80.154.153'; Doh = 'https://wikimedia-dns.org/dns-query' }
    'uncensored'    = @{ Title = 'UncensoredDNS';     Primary = '91.239.100.100';  Secondary = '89.233.43.71';   Doh = 'https://anycast.uncensoreddns.org/dns-query' }
    'dnssb'         = @{ Title = 'DNS.SB';            Primary = '185.222.222.222'; Secondary = '45.11.45.11';    Doh = 'https://doh.dns.sb/dns-query' }
    'alidns'        = @{ Title = 'AliDNS';            Primary = '223.5.5.5';       Secondary = '223.6.6.6';      Doh = 'https://dns.alidns.com/dns-query' }
}

function Test-DohReachable {
    param([string]$DohUrl)
    if (-not $DohUrl) { return $false }
    try {
        $req = [System.Net.HttpWebRequest]::Create($DohUrl)
        $req.Method = 'GET'
        $req.Timeout = 4000
        $req.ReadWriteTimeout = 4000
        $req.UserAgent = 'Mozilla/5.0'
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        return ($code -ge 200 -and $code -lt 500)
    } catch {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
            return ($code -ge 200 -and $code -lt 500)
        }
        return $false
    }
}

function Test-DohFull {
    param([string]$Dns, [string]$DohUrl)
    if (-not (Test-DohReachable -DohUrl $DohUrl)) {
        return [pscustomobject]@{ Ok = $false; Ms = 4000; Reason = 'DoH endpoint недоступен'; IpHits = 0 }
    }
    $r = Test-DnsFull -Dns $Dns
    if ($r.Ok) { return [pscustomobject]@{ Ok = $true; Ms = $r.Ms; Reason = 'ok'; IpHits = $r.IpHits } }
    return [pscustomobject]@{ Ok = $false; Ms = $r.Ms; Reason = $r.Reason; IpHits = 0 }
}

try {
    $targets = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4DefaultGateway -and $_.IPv4Address })
    if ($targets.Count -eq 0) { $targets = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4Address }) }
    if ($targets.Count -eq 0) {
        Write-Line '[X] Нет живых адаптеров с IPv4.' 'Red'
        Read-Enter; exit 1
    }

    Write-Line ''
    Write-Line '  +======================================================+' 'Cyan'
    Write-Line '  |   Д Е Т Е К Т И В :  Куда пропал доступ?             |' 'Cyan'
    Write-Line '  +======================================================+' 'Cyan'
    Write-Line ''
    Write-Line ('  Цель: {0}' -f $Domain) 'White'
    Write-Line ''

    Write-Line '  --- Адаптеры ---' 'Cyan'
    foreach ($t in $targets) {
        $cur = @((Get-DnsClientServerAddress -InterfaceIndex $t.InterfaceIndex -AddressFamily IPv4).ServerAddresses)
        $curText = if ($cur.Count -gt 0) { $cur -join ', ' } else { 'авто (DHCP)' }
        Write-Line ('    {0}  ->  {1}' -f $t.InterfaceAlias, $curText) 'DarkGray'
    }
    Write-Line ''

    if ($Reset) {
        Write-Line '--- Возврат на DHCP ---' 'Cyan'
        foreach ($t in $targets) {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $t.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
                Write-Line ('  {0}: DHCP.' -f $t.InterfaceAlias) 'Green'
            } catch {
                Write-Line ('  {0}: ошибка - {1}' -f $t.InterfaceAlias, $_.Exception.Message) 'Red'
            }
        }
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        & ipconfig /flushdns 2>&1 | Out-Null
        Write-Line 'Кэш очищен.' 'Green'
        Read-Enter; exit 0
    }

    $isWin11 = $false
    try { $b = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber; $isWin11 = ($b -ge 22000) } catch { }

    if ($Provider -ne 'auto' -and $allDns.Contains($Provider)) { $toTest = @($Provider) } else { $toTest = @($allDns.Keys) }

    Write-Line ('  --- Тест DNS ({0} провайдеров, UDP + DoH) ---' -f $toTest.Count) 'Cyan'
    Write-Line ('  (Проверяем: www.{0} / {0})' -f $Domain) 'DarkGray'
    if ($Domain -eq 'youtube.com') {
        Write-Line '  (Дополнительно для YouTube: i.ytimg.com / youtu.be)' 'DarkGray'
    }
    Write-Line ''

    $results = @()
    foreach ($key in $toTest) {
        $cfg = $allDns[$key]
        Write-Host ('  {0,-20} {1,-15} ' -f $cfg.Title, $cfg.Primary) -NoNewline -ForegroundColor DarkGray

        try { $rUdp = Test-DnsFull -Dns $cfg.Primary } catch { $rUdp = [pscustomobject]@{ Ok = $false; Ms = 0; Reason = ('исключение: ' + $_.Exception.Message); IpHits = 0 } }
        Write-TestRow -Title $cfg.Title -Primary $cfg.Primary -Mode 'UDP' -Ok $rUdp.Ok -Ms $rUdp.Ms -IpHits $rUdp.IpHits -Reason $rUdp.Reason

        $results += [pscustomobject]@{
            Key = $key; Title = $cfg.Title; Primary = $cfg.Primary; Secondary = $cfg.Secondary; Doh = $cfg.Doh;
            Mode = 'UDP'; Ok = $rUdp.Ok; Ms = $rUdp.Ms; Reason = $rUdp.Reason; IpHits = $rUdp.IpHits
        }

        if ($cfg.Doh) {
            Write-Host ('  {0,-20} {1,-15} ' -f '', '') -NoNewline
            try { $rDoh = Test-DohFull -Dns $cfg.Primary -DohUrl $cfg.Doh } catch { $rDoh = [pscustomobject]@{ Ok = $false; Ms = 0; Reason = ('исключение: ' + $_.Exception.Message); IpHits = 0 } }
            Write-TestRow -Title $cfg.Title -Primary $cfg.Primary -Mode 'DoH' -Ok $rDoh.Ok -Ms $rDoh.Ms -IpHits $rDoh.IpHits -Reason $rDoh.Reason
            $results += [pscustomobject]@{
                Key = $key; Title = $cfg.Title; Primary = $cfg.Primary; Secondary = $cfg.Secondary; Doh = $cfg.Doh;
                Mode = 'DoH'; Ok = $rDoh.Ok; Ms = $rDoh.Ms; Reason = $rDoh.Reason; IpHits = $rDoh.IpHits
            }
        } else {
            Write-Host ('  {0,6}      [DoH] [SKIP: нет шаблона]' -f '') -ForegroundColor DarkGray
        }
    }

    $workingUdp = @($results | Where-Object { $_.Mode -eq 'UDP' -and $_.Ok } | Sort-Object Ms)
    $workingDoh = @($results | Where-Object { $_.Mode -eq 'DoH' -and $_.Ok } | Sort-Object Ms)
    $allWorking = @($results | Where-Object { $_.Ok } | Sort-Object Ms -Descending)

    $workingForChoice = @()
    foreach ($r in $allWorking) {
        $dup = $false
        foreach ($c in $workingForChoice) {
            if ($c.Key -eq $r.Key) { $dup = $true; break }
        }
        if (-not $dup) { $workingForChoice += $r }
    }

    Write-Line ''
    Write-Line '  --- Итоги ---' 'Cyan'

    if ($workingForChoice.Count -eq 0) {
        Write-Line '[X] Ни один DNS не резолвит этот домен честно.' 'Red'
        Write-Line '    Проблема не в DNS, а глубже.' 'Yellow'
        Read-Enter; exit 1
    }

    Write-Line ('  UDP рабочих: {0}' -f $workingUdp.Count) 'Green'
    if ($workingDoh.Count -gt 0) { Write-Line ('  DoH рабочих: {0}' -f $workingDoh.Count) 'Green' } else { Write-Line '  DoH рабочих: 0' 'Yellow' }

    Write-Line ''
    Write-Line '  Топ UDP по скорости:' 'Cyan'
    foreach ($w in ($workingUdp | Select-Object -First 5)) {
        Write-Line ('    {0,-20} {1,-15} {2,6} ms' -f $w.Title, $w.Primary, $w.Ms) 'Green'
    }
    if ($workingDoh.Count -gt 0) {
        Write-Line ''
        Write-Line '  Топ DoH по скорости:' 'Cyan'
        foreach ($w in ($workingDoh | Select-Object -First 5)) {
            Write-Line ('    {0,-20} {1,-15} {2,6} ms' -f $w.Title, $w.Primary, $w.Ms) 'Green'
        }
    }

    $best = $workingUdp[0]
    if ($workingDoh.Count -gt 0 -and $workingUdp.Count -gt 0) {
        if ($workingDoh[0].Ms -le ($workingUdp[0].Ms * 1.5)) { $best = $workingDoh[0] } else { $best = $workingUdp[0] }
    } elseif ($workingDoh.Count -gt 0) {
        $best = $workingDoh[0]
    }

    if ($OnlyTest) {
        Write-Line ''
        Write-Line 'Режим OnlyTest: ничего не меняю.' 'Yellow'
        Read-Enter; exit 0
    }

    Write-Line ''
    Write-Line '  --- Выбор DNS для применения ---' 'Cyan'
    
    $topChoices = @()
    foreach ($candidate in $workingForChoice) {
        if ($topChoices.Count -ge 3) { break }
        $topChoices += $candidate
    }

    $bestIndex = 1
    for ($i = 0; $i -lt $topChoices.Count; $i++) {
        if ($topChoices[$i].Key -eq $best.Key -and $topChoices[$i].Mode -eq $best.Mode) {
            $bestIndex = $i + 1
            break
        }
    }

    for ($i = 0; $i -lt $topChoices.Count; $i++) {
        $c = $topChoices[$i]
        $modeStr = if ($c.Mode -eq 'DoH') { 'с шифрованием' } else { 'без шифрования' }
        $marker = if (($i + 1) -eq $bestIndex) { ' <<< рекомендуется' } else { '' }
        Write-Line ('  [{0}] {1,-20} {2,-15} {3,6} ms ({4}){5}' -f ($i + 1), $c.Title, $c.Primary, $c.Ms, $modeStr, $marker) 'White'
    }

    Write-Host ''
    $userChoice = ''
    try { $userChoice = Read-Host ('  Введите номер DNS для применения [1-{0}] (Enter = {1}): ' -f $topChoices.Count, $bestIndex) } catch { }

    $selectedIndex = $bestIndex - 1
    $parsed = 0
    if ([int]::TryParse($userChoice, [ref]$parsed)) {
        if ($parsed -ge 1 -and $parsed -le $topChoices.Count) { $selectedIndex = $parsed - 1 }
    }
    
    $best = $topChoices[$selectedIndex]
    $modeLabel = if ($best.Mode -eq 'DoH') { ' (с шифрованием)' } else { ' (без шифрования)' }
    Write-Line ('  >>> Применяю: {0} ({1}) - {2} ms{3}' -f $best.Title, $best.Primary, $best.Ms, $modeLabel) 'Cyan'

    Write-Line ''
    Write-Line '  --- Применение ---' 'Cyan'

    $serverList = @($best.Primary, $best.Secondary) | Where-Object { $_ }
    $applied = 0
    foreach ($t in $targets) {
        try {
            $cur = @((Get-DnsClientServerAddress -InterfaceIndex $t.InterfaceIndex -AddressFamily IPv4).ServerAddresses)
            if ($cur.Count -ge 2 -and $cur[0] -eq $best.Primary -and $cur[1] -eq $best.Secondary) {
                Write-Line ('  {0}: уже стоит.' -f $t.InterfaceAlias) 'DarkGray'
                $applied++
                continue
            }
            Set-DnsClientServerAddress -InterfaceIndex $t.InterfaceIndex -ServerAddresses $serverList -ErrorAction Stop
            Write-Line ('  {0}: {1}' -f $t.InterfaceAlias, ($serverList -join ', ')) 'Green'
            $applied++
        } catch {
            Write-Line ('  {0}: ошибка - {1}' -f $t.InterfaceAlias, $_.Exception.Message) 'Red'
        }
    }

    if ($applied -eq 0) {
        Write-Line '[X] Ни на один адаптер не легло.' 'Red'
        Read-Enter; exit 1
    }

    if ($best.Mode -eq 'DoH' -and $best.Doh -and $isWin11) {
        $dohOk = $true
        foreach ($srv in $serverList) {
            try {
                $out = & netsh dns set encryption server=$srv dohtemplate=$($best.Doh) autoupgrade=yes udpfallback=yes 2>&1
                if ($LASTEXITCODE -ne 0) { $dohOk = $false; break }
            } catch { $dohOk = $false; break }
        }
        if ($dohOk) { Write-Line ('  DoH: {0}' -f $best.Doh) 'Green' } else { Write-Line '  DoH не включился. Обычный DNS.' 'Yellow' }
    } elseif ($best.Mode -eq 'DoH' -and -not $isWin11) {
        Write-Line '  DoH недоступен (нужна Win11). DNS работает без шифрования.' 'DarkGray'
    } else {
        Write-Line '  Режим без шифрования (DoH не выбран).' 'DarkGray'
    }

    Clear-DnsClientCache -ErrorAction SilentlyContinue
    & ipconfig /flushdns 2>&1 | Out-Null
    Write-Line '  Кэш очищен.' 'Green'

    Write-Line ''
    Write-Line '  --- Проверка после применения ---' 'Cyan'

    $finalOk = $true
    foreach ($n in $names) {
        $ans = Get-DnsAnswerSafe -Fqdn $n -Via $best.Primary -TimeoutSec 5
        if ($ans.Ok -and $ans.Ips.Count -gt 0) {
            $real = @($ans.Ips | Where-Object { -not (Test-PrivateOrFake -addr $_) })
            if ($real.Count -gt 0) {
                Write-Line ('  {0} -> {1}' -f $n, (($real | Select-Object -First 3) -join ', ')) 'Green'
            } else {
                Write-Line ('  {0} -> подмена' -f $n) 'Red'
                $finalOk = $false
            }
        } else {
            Write-Line ('  {0} -> нет ответа' -f $n) 'Red'
            $finalOk = $false
        }
    }

    Write-Line ''
    if ($finalOk) {
        Write-Line '  +======================================================+' 'Cyan'
        Write-Line '  |   Готово. Доступ должен восстановиться.               |' 'Green'
        Write-Line '  +======================================================+' 'Cyan'
        Write-Line ''
        Write-Line '  Create by Just Moments' 'Cyan'
    } else {
        Write-Line '  DNS встал, но проверка не прошла.' 'Yellow'
    }
}
catch {
    Write-Line ''
    Write-Line ('[!] Внутренняя ошибка: ' + $_.Exception.Message) 'Red'
    Write-Line ('    ' + $_.InvocationInfo.PositionMessage) 'DarkGray'
}
finally {
    Read-Enter
    exit 0
}