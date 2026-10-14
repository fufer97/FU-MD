#!/bin/bash
#
# 下载 Vditor 发行包，裁剪成 FU MD 需要的最小内核，放入 Sources/FUMD/Resources/editor/vditor/
# （仅依赖系统 curl/sed/tar）
#
# 版本钉死在 VDITOR_VERSION：仓库内已入库这份内核，正常情况下你不需要跑这个脚本；
# 只有升级 Vditor 时才跑，跑完请连同 VERSION 文件一起提交。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$SCRIPT_DIR/../Sources/FUMD/Resources/editor/vditor"
VDITOR_VERSION="4.0.0"

# 保留的 js 子目录：IR 即时渲染必需的部分（代码高亮、双语界面、图标、公式、解析器、图表）
KEEP_JS="highlight.js i18n icons katex lute mermaid"

TMPDIR_DL=$(mktemp -d)
trap '/bin/rm -rf "$TMPDIR_DL"' EXIT

echo "▶︎ 下载 Vditor ${VDITOR_VERSION}"
curl -fsSL "https://registry.npmjs.org/vditor/-/vditor-${VDITOR_VERSION}.tgz" -o "$TMPDIR_DL/vditor.tgz"
mkdir -p "$TMPDIR_DL/unpacked"
tar -xzf "$TMPDIR_DL/vditor.tgz" -C "$TMPDIR_DL/unpacked"
SRC="$TMPDIR_DL/unpacked/package"

[ -d "$SRC/dist" ] || { echo "❌ 发行包结构异常：找不到 package/dist" >&2; exit 1; }
[ -f "$SRC/LICENSE" ] || { echo "❌ 发行包里没有 LICENSE（MIT 许可正文必须随包分发）" >&2; exit 1; }

echo "▶︎ 裁剪并写入 $DEST"
/bin/rm -rf "$DEST"
mkdir -p "$DEST/dist"
/bin/cp -R "$SRC/dist/css" "$SRC/dist/images" "$DEST/dist/"
/bin/cp "$SRC/dist/index.css" "$SRC/dist/index.min.js" "$DEST/dist/"
mkdir -p "$DEST/dist/js"
for d in $KEEP_JS; do
  [ -d "$SRC/dist/js/$d" ] || { echo "❌ 发行包里缺少 dist/js/$d" >&2; exit 1; }
  /bin/cp -R "$SRC/dist/js/$d" "$DEST/dist/js/"
done

# 许可与版本：MIT 的 Notices 义务 + 后续升级可追溯
/bin/cp "$SRC/LICENSE" "$DEST/LICENSE"
printf '%s\n' "$VDITOR_VERSION" > "$DEST/VERSION"

echo "✅ 已就绪：${DEST}（Vditor ${VDITOR_VERSION}，已裁剪 $(ls "$SRC/dist/js" | grep -vc -E "^($(echo $KEEP_JS | tr ' ' '|'))$") 个未使用的渲染引擎）"
du -sh "$DEST"
