# Pitfalls

> Every trap we hit while building `git-proxy`. Each one cost time to debug — this list saves you from repeating the same mistakes.

---

## Table of contents

1. [PowerShell `$` in strings](#1-powershell--in-strings)
2. [SSH non-interactive shell PATH](#2-ssh-non-interactive-shell-path)
3. [PowerShell alias case-insensitivity](#3-powershell-alias-case-insensitivity)
4. [Windows Terminal: `wt.exe` direct invocation fails](#4-windows-terminal-wtexe-direct-invocation-fails)
5. [PowerShell UTF-8 BOM with Chinese comments](#5-powershell-utf-8-bom-with-chinese-comments)
6. [GitHub release assets can't be downloaded directly](#6-github-release-assets-cant-be-downloaded-directly)
7. [Chocolatey MSIX missing WinUI 2.8 framework](#7-chocolatey-msix-missing-winui-28-framework)
8. [360 Safe kernel-level self-protection](#8-360-safe-kernel-level-self-protection)
9. [PowerShell `$Host` is a reserved variable](#9-powershell-host-is-a-reserved-variable)
10. [Shell extension DLLs can't be deleted normally](#10-shell-extension-dlls-cant-be-deleted-normally)
11. [MoveFileEx requires elevated permissions for cross-drive](#11-movefileex-requires-elevated-permissions-for-cross-drive)
12. [GitHub API requires SHA for updates](#12-github-api-requires-sha-for-updates)

---

## 1. PowerShell `$` in strings

**Symptom**:
```powershell
$s = "export PATH=\$HOME/bin:\$PATH"
echo $s
# Result: export PATH=\C:\Users\Administrator/bin:\
# (Windows path on Linux!)
```

**Why**: PowerShell's escape rules interpret `\$HOME` differently than bash. Then when SSH'd to Linux, the result is a Windows path literal.

**Fix**: Always use file upload (`scp`) instead of remote `echo`. Or use here-strings without `$` literals:

```powershell
$content = @'
export PATH="$HOME/bin:$PATH"
'@
$content | ssh user@server "cat >> ~/.bashrc"
```

---

## 2. SSH non-interactive shell PATH

**Symptom**:
```bash
$ ssh user@server 'git-proxy -t'
[ERROR] Git not found. Please install: sudo apt install git
```

But `git` is clearly at `/usr/bin/git`.

**Why**: SSH non-interactive shells (without `-t`) don't source `~/.bashrc`. They get a minimal PATH from `/etc/environment` or `sshd_config`. Some Docker containers / minimal images have PATH that excludes `/usr/bin`.

**Fix**: Inside the script, set PATH explicitly:

```bash
# At the top of git-proxy.sh
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
```

Plus resolve git's absolute path so even PATH-wrangling doesn't matter:

```bash
GIT_CMD=""
for p in /usr/bin/git /usr/local/bin/git /bin/git; do
    [[ -x "$p" ]] && GIT_CMD="$p" && break
done
[[ -z "$GIT_CMD" ]] && GIT_CMD=$(command -v git 2>/dev/null)
```

---

## 3. PowerShell alias case-insensitivity

**Symptom**:
```powershell
param(
    [Alias("t")][switch]$Test,
    [Alias("T")][string]$ProxyType
)
# ParserError: AliasDeclaredMultipleTimes (for 't')
```

**Why**: PowerShell aliases are case-insensitive. `-t` and `-T` are the same identifier.

**Workaround**:
- Pick one casing and stick with it
- Use full names for the other parameter: `-ProxyType` instead of `-T`

```powershell
param(
    [Alias("t")][switch]$Test,
    [ValidateSet("http","https","socks5")][string]$ProxyType = "socks5"  # no -T alias
)
```

---

## 4. Windows Terminal: `wt.exe` direct invocation fails

**Symptom**:
```
C:\> wt
系统无法执行指定的程序。
```

**Why**: When running in a non-interactive session (SSH into Windows, service context, automation), the AppX activation context can't find a desktop to launch against.

**Fix**:
- For interactive use: log in via console or RDP, then `wt` works.
- For automation: use `cmd /c "start wt"` or AUMID:
  ```cmd
  explorer shell:AppsFolder\Microsoft.WindowsTerminal_8wekyb3d8bbwe!App
  ```

---

## 5. PowerShell UTF-8 BOM with Chinese comments

**Symptom**: Script throws `ParserError` on lines with Chinese characters, even though they look fine in the editor.

**Why**: PowerShell 5.1 expects files without BOM when using non-ASCII characters in some contexts, but `Write-Output "中文"` breaks when the file has mixed line endings.

**Fix**: Use English comments in `.ps1` files. Or use `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))` (no BOM).

---

## 6. GitHub release assets can't be downloaded directly

**Symptom**:
```
Error: 远程服务器返回错误: (401) 未授权
```
or
```
Timeout after 6.6 MB downloaded (file is actually 21 MB)
```

**Why**:
- `objects.githubusercontent.com` requires AWS-signed URLs (rotating)
- Direct `github.com/.../releases/download/...` is unreliable in some networks

**Fix**: Use `gh-proxy.org` proxy:
```
https://gh-proxy.org/https://github.com/<user>/<repo>/releases/download/<tag>/<file>
```

Verify with SHA256 from the GitHub release page.

---

## 7. Chocolatey MSIX missing WinUI 2.8 framework

**Symptom**: `choco install microsoft-windows-terminal` succeeds, but re-registering the AppX package fails:
```
HRESULT: 0x80073CF3
需要安装... Microsoft.UI.Xaml.2.8 (8.2305.5001.0)
```

**Why**: The Chocolatey package is a "skinny" MSIX — it doesn't bundle framework dependencies. WinUI 2.8 isn't on the system.

**Fix**: Download the **`*_Windows10_PreinstallKit.zip`** from GitHub releases. It contains:
- `Microsoft.UI.Xaml.2.8_8.x.x.x_xxx_x64__8wekyb3d8bbwe.appx`
- The terminal's `.msixbundle`

Install order matters:
```powershell
Add-AppxPackage Microsoft.UI.Xaml.2.8_x64.appx  # framework first
Add-AppxPackage *.msixbundle                    # then the app
```

---

## 8. 360 Safe kernel-level self-protection

**Symptom**: Can't stop 360 processes, can't delete 360 files. Even in safe mode, 4 DLLs refuse to delete because they're loaded by Explorer.

**Why**: 360 installs 8+ kernel drivers (`360netmon`, `360Hvm`, `360FsFlt`, etc.) that protect user-mode processes and files.

**Fix ladder**:
1. Safe mode (msconfig → 安全引导 → 网络)
2. `taskkill /F` for processes
3. `sc config ... start= disabled` for services/drivers
4. `rmdir /s /q` for directories
5. For shell-extension DLLs locked by Explorer: use `MoveFileEx` API with `MOVEFILE_DELAY_UNTIL_REBOOT`:
   ```powershell
   [FileMover]::DeleteOnReboot("C:\...\shell360ext64.dll")
   ```
   The kernel deletes it during boot, before any process can lock it.

---

## 9. PowerShell `$Host` is a reserved variable

**Symptom**:
```
A parameter cannot be found that accepts argument 'System.String'.
MissingArgument, ParameterBindingValidationException
```

**Why**: PowerShell has a built-in `$Host` automatic variable. When you write `[string]$Host`, the parser tries to bind the user's input to the existing `$Host`, not your parameter.

**Fix**: Rename your parameter:
```powershell
param(
    [Alias("h")][string]$ProxyHost,   # not $Host
    [Alias("p")][int]$ProxyPort
)
```

---

## 10. Shell extension DLLs can't be deleted normally

**Symptom**:
```
Access denied — file in use
```
Even when you have admin rights, even in safe mode.

**Why**: `explorer.exe` loads shell-extension DLLs at startup and holds an open handle to them. They're locked until Explorer exits.

**Fix**: Use the Windows API `MoveFileEx` with `MOVEFILE_DELAY_UNTIL_REBOOT`:

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class FileMover {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
    public const int MOVEFILE_DELAY_UNTIL_REBOOT = 0x4;
    public const int MOVEFILE_REPLACE_EXISTING = 0x1;
    public static bool DeleteOnReboot(string path) {
        return MoveFileEx(path, null, MOVEFILE_DELAY_UNTIL_REBOOT | MOVEFILE_REPLACE_EXISTING);
    }
}
"@

[FileMover]::DeleteOnReboot("C:\locked.dll")
Restart-Computer
```

The kernel marks the file for deletion in its boot-time `PendingFileRenameOperations` registry entry. Then deletes it **before** any user-mode process can lock it.

---

## 11. MoveFileEx requires elevated permissions for cross-drive

**Symptom**: `MoveFileEx` returns `false`, GetLastError says "Access denied".

**Why**: When source and destination are on different drives, MoveFileEx needs admin rights (it has to copy across volumes).

**Fix**: Run from elevated PowerShell. Or move to a path on the same drive first, then delete.

---

## 12. GitHub API requires SHA for updates

**Symptom**:
```
PUT /repos/.../contents/file → 409 Conflict
```

**Why**: When updating an existing file via the Contents API, you must include the current file's SHA in the body. Otherwise GitHub thinks you're trying to create a duplicate.

**Fix**:
```powershell
$existing = Invoke-RestMethod -Uri "https://api.github.com/repos/USER/REPO/contents/file" -Headers $headers
$body = @{
    message = "Update"
    content  = $base64
    branch   = "main"
    sha      = $existing.sha    # ← required for updates
} | ConvertTo-Json
```

For new files (first PUT), omit `sha`.

---

## Bonus: General debugging recipe

When something doesn't work and you don't know why:

```powershell
# 1. Run with verbose / debug output
ssh -v user@host ...
bash -x script.sh
git-proxy -v

# 2. Verify each link in the chain
# - Is the file there? ls -la
# - Is it executable? stat
# - Is it in PATH? which git-proxy
# - What is PATH actually? echo $PATH
# - Can it be called directly? ~/bin/git-proxy --help

# 3. Strip the chain to minimum
# - Replace complex command with: ls -la file && ./file arg1 arg2

# 4. Check OS-level stuff
# - Permissions: icacls on Windows, ls -la on Linux
# - Disk space: df -h
# - Locks: handle.exe (Windows), lsof (Linux)

# 5. Add tracing
# - PowerShell: Set-PSDebug -Trace 1
# - Bash: bash -x script.sh
# - Add Write-Output "DEBUG: var=$var" liberally
```