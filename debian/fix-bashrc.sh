#!/bin/bash
# 修复 .bashrc 和 .profile

echo "=== 原始 .bashrc (末尾) ==="
tail -5 ~/.bashrc

echo ""
echo "=== 修复中... ==="

# 备份
cp ~/.bashrc ~/.bashrc.bak
cp ~/.profile ~/.profile.bak

# 删除包含 Administrator 的行
grep -v 'Administrator' ~/.bashrc > /tmp/bashrc.new
mv /tmp/bashrc.new ~/.bashrc

# 添加正确的 PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.profile

echo "=== 修复后 .bashrc (末尾) ==="
tail -5 ~/.bashrc

echo ""
echo "=== 修复后 .profile (末尾) ==="
tail -3 ~/.profile

echo ""
echo "=== 测试 git-proxy 是否能找到 ==="
~/bin/git-proxy --help | head -3