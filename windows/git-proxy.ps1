# git-proxy.ps1 - Git Proxy Manager (HTTP / HTTPS / SOCKS5)
#
# Usage:
#   .\git-proxy.ps1 -h <IP> -p <PORT> -ProxyType <TYPE> -s      Set proxy (apply immediately)
#   .\git-proxy.ps1 -t                                    Test current proxy connectivity
#   .\git-proxy.ps1 -u                                    Unset proxy
#   .\git-proxy.ps1 -c                                    Show current proxy status
#   .\git-proxy.ps1 -Help                                 Show help
#
# Examples:
#   .\git-proxy.ps1 -h 127.0.0.1 -p 1080 -s                  # Default: SOCKS5
#   .\git-proxy.ps1 -h 127.0.0.1 -p 1080 -ProxyType socks5 -s
#   .\git-proxy.ps1 -h 127.0.0.1 -p 7890 -ProxyType http -s          # HTTP proxy
#   .\git-proxy.ps1 -h proxy.example.com -p 8080 -ProxyType https -s # HTTPS proxy
#   .\git-proxy.ps1 -t                                       # Test current proxy
#   .\git-proxy.ps1 -u                                       # Unset proxy

param(
    [Alias("h")][string]$ProxyHost,
    [Alias("p")][int]$ProxyPort,
    [ValidateSet("http","https","socks5")][string]$ProxyType = "socks5",
    [Alias("t")][switch]$Test,
    [Alias("s")][switch]$Set,
    [Alias("u")][switch]$Unset,
    [Alias("c")][switch]$Check,
    [switch]$Help
)

# ========== Color Functions ==========
function Write-Info { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ========== Help ==========
function Show-Help {
@"
Git Proxy Manager (HTTP / HTTPS / SOCKS5)

Usage:
    .\git-proxy.ps1 -h <IP> -p <PORT> -ProxyType <TYPE> -s      Set proxy
    .\git-proxy.ps1 -t                                    Test current proxy
    .\git-proxy.ps1 -u                                    Unset proxy
    .\git-proxy.ps1 -c                                    Show current proxy status
    .\git-proxy.ps1 -Help                                 Show this help

Parameters:
    -h, -ProxyHost     Proxy server IP or hostname (e.g. 127.0.0.1)
    -p, -ProxyPort     Proxy port (e.g. 1080)
    -T, -ProxyType     Proxy protocol: http | https | socks5 (default: socks5)
                       Note: Only -ProxyType (full name) works, -T is reserved for -Test
    -t, -Test          Test current proxy connectivity (no other args needed)
    -s, -Set           Apply proxy settings to Git
    -u, -Unset         Unset Git proxy
    -c, -Check         Show current proxy status
    -Help              Show this help

Supported Protocols:
    socks5    SOCKS5 proxy (recommended)
    http      HTTP proxy  (e.g. Clash default port 7890)
    https     HTTPS proxy (less common)

Examples:
    # Set SOCKS5 proxy (default)
    .\git-proxy.ps1 -h 127.0.0.1 -p 1080 -s
    .\git-proxy.ps1 -h 127.0.0.1 -p 10808 -ProxyType socks5 -s

    # Set HTTP proxy (Clash default port)
    .\git-proxy.ps1 -h 127.0.0.1 -p 7890 -ProxyType http -s

    # Set HTTPS proxy
    .\git-proxy.ps1 -h proxy.example.com -p 8080 -ProxyType https -s

    # Test current proxy connectivity
    .\git-proxy.ps1 -t

    # Unset proxy
    .\git-proxy.ps1 -u

    # Check proxy status
    .\git-proxy.ps1 -c

Notes:
    - Only modifies git config (global ~/.gitconfig), not system env vars
    - Sets both http.proxy and https.proxy
    - Apply takes effect immediately
    - For SOCKS5, URL prefix is socks5://
    - For HTTP, URL prefix is http://
    - For HTTPS proxy, URL prefix is https://
"@
}

# ========== Check Git ==========
function Test-GitInstalled {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Err "Git not found. Please install Git for Windows first."
        Write-Info "Download: https://git-scm.com/download/win"
        exit 1
    }
}

# ========== Test Current Proxy ==========
function Test-CurrentProxy {
    Write-Info "Testing current Git proxy connectivity..."
    Write-Host ""

    $httpProxy  = git config --global --get http.proxy
    $httpsProxy = git config --global --get https.proxy

    if (-not $httpProxy -and -not $httpsProxy) {
        Write-Warn "No proxy currently set. Use -h <IP> -p <PORT> -s to set one."
        return
    }

    $results = @()
    $proxies = @()

    if ($httpProxy)  { $proxies += @{ name = "http.proxy";  url = $httpProxy  } }
    if ($httpsProxy) { $proxies += @{ name = "https.proxy"; url = $httpsProxy } }

    foreach ($p in $proxies) {
        Write-Host "  Testing $($p.name) = $($p.url) ..." -ForegroundColor Gray

        if ($p.url -match '^(https?|socks5)://([^:]+):(\d+)$') {
            $proto    = $Matches[1]
            $testHost = $Matches[2]
            $testPort = [int]$Matches[3]

            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $iar = $tcp.BeginConnect($testHost, $testPort, $null, $null)
                $success = $iar.AsyncWaitHandle.WaitOne(2000, $false)

                if ($success -and $tcp.Connected) {
                    Write-OK ("    [REACHABLE]  {0}://{1}:{2}" -f $proto, $testHost, $testPort)
                    $tcp.Close()

                    # Optional: test actual HTTP/SOCKS5 handshake (skip for socks5)
                    if ($proto -in @("http","https")) {
                        try {
                            $req  = [System.Net.HttpWebRequest]::Create("http://www.github.com")
                            $req.Proxy = New-Object System.Net.WebProxy($p.url)
                            $req.Timeout = 5000
                            $req.Method = "HEAD"
                            $resp = $req.GetResponse()
                            Write-OK ("    [HTTP OK]    github.com reachable via proxy" -f $proto, $testHost, $testPort)
                            $resp.Close()
                        }
                        catch {
                            Write-Warn ("    [HTTP FAIL]  github.com NOT reachable via proxy: {0}" -f $_.Exception.Message)
                        }
                    }
                }
                else {
                    Write-Warn ("    [UNREACHABLE] {0}://{1}:{2}" -f $proto, $testHost, $testPort)
                    $tcp.Close()
                }
            }
            catch {
                Write-Err ("    [ERROR]      {0}://{1}:{2} - {3}" -f $proto, $testHost, $testPort, $_.Exception.Message)
            }
        }
        else {
            Write-Warn "    [SKIP]       Unrecognized URL format"
        }
        Write-Host ""
    }
}

# ========== Set Proxy ==========
function Set-GitProxyInternal {
    param([string]$ProxyHost, [int]$ProxyPort, [string]$ProxyType)

    if (-not $ProxyHost -or -not $ProxyPort) {
        Write-Err "Setting proxy requires -h <IP> and -p <port>"
        Show-Help
        exit 1
    }

    # Validate IP / domain
    $ipRegex = '^(\d{1,3}\.){3}\d{1,3}$'
    $domainRegex = '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    if ($ProxyHost -notmatch $ipRegex -and $ProxyHost -notmatch $domainRegex) {
        Write-Err "Invalid proxy host: $ProxyHost"
        exit 1
    }

    # Validate port
    if ($ProxyPort -lt 1 -or $ProxyPort -gt 65535) {
        Write-Err "Invalid port: $ProxyPort (range 1-65535)"
        exit 1
    }

    $validTypes = @("http","https","socks5")
    if ($ProxyType -notin $validTypes) {
        Write-Err "Invalid proxy type: $ProxyType (must be one of: http, https, socks5)"
        exit 1
    }

    $proxyUrl = "${ProxyType}://${ProxyHost}:${ProxyPort}"

    Write-Info "Setting $ProxyType proxy: $proxyUrl"

    try {
        git config --global http.proxy  $proxyUrl
        git config --global https.proxy $proxyUrl
        Write-OK "Proxy set successfully (effective immediately)"
        Write-Host ""
        Write-Host "  Protocol    = $ProxyType" -ForegroundColor Gray
        Write-Host "  http.proxy  = $proxyUrl" -ForegroundColor Gray
        Write-Host "  https.proxy = $proxyUrl" -ForegroundColor Gray
    }
    catch {
        Write-Err "Failed to set proxy: $($_.Exception.Message)"
        exit 1
    }
}

# ========== Unset Proxy ==========
function Unset-GitProxyInternal {
    Write-Info "Unsetting Git proxy..."

    try {
        git config --global --unset http.proxy  2>$null
        git config --global --unset https.proxy 2>$null
        Write-OK "Proxy unset successfully"
    }
    catch {
        Write-Err "Failed to unset proxy: $($_.Exception.Message)"
        exit 1
    }
}

# ========== Show Status ==========
function Show-GitProxyStatus {
    Write-Info "Current Git proxy configuration:"
    Write-Host ""
    Write-Host "  http.proxy  = $(git config --global --get http.proxy)"  -ForegroundColor Gray
    Write-Host "  https.proxy = $(git config --global --get https.proxy)" -ForegroundColor Gray
    Write-Host ""

    $httpProxy  = git config --global --get http.proxy
    if ($httpProxy) {
        Write-Info "Tip: Run 'git-proxy -t' to test connectivity"
    }
    else {
        Write-Warn "No proxy currently set"
    }
}

# ========== Main Logic ==========
Test-GitInstalled

# Show help if no args or -Help
if ($Help -or (-not $ProxyHost -and -not $Test -and -not $Set -and -not $Unset -and -not $Check)) {
    Show-Help
    exit 0
}

if ($Test) {
    Test-CurrentProxy
}
elseif ($Set) {
    Set-GitProxyInternal -ProxyHost $ProxyHost -ProxyPort $ProxyPort -ProxyType $ProxyType
}
elseif ($Unset) {
    Unset-GitProxyInternal
}
elseif ($Check) {
    Show-GitProxyStatus
}
elseif ($ProxyHost -or $ProxyPort) {
    Write-Err "Incomplete arguments: need -h <IP> -p <port> -T <type> -s"
    Show-Help
    exit 1
}