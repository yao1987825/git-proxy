# Git Proxy

> Cross-platform Git SOCKS5 / HTTP / HTTPS proxy manager.
> One command to set, test, and unset your Git proxy — works on Windows PowerShell and Debian/Linux bash.

[![GitHub](https://img.shields.io/badge/GitHub-yao1987825-blue)](https://github.com/yao1987825)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-blue)]()

---

## Features

- ✅ **Set proxy** in one command (`-h IP -p PORT -s`)
- ✅ **Three protocols**: SOCKS5, HTTP, HTTPS
- ✅ **Test connectivity** (`-t`) — TCP probe + optional HTTP probe
- ✅ **Unset** cleanly (`-u`)
- ✅ **Check status** (`-c`)
- ✅ **Cross-platform**: Windows PowerShell + Debian/Linux bash
- ✅ **No system env vars** — only modifies `~/.gitconfig`
- ✅ **PATH-resilient** — works even with minimal SSH non-interactive shell PATH

---

## Quick Start

### Windows (PowerShell)

```powershell
# Set SOCKS5 proxy (default)
git-proxy -h 127.0.0.1 -p 1080 -s

# Set HTTP proxy (e.g. Clash default port)
git-proxy -h 127.0.0.1 -p 7890 -ProxyType http -s

# Test current proxy
git-proxy -t

# Unset
git-proxy -u
```

### Debian / Ubuntu (bash)

```bash
# Same syntax
git-proxy -h 127.0.0.1 -p 1080 -s
git-proxy -t
git-proxy -u
```

---

## Installation

### Windows

```powershell
# Option 1: Clone this repo
git clone https://github.com/yao1987825/git-proxy.git
cd git-proxy\windows
# Add the windows/ folder to your PATH (or copy scripts to a folder already in PATH)

# Option 2: Use the CMD shim from any folder in PATH
# (see windows/global-cli-setup.md for details)
```

### Debian / Ubuntu

```bash
# Clone and install in one shot
git clone https://github.com/yao1987825/git-proxy.git
cd git-proxy/debian
bash install.sh
```

Or manually:

```bash
mkdir -p ~/bin
cp git-proxy.sh ~/bin/git-proxy
chmod +x ~/bin/git-proxy

# Make sure ~/bin is in PATH (add to ~/.bashrc and ~/.profile):
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.profile
```

---

## Usage Reference

### Parameters

| Short | Full | Type | Description |
|-------|------|------|-------------|
| `-h` | `-ProxyHost` | string | Proxy server IP or hostname |
| `-p` | `-ProxyPort` | int | Proxy port (1-65535) |
| `-T` | `-ProxyType` | string | `http` \| `https` \| `socks5` (default: socks5) |
| `-t` | `-Test` | switch | Test current proxy connectivity |
| `-s` | `-Set` | switch | Apply proxy settings to Git |
| `-u` | `-Unset` | switch | Remove Git proxy |
| `-c` | `-Check` | switch | Show current proxy status |
| — | `-Help` | switch | Show help |

### Examples

```bash
# SOCKS5 (recommended for general use)
git-proxy -h 127.0.0.1 -p 1080 -s

# SOCKS5 with explicit type
git-proxy -h 127.0.0.1 -p 10808 -ProxyType socks5 -s

# HTTP proxy (e.g. Clash on default port 7890)
git-proxy -h 127.0.0.1 -p 7890 -ProxyType http -s

# HTTPS proxy
git-proxy -h proxy.example.com -p 8080 -ProxyType https -s

# Test: probe TCP + HTTP (for http/https) reachability
git-proxy -t

# Quick check
git-proxy -c

# Unset
git-proxy -u
```

---

## Repository Layout

```
git-proxy/
├── README.md                   This file
├── LICENSE                     MIT License
├── .gitignore
├── windows/
│   ├── git-proxy.ps1           Windows PowerShell core script
│   ├── git-proxy.cmd           CMD wrapper for global PATH access
│   └── global-cli-setup.md     How to make `git-proxy` callable everywhere
├── debian/
│   ├── git-proxy.sh            Debian/Linux bash core script
│   ├── install.sh              One-line installer
│   └── fix-bashrc.sh           Repair tool for corrupted .bashrc
├── examples/
│   ├── clash.md                Common proxy tool setups (Clash, V2Ray, etc.)
│   └── ssh-tunnel.md           SSH-based dynamic SOCKS5 proxy
└── docs/
    ├── DEVELOPMENT.md          Full development log
    └── PITFALLS.md             Every trap we hit (so you don't have to)
```

---

## Compatibility

| Platform | Shell | Git | Notes |
|----------|-------|-----|-------|
| Windows 10 1809+ | PowerShell 5.1 | any | Default |
| Windows 10/11 | PowerShell 7+ | any | Recommended |
| Debian 11+ | bash 5+ | 2.30+ | Default |
| Ubuntu 20.04+ | bash 5+ | 2.25+ | Tested |
| Other Linux | bash 4+ | 2.20+ | Should work; PRs welcome |

---

## Contributing

Issues and PRs welcome! See [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) for the design rationale.

---

## License

MIT — see [`LICENSE`](LICENSE).

---

## See Also

- [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) — How this project was built, step by step
- [`docs/PITFALLS.md`](docs/PITFALLS.md) — 10+ bugs and traps documented
- [Git's official proxy docs](https://git-scm.com/docs/git-config#Documentation/git-config.txt-httpproxy)
- [SOCKS5 protocol (RFC 1928)](https://datatracker.ietf.org/doc/html/rfc1928)