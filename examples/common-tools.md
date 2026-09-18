# Clash

[Clash](https://github.com/Dreamacro/clash) (and forks like Clash Verge, Clash for Windows) default ports:

| Type | Port | URL format |
|------|------|-----------|
| HTTP | 7890 | `http://127.0.0.1:7890` |
| SOCKS5 | 7891 | `socks5://127.0.0.1:7891` |

## Set with git-proxy

```bash
# HTTP (Clash default)
git-proxy -h 127.0.0.1 -p 7890 -ProxyType http -s

# SOCKS5
git-proxy -h 127.0.0.1 -p 7891 -s

# Test
git-proxy -t
```

## Enable system proxy (optional)

If you also want curl/wget/etc to use the proxy:

**Windows (CMD)**:
```cmd
set http_proxy=http://127.0.0.1:7890
set https_proxy=http://127.0.0.1:7890
```

**Linux/macOS (bash)**:
```bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
```

⚠️ Setting `http_proxy` env var will affect SSH too (unless you add it to `~/.ssh/config`'s `ProxyCommand` exclusions). Use with care.

---

# V2Ray / V2RayN

| Type | Port (V2RayN default) |
|------|----------------------|
| SOCKS5 | 10808 |
| HTTP | 10809 |

```bash
git-proxy -h 127.0.0.1 -p 10808 -s
git-proxy -t
```

---

# Shadowsocks / shadowsocks-rust

Most ss clients only expose SOCKS5. Typical port: 1080.

```bash
git-proxy -h 127.0.0.1 -p 1080 -s
```

---

# SSH dynamic port forwarding (no client needed)

If you have SSH access to a remote server, you can use it as a SOCKS5 proxy:

```bash
# Start dynamic SOCKS5 proxy on local port 1080 via SSH
ssh -D 1080 -f -N user@remote-server

# Then tell git-proxy
git-proxy -h 127.0.0.1 -p 1080 -s
```

`-D 1080` = dynamic SOCKS5 proxy
`-f -N` = background, no command (just tunnel)

To stop:
```bash
# Find and kill
ps aux | grep "ssh -D"
kill <pid>
# Or, in PowerShell
Get-Process ssh | Where-Object {$_.CommandLine -like "*-D 1080*"} | Stop-Process
```

---

# WireGuard

WireGuard doesn't natively do SOCKS5. You need a WireGuard → SOCKS5 bridge. Easiest:
1. Set up WireGuard tunnel to your VPS
2. On the VPS, run `dante` or `3proxy` to expose SOCKS5
3. Point git-proxy at the VPS's SOCKS5 port

Not covered here — search for "wireguard dante socks5" for tutorials.

---

# System-wide git config

`git-proxy` only modifies `~/.gitconfig` (user scope). If you need machine-wide config:

```bash
# Linux
sudo git config --system http.proxy socks5://127.0.0.1:1080

# Windows (admin CMD)
git config --system http.proxy socks5://127.0.0.1:1080
```

Or use `git config --local` inside a repo for repo-specific settings.