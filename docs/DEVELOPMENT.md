# Development Log

> How `git-proxy` was built, version by version, with the reasoning behind every change.

---

## v1.0 鈥?Initial Windows PowerShell version

**Goal**: Replace long `git config --global http.proxy socks5://...` commands with a one-liner.

**Why PowerShell first**: Target platform is Windows Terminal, which defaults to PowerShell.

**Features**:
- `-h <IP> -p <PORT> -s` 鈫?set SOCKS5 proxy
- `-u` 鈫?unset
- `-c` 鈫?check status
- `-Help` 鈫?help

**Code size**: 188 lines (with all comments).

**Key decisions**:
1. **SOCKS5 only** 鈥?most flexible; covers HTTP/HTTPS git repos
2. **`--global` flag** 鈥?applies to all repos, matches user expectation
3. **Validate inputs** (IP regex, port range) 鈥?fail fast on typos
4. **Connectivity test** 鈥?TCP connect with 2-second timeout, runs in `-c`

---

## v1.1 鈥?Add HTTP/HTTPS proxy support

**User feedback**: "I use Clash, which only has HTTP proxy. Can you add HTTP?"

**Implementation**:
- Added `-t` / `-ProxyType` parameter with `[ValidateSet("http","https","socks5")]`
- Default still `socks5` for backward compatibility
- Same URL prefix scheme: `git config --global http.proxy <type>://host:port`

**Why URL prefix matters**:
- git's `--global` config stores the literal URL
- For SOCKS5: `socks5://host:port`
- For HTTP: `http://host:port` (Git/curl will use HTTP CONNECT for HTTPS)
- For HTTPS proxy: `https://host:port` (rare, double-encrypted)

**Bug encountered**: PowerShell aliases are **case-insensitive**, so `-t` and `-T` collide. Resolved by removing `-T` alias (use full `-ProxyType`).

---

## v1.2 鈥?Add `-t` test mode

**User feedback**: "I want to quickly check if my proxy still works, without typing all params."

**Behavior**:
- `git-proxy -t` alone 鈫?test current `http.proxy` / `https.proxy`
- TCP connect to proxy host:port (2s timeout)
- For HTTP/HTTPS proxies, also do an actual HTTP probe to `github.com` via `curl`

**Why not test external connectivity?** A proxy being reachable doesn't mean it can reach GitHub. We layer TCP + HTTP tests.

---

## v1.3 鈥?Make it globally callable (Windows)

**Problem**: User wants to run `git-proxy` from any directory, in any terminal (CMD, PowerShell, Git Bash).

**Approach 1 鈥?PowerShell profile function** (PowerShell-only):
```powershell
# In $PROFILE
function git-proxy { & "D:\Windows_Terminal\git-proxy.ps1" @args }
```
Limitation: only works in PowerShell.

**Approach 2 鈥?`.cmd` wrapper + PATH** (recommended, works everywhere):
```cmd
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Windows_Terminal\git-proxy.ps1" %*
```
Then add `D:\Windows_Terminal` to user PATH.

**Chosen**: Approach 2, plus added `Set-Alias gpx git-proxy` for the PowerShell side.

**Implementation detail**: Adding to PATH requires either:
- `sysdm.cpl` GUI (permanent)
- PowerShell `[Environment]::SetEnvironmentVariable("Path", ..., "User")` (permanent, scriptable)
- New terminal session to take effect (PATH changes don't propagate to running shells)

---

## v1.4 鈥?Debian/Linux bash port

**Driver**: User has a remote Debian 13 server (10.0.0.10), wants the same convenience there.

**Port from PowerShell 鈫?bash**:
- Same CLI surface: `-h`, `-p`, `-T`, `-t`, `-s`, `-u`, `-c`
- Different internals: `git config --global` works the same; colors use ANSI escapes; connectivity test uses `bash -c "echo > /dev/tcp/..."` instead of `System.Net.Sockets.TcpClient`

**Distribution challenges**:
1. No `ssh-copy-id` on Windows for sending the script
2. User's `yao` user is in `sudo` group, but SSH sessions can't easily use `sudo` (no TTY for password)
3. Solution: install to `~/bin/`, add PATH to `~/.bashrc` and `~/.profile`

**First bug**: `command -v git` failed inside script. Root cause: SSH non-interactive shell PATH doesn't include `/usr/bin`.

**Fix**: Inside script, `export PATH="/usr/local/sbin:...:/usr/bin:/sbin:/bin:$PATH"` before anything else. Plus hardcoded lookup for git at `/usr/bin/git` etc.

---

## v1.5 鈥?`.bashrc` corruption disaster (and recovery)

**What happened**: While deploying, a PowerShell SSH command contained `\$HOME` which got **escaped** in transit:

```
PowerShell intent:     echo 'export PATH=\$HOME/bin:\$PATH'
PowerShell result:     export PATH=\C:\Users\Administrator/bin:\
After SSH:             export PATH=\C:\Users\Administrator/bin:\
In .bashrc:            export PATH=\C:\Users\Administrator/bin:\   鈫?BUG
```

**Impact**: User's `~/.bashrc` had **Windows paths** in Linux `$PATH`. Login shell couldn't find anything in `~/bin/`.

**Recovery**: Wrote `fix-bashrc.sh` that:
1. Backs up `.bashrc` / `.profile`
2. Greps out lines containing `Administrator`
3. Appends correct `export PATH="$HOME/bin:$PATH"`

**Lesson documented**: Never use `echo ... >> ~/.bashrc` from PowerShell via SSH. Always upload a script file via `scp` then execute.

---

## v2.0 鈥?Project extraction (this repo)

**Why split into separate repo**: The script is useful on its own; bundling it inside `windows-terminal` makes the repo confusing. Also, this repo can be a showcase for "writing a small CLI tool end-to-end with pitfalls documented".

**Structure**:
```
git-proxy/
鈹溾攢鈹€ README.md
鈹溾攢鈹€ LICENSE
鈹溾攢鈹€ windows/    # PowerShell + CMD wrapper
鈹溾攢鈹€ debian/     # bash + installer
鈹溾攢鈹€ docs/       # this file + PITFALLS
鈹斺攢鈹€ examples/   # real-world configs
```

---

## Roadmap

| Version | Feature | Status |
|---------|---------|--------|
| v2.0 | Initial public release | 鉁?Done |
| v2.1 | `--list` to show multiple profiles | Planned |
| v2.2 | macOS support (zsh variant) | Planned |
| v2.3 | Config file (`~/.git-proxy.toml`) for saved profiles | Planned |

---

## Architecture decisions

### Why three files per platform?

```
windows/git-proxy.ps1     # Core logic (PowerShell)
windows/git-proxy.cmd     # CMD shim (5 lines)
debian/git-proxy.sh       # Core logic (bash)
```

This separation lets you:
- Use the core script directly in advanced workflows (`powershell -File git-proxy.ps1 ...`)
- Drop the `.cmd` shim in any PATH directory for global access
- Source the bash script in other tools if needed

### Why no shared config file?

`~/.gitconfig` IS the config file. Git's native `http.proxy` / `https.proxy` keys are the contract. We just read/write them. Adding our own format would be redundant and create sync issues.

### Why not use environment variables (`HTTPS_PROXY`)?

Pros of env vars:
- One variable covers all tools (curl, wget, pip, npm)
- Already widely understood

Cons:
- Affects all applications (including SSH itself, which can break things!)
- Less Git-specific 鈥?git has built-in proxy support that integrates with credential helpers, SSL verification, etc.

We chose the Git-native route. Users who want env-var approach can do `export http_proxy=...` separately.

### Why not support `http.proxyAuthMethod`?

Git supports many authentication methods for proxies (basic, digest, negotiate). We deliberately don't expose these 鈥?adding them would make the CLI surface much larger for the 99% case. Advanced users can `git config --global http.proxyAuthMethod 'basic'` manually.

---

## Test matrix (manually verified)

| Platform | Shell | Proxy type | Result |
|----------|-------|-----------|--------|
| Windows 10 | PowerShell 5.1 | SOCKS5 | 鉁?|
| Windows 10 | PowerShell 5.1 | HTTP | 鉁?|
| Windows 10 | CMD | SOCKS5 | 鉁?|
| Debian 13 | bash 5.2 | SOCKS5 | 鉁?|
| Debian 13 | bash 5.2 | HTTP | 鉁?|
| Debian 13 | SSH non-interactive | SOCKS5 | 鉁?|
| Debian 13 | Login shell | SOCKS5 | 鉁?|

---

## Lessons learned

1. **Validate, validate, validate** 鈥?input regex catches typos before they corrupt `.gitconfig`
2. **Two protocol tests** (TCP + HTTP) catch more bugs than one
3. **PATH is a hidden dependency** 鈥?always make scripts self-sufficient
4. **String escaping across shells** 鈥?use file upload, not echo+append
5. **Document every pitfall** 鈥?next person (or future-you) will thank you