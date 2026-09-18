#!/bin/bash
# install.sh — One-shot installer for git-proxy on Debian/Ubuntu
#
# Usage:
#   bash install.sh           # install to ~/bin/git-proxy
#   bash install.sh /usr/local/bin  # install system-wide (needs sudo)
set -e

INSTALL_DIR="${1:-$HOME/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== git-proxy installer ==="
echo "Source: $SCRIPT_DIR/git-proxy.sh"
echo "Target: $INSTALL_DIR/git-proxy"
echo ""

# 1. Create install dir
mkdir -p "$INSTALL_DIR"

# 2. Copy script
cp "$SCRIPT_DIR/git-proxy.sh" "$INSTALL_DIR/git-proxy"
chmod +x "$INSTALL_DIR/git-proxy"

# 3. Ensure PATH is set in shell rc files (only if installing to ~/bin)
if [[ "$INSTALL_DIR" == "$HOME"* ]]; then
    for rc in "$HOME/.bashrc" "$HOME/.profile"; do
        if [[ -f "$rc" ]] && ! grep -q "$INSTALL_DIR" "$rc"; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$rc"
            echo "Added PATH export to $rc"
        fi
    done
fi

# 4. Test
echo ""
echo "=== Verifying install ==="
"$INSTALL_DIR/git-proxy" --help | head -3
echo ""

if [[ "$INSTALL_DIR" == "$HOME"* ]]; then
    echo "✅ Installed to $INSTALL_DIR/git-proxy"
    echo ""
    echo "To use it in your CURRENT shell:"
    echo "    source ~/.bashrc"
    echo "Or open a new terminal."
    echo ""
    echo "Quick test:"
    echo "    git-proxy --help"
else
    echo "✅ Installed to $INSTALL_DIR/git-proxy (system-wide)"
    echo ""
    echo "Quick test:"
    echo "    git-proxy --help"
fi