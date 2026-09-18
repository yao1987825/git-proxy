@echo off
rem git-proxy.cmd - Git SOCKS5 proxy wrapper
rem 用法: git-proxy -h IP -p PORT -s
rem       git-proxy -u
rem       git-proxy -c
rem       git-proxy -Help

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Windows_Terminal\git-proxy.ps1" %*