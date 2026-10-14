#!/usr/bin/env bash
#
# 一条命令发版：改版本号 → 构建 + 打包 dmg → 提交推送 → 发布到 GitHub。
#
#   Scripts/release.sh 0.2 "这次改了什么"
#   Scripts/release.sh 0.2 "说明" --dry-run     # 只改版本号并检查，不构建不发布
#
# 安装包发到 fufer97/FU-MD 的 Releases，附件名 FU-MD-<版本>.dmg。
set -euo pipefail

REPO="fufer97/FU-MD"
VERSION="${1:-}"
NOTES="${2:-}"
DRY=""
[ "${3:-}" = "--dry-run" ] && DRY=1

if [ -z "$VERSION" ]; then
  echo "用法：Scripts/release.sh <版本号> [\"这次改了什么\"] [--dry-run]"
  echo "例：  Scripts/release.sh 0.2 \"修复导出公式字体回退\""
  exit 1
fi

cd "$(dirname "$0")/.."   # → 项目根目录

# gh 优先用带代理的封装：本机 github.com 有时需要走本地代理，封装脚本会自动判断
GH="gh"
[ -x "$HOME/.local/bin/github" ] && GH="$HOME/.local/bin/github"

# 1) 版本号（单一来源：Sources/FUMD/AppVersion.swift）
/usr/bin/sed -i '' -E "s/current = \"[0-9.]+\"/current = \"$VERSION\"/" Sources/FUMD/AppVersion.swift
echo "版本号 → $(grep -o 'current = "[0-9.]*"' Sources/FUMD/AppVersion.swift)"

if [ -n "$DRY" ]; then
  echo "（dry-run：只改了版本号，未构建、未发布）"
  exit 0
fi

# 2) 构建 + 出包（先构建再提交：构建失败就不会推进版本号提交）
Scripts/build-app.sh dmg

# 3) 提交并推送到源码仓库
git add -A
if git diff --cached --quiet; then
  echo "▶︎ 工作区无改动，跳过提交"
else
  git commit -m "发布 $VERSION${NOTES:+：$NOTES}"
fi
git push origin main

# 4) 发布到 GitHub
# 附件名先改好再上传：GitHub 会把空格换成点（FU.MD.dmg），不好认也不好念
/bin/cp "build/FU-MD.dmg" "/tmp/FU-MD-$VERSION.dmg"
"$GH" release create "v$VERSION" "/tmp/FU-MD-$VERSION.dmg" \
  --repo "$REPO" \
  --title "FU MD $VERSION" \
  --notes "${NOTES:-见提交记录}"

echo
echo "✓ 已发布：https://github.com/$REPO/releases/tag/v$VERSION"
