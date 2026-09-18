# git-proxy global setup on Windows

> Make `git-proxy` callable from any directory, in any terminal (CMD / PowerShell / Git Bash).

---

## Recommended: `.cmd` wrapper + PATH

### Step 1 — Create wrapper

Save this file as `git-proxy.cmd` anywhere in your PATH (e.g. `D:\Tools\` or `%USERPROFILE%\bin\`):

```cmd
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\path\to\git-proxy.ps1" %*
```

> Replace `D:\path\to\git-proxy.ps1` with the actual path to your `git-proxy.ps1`.

### Step 2 — Add to PATH

**Option A: GUI**
1. `Win + R` → `sysdm.cpl` → Enter
2. "Advanced" tab → "Environment Variables"
3. Under "User variables", select `Path` → Edit
4. "New" → paste your wrapper folder (e.g. `D:\Tools`)
5. OK → OK → OK

**Option B: PowerShell (scriptable)**
```powershell
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = "$currentPath;D:\Tools"
[Environment]::SetEnvironmentVariable("Path", $newPath", "User")
```

### Step 3 — Test

**Open a new terminal** (changes don't propagate to running shells):

```cmd
git-proxy -Help
git-proxy -h 127.0.0.1 -p 1080 -s
```

---

## Alternative: PowerShell profile alias (PowerShell-only)

Edit `$PROFILE`:

```powershell
notepad $PROFILE
```

Add:

```powershell
function git-proxy {
    & "D:\path\to\git-proxy.ps1" @args
}
Set-Alias gpx git-proxy
```

Reload:

```powershell
. $PROFILE
```

Now use:

```powershell
git-proxy -h 127.0.0.1 -p 1080 -s
gpx -u     # short alias
```

---

## Why both?

| Terminal | `git-proxy.cmd` (PATH) | PowerShell alias |
|----------|------------------------|------------------|
| CMD | ✅ | ❌ |
| PowerShell | ✅ | ✅ |
| Git Bash | ✅ | ❌ |
| VS Code terminal | depends on shell | depends on shell |

Use `.cmd` + PATH for maximum compatibility. Add the PowerShell alias if you want a short alias (`gpx`).

---

## Verification

```powershell
# CMD
where git-proxy

# PowerShell
Get-Command git-proxy
```

Both should return the path to your wrapper / script.