[CmdletBinding()]
param(
    [string]$Config = "",
    [string]$Domain = "youtube.com",
    [switch]$Reset
)

$ErrorActionPreference = 'Continue'
$script:LogFile = Join-Path $env:TEMP 'fix-dns.log'

function Write-Line {
    param([string]$Text, [string]$Tone = 'Gray')
    try { Write-Host $Text -ForegroundColor $Tone } catch { Write-Host $Text }
    try {
        $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        [IO.File]::AppendAllText($script:LogFile, "[$stamp] $Text`r`n", (New-Object Text.UTF8Encoding($true)))
    } catch { }
}

function Get-DnsAnswerSafe {
    param([string]$Fqdn, [string]$Via, [int]$TimeoutSec = 5)
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $r = Resolve-DnsName -Name $Fqdn -Type A -Server $Via -DnsOnly -ErrorAction Stop
        $ips = @($r | Where-Object { $_.Type -eq 'A' -and $_.IPAddress } | ForEach-Object { $_.IPAddress })
        $sw.Stop()
        return [pscustomobject]@{ Ips = $ips; Ms = [int]$sw.ElapsedMilliseconds; Ok = $true }
    } catch {
        $sw.Stop()
        return [pscustomobject]@{ Ips = @(); Ms = [int]$sw.ElapsedMilliseconds; Ok = $false }
    }
}

$privateRanges = @('^0\.', '^127\.', '^10\.', '^192\.168\.', '^172\.(1[6-9]|2[0-9]|3[01])\.', '^169\.254\.')
function Test-PrivateOrFake { 
    param([string]$addr)
    foreach ($rx in $privateRanges) { if ($addr -match $rx) { return $true } }
    return $false 
}

function Test-DnsFull {
    param([string]$Dns)
    $names = @("www.$Domain", $Domain)
    if ($Domain -eq 'youtube.com') { $names += @('youtu.be','i.ytimg.com') }
    
    $totalMs = 0
    $totalIps = 0
    foreach ($n in $names) {
        $ans = Get-DnsAnswerSafe -Fqdn $n -Via $Dns -TimeoutSec 5
        $totalMs += $ans.Ms
        if (-not $ans.Ok -or $ans.Ips.Count -eq 0) { 
            return [pscustomobject]@{ Ok = $false; Ms = $totalMs; Reason = "no answer for $n"; IpHits = $totalIps } 
        }
        $real = @($ans.Ips | Where-Object { -not (Test-PrivateOrFake -addr $_) })
        if ($real.Count -eq 0) { 
            return [pscustomobject]@{ Ok = $false; Ms = $totalMs; Reason = "fake IP for $n"; IpHits = $totalIps } 
        }
        $totalIps += $real.Count
    }
    return [pscustomobject]@{ Ok = $true; Ms = $totalMs; Reason = 'ok'; IpHits = $totalIps }
}

$targets = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4DefaultGateway -and $_.IPv4Address })
if ($targets.Count -eq 0) { $targets = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4Address }) }
if ($targets.Count -eq 0) { Write-Line '[X] No active IPv4 adapters.' 'Red'; exit 1 }

if ($Reset) {
    foreach ($t in $targets) {
        try { Set-DnsClientServerAddress -InterfaceIndex $t.InterfaceIndex -ResetServerAddresses -ErrorAction Stop; Write-Line ("  " + $t.InterfaceAlias + ": DHCP.") 'Green' } catch {}
    }
    Clear-DnsClientCache; ipconfig /flushdns | Out-Null; Write-Line 'DNS cache flushed.' 'Green'; exit 0
}

$isWin11 = $false
try { $b = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber; $isWin11 = ($b -ge 22000) } catch { }

$allDns = [ordered]@{}
$lines = Get-Content $Config
foreach ($line in $lines) {
    if ($line -match '^\s*([^,]+),([^,]+),([^,]+),([^,]+),?(.*)$') {
        $key = $matches[1].Trim()
        $allDns[$key] = @{ 
            Title = $matches[2].Trim()
            Primary = $matches[3].Trim()
            Secondary = $matches[4].Trim()
            Doh = $matches[5].Trim()
        }
    }
}

$working = @()
Write-Line ''
Write-Line "  --- DNS Test for $Domain ---" 'Cyan'
Write-Line ''
foreach ($key in $allDns.Keys) {
    $cfg = $allDns[$key]
    Write-Host ('  {0,-20} {1,-15} ' -f $cfg.Title, $cfg.Primary) -NoNewline -ForegroundColor DarkGray
    $r = Test-DnsFull -Dns $cfg.Primary
    if ($r.Ok) {
        Write-Host (' [OK] {0} ms' -f $r.Ms) -ForegroundColor Green
        $working += [pscustomobject]@{ Title = $cfg.Title; Primary = $cfg.Primary; Secondary = $cfg.Secondary; Doh = $cfg.Doh; Ms = $r.Ms }
    } else {
        Write-Host ' [FAIL]' -ForegroundColor Red
    }
}

if ($working.Count -eq 0) { Write-Line '[X] No DNS resolved the domain.' 'Red'; exit 1 }
$working = @($working | Sort-Object Ms)

Write-Line ''
Write-Line '  --- Top-3 best ---' 'Cyan'
$top3 = @($working | Select-Object -First 3)
for ($i=0; $i -lt $top3.Count; $i++) {
    $enc = if ($top3[$i].Doh -and $isWin11) { " (DoH)" } else { "" }
    Write-Line ('  [{0}] {1,-20} {2,-15} {3,6} ms{4}' -f ($i+1), $top3[$i].Title, $top3[$i].Primary, $top3[$i].Ms, $enc) 'White'
}

Write-Host ''
$choice = Read-Host "  Select DNS to apply [1-$($top3.Count)] (Enter = 1)"
$idx = 1
$parsed = 0
if ([int]::TryParse($choice, [ref]$parsed)) { if ($parsed -ge 1 -and $parsed -le $top3.Count) { $idx = $parsed } }

$best = $top3[$idx - 1]
Write-Line ("  >>> Applying: " + $best.Title + " (" + $best.Primary + ")") 'Cyan'

foreach ($t in $targets) {
    try {
        Set-DnsClientServerAddress -InterfaceIndex $t.InterfaceIndex -ServerAddresses @($best.Primary, $best.Secondary) -ErrorAction Stop
        Write-Line ("  " + $t.InterfaceAlias + ": settings updated.") 'Green'
    } catch {
        Write-Line ("  " + $t.InterfaceAlias + ": error.") 'Red'
    }
}

if ($best.Doh -and $isWin11) {
    $dohOk = $true
    foreach ($srv in @($best.Primary, $best.Secondary)) {
        try {
            $out = & netsh dns set encryption server=$srv dohtemplate=$($best.Doh) autoupgrade=yes udpfallback=yes 2>&1
            if ($LASTEXITCODE -ne 0) { $dohOk = $false }
        } catch { $dohOk = $false }
    }
    if ($dohOk) { Write-Line "  DoH enabled." 'Green' } else { Write-Line "  DoH failed to enable." 'Yellow' }
}

Clear-DnsClientCache; ipconfig /flushdns | Out-Null
Write-Line '  Cache flushed.' 'Green'