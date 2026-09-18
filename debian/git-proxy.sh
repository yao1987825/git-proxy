#!/bin/bash
# git-proxy - Git Proxy Manager for Debian/Linux (HTTP / HTTPS / SOCKS5)
#
# Usage:
#   git-proxy -h <IP> -p <PORT> -T <TYPE> -s      Set proxy (apply immediately)
#   git-proxy -t                                    Test current proxy connectivity
#   git-proxy -u                                    Unset proxy
#   git-proxy -c                                    Show current proxy status
#   git-proxy --help                                Show help
#
# Examples:
#   git-proxy -h 127.0.0.1 -p 1080 -s                       # Default: SOCKS5
#   git-proxy -h 127.0.0.1 -p 1080 -T socks5 -s
#   git-proxy -h 127.0.0.1 -p 7890 -T http -s               # HTTP proxy
#   git-proxy -h proxy.example.com -p 8080 -T https -s      # HTTPS proxy
#   git-proxy -t                                            # Test current proxy
#   git-proxy -u                                            # Unset proxy

set -e

# ========== Color Functions ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ========== Help ==========
show_help() {
cat <<'HELP'
Git Proxy Manager (HTTP / HTTPS / SOCKS5) - Debian/Linux

Usage:
    git-proxy -h <IP> -p <PORT> -T <TYPE> -s      Set proxy
    git-proxy -t                                    Test current proxy
    git-proxy -u                                    Unset proxy
    git-proxy -c                                    Show current proxy status
    git-proxy --help                                Show this help

Parameters:
    -h, --host=IP         Proxy server IP or hostname
    -p, --port=PORT       Proxy port
    -T, --type=TYPE       Proxy type: http | https | socks5 (default: socks5)
    -t, --test            Test current proxy connectivity
    -s, --set             Apply proxy settings to Git
    -u, --unset           Unset Git proxy
    -c, --check           Show current proxy status
    --help                Show this help

Supported Protocols:
    socks5    SOCKS5 proxy (recommended)
    http      HTTP proxy  (e.g. Clash default port 7890)
    https     HTTPS proxy (less common)

Examples:
    # Set SOCKS5 proxy (default)
    git-proxy -h 127.0.0.1 -p 1080 -s
    git-proxy -h 127.0.0.1 -p 10808 -T socks5 -s

    # Set HTTP proxy (Clash default port)
    git-proxy -h 127.0.0.1 -p 7890 -T http -s

    # Set HTTPS proxy
    git-proxy -h proxy.example.com -p 8080 -T https -s

    # Test current proxy connectivity
    git-proxy -t

    # Unset proxy
    git-proxy -u

Notes:
    - Only modifies git config (global ~/.gitconfig)
    - Sets both http.proxy and https.proxy
    - Apply takes effect immediately
    - SOCKS5 needs: apt install git (Debian 11+ has built-in support)
HELP
}

# ========== Check Git ==========
# SSH non-interactive shell PATH may not include /usr/bin
# Ensure git is found regardless of how the script was invoked
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

GIT_CMD=""
test_git_installed() {
    # Try common locations first (fastest, most reliable)
    for p in /usr/bin/git /usr/local/bin/git /bin/git; do
        if [[ -x "$p" ]]; then
            GIT_CMD="$p"
            return 0
        fi
    done

    # Fall back to command -v
    GIT_CMD=$(command -v git 2>/dev/null)
    if [[ -n "$GIT_CMD" && -x "$GIT_CMD" ]]; then
        return 0
    fi

    err "Git not found. Please install: sudo apt install git"
    exit 1
}

# ========== Test Current Proxy ==========
test_current_proxy() {
    info "Testing current Git proxy connectivity..."
    echo ""

    local http_proxy_url=$($GIT_CMD config --global --get http.proxy 2>/dev/null || echo "")
    local https_proxy_url=$($GIT_CMD config --global --get https.proxy 2>/dev/null || echo "")

    if [[ -z "$http_proxy_url" && -z "$https_proxy_url" ]]; then
        warn "No proxy currently set. Use -h <IP> -p <PORT> -s to set one."
        return
    fi

    test_one_proxy() {
        local name="$1"
        local url="$2"
        echo -e "  ${GRAY}Testing $name = $url ...${NC}"

        # Parse: protocol://host:port
        if [[ "$url" =~ ^(https?|socks5)://([^:]+):([0-9]+)$ ]]; then
            local proto="${BASH_REMATCH[1]}"
            local host="${BASH_REMATCH[2]}"
            local port="${BASH_REMATCH[3]}"

            # TCP connectivity test (2-second)
            if timeout 2 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
                ok "    [REACHABLE]  ${proto}://${host}:${port}"

                # HTTP/SOCKS5 handshake test for http/https proxies
                if [[ "$proto" == "http" || "$proto" == "https" ]]; then
                    if command -v curl >/dev/null 2>&1; then
                        if curl --proxy "$url" --connect-timeout 5 -s -o /dev/null -w "%{http_code}" http://www.github.com 2>/dev/null | grep -qE "^(200|301|302)$"; then
                            ok "    [HTTP OK]    github.com reachable via proxy"
                        else
                            warn "    [HTTP FAIL]  github.com NOT reachable via proxy"
                        fi
                    else
                        warn "    [SKIP HTTP]  curl not installed"
                    fi
                fi
            else
                warn "    [UNREACHABLE] ${proto}://${host}:${port}"
            fi
        else
            warn "    [SKIP]       Unrecognized URL format: $url"
        fi
        echo ""
    }

    [[ -n "$http_proxy_url" ]]  && test_one_proxy "http.proxy"  "$http_proxy_url"
    [[ -n "$https_proxy_url" ]] && test_one_proxy "https.proxy" "$https_proxy_url"
}

# ========== Set Proxy ==========
set_proxy() {
    local host="$1"
    local port="$2"
    local type="${3:-socks5}"

    if [[ -z "$host" || -z "$port" ]]; then
        err "Setting proxy requires -h <IP> and -p <port>"
        show_help
        exit 1
    fi

    # Validate IP / domain
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    local domain_regex='^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    if ! [[ "$host" =~ $ip_regex || "$host" =~ $domain_regex ]]; then
        err "Invalid proxy host: $host"
        exit 1
    fi

    # Validate port
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        err "Invalid port: $port (range 1-65535)"
        exit 1
    fi

    # Validate type
    if [[ ! "$type" =~ ^(http|https|socks5)$ ]]; then
        err "Invalid proxy type: $type (must be: http, https, socks5)"
        exit 1
    fi

    local proxy_url="${type}://${host}:${port}"

    info "Setting $type proxy: $proxy_url"

    $GIT_CMD config --global http.proxy  "$proxy_url"
    $GIT_CMD config --global https.proxy "$proxy_url"

    ok "Proxy set successfully (effective immediately)"
    echo ""
    echo -e "  ${GRAY}Protocol    = ${type}${NC}"
    echo -e "  ${GRAY}http.proxy  = ${proxy_url}${NC}"
    echo -e "  ${GRAY}https.proxy = ${proxy_url}${NC}"
}

# ========== Unset Proxy ==========
unset_proxy() {
    info "Unsetting Git proxy..."
    $GIT_CMD config --global --unset http.proxy  2>/dev/null || true
    $GIT_CMD config --global --unset https.proxy 2>/dev/null || true
    ok "Proxy unset successfully"
}

# ========== Show Status ==========
show_status() {
    info "Current Git proxy configuration:"
    echo ""
    echo -e "  ${GRAY}http.proxy  = $($GIT_CMD config --global --get http.proxy)${NC}"
    echo -e "  ${GRAY}https.proxy = $($GIT_CMD config --global --get https.proxy)${NC}"
    echo ""

    local http_proxy_url=$($GIT_CMD config --global --get http.proxy 2>/dev/null || echo "")
    if [[ -n "$http_proxy_url" ]]; then
        info "Tip: Run 'git-proxy -t' to test connectivity"
    else
        warn "No proxy currently set"
    fi
}

# ========== Parse Args ==========
PROXY_HOST=""
PROXY_PORT=""
PROXY_TYPE="socks5"
DO_SET=0
DO_UNSET=0
DO_CHECK=0
DO_TEST=0
DO_HELP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host)
            PROXY_HOST="$2"
            shift 2
            ;;
        -h=*|--host=*)
            PROXY_HOST="${1#*=}"
            shift
            ;;
        -p|--port)
            PROXY_PORT="$2"
            shift 2
            ;;
        -p=*|--port=*)
            PROXY_PORT="${1#*=}"
            shift
            ;;
        -T|--type)
            PROXY_TYPE="$2"
            shift 2
            ;;
        -T=*|--type=*)
            PROXY_TYPE="${1#*=}"
            shift
            ;;
        -t|--test)
            DO_TEST=1
            shift
            ;;
        -s|--set)
            DO_SET=1
            shift
            ;;
        -u|--unset)
            DO_UNSET=1
            shift
            ;;
        -c|--check)
            DO_CHECK=1
            shift
            ;;
        --help|-H)
            DO_HELP=1
            shift
            ;;
        *)
            err "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# ========== Main Logic ==========
test_git_installed

if [[ $DO_HELP -eq 1 || ($DO_SET -eq 0 && $DO_UNSET -eq 0 && $DO_CHECK -eq 0 && $DO_TEST -eq 0 && -z "$PROXY_HOST") ]]; then
    show_help
    exit 0
fi

if [[ $DO_TEST -eq 1 ]]; then
    test_current_proxy
elif [[ $DO_SET -eq 1 ]]; then
    set_proxy "$PROXY_HOST" "$PROXY_PORT" "$PROXY_TYPE"
elif [[ $DO_UNSET -eq 1 ]]; then
    unset_proxy
elif [[ $DO_CHECK -eq 1 ]]; then
    show_status
elif [[ -n "$PROXY_HOST" || -n "$PROXY_PORT" ]]; then
    err "Incomplete arguments: need -h <IP> -p <port> -T <type> -s"
    show_help
    exit 1
fi