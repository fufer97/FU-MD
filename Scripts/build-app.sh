#!/bin/bash
#
# FU MD 构建脚本：swift build -c release → 组装 FU MD.app → ad-hoc 签名（可选出 dmg）
#
#   Scripts/build-app.sh            # 编译并打包 build/FU MD.app
#   Scripts/build-app.sh run        # 打包后启动
#   Scripts/build-app.sh dmg        # 打包并生成 build/FU-MD.dmg
#
# 本机没有完整 Xcode，只能用 CommandLineTools 的 Swift 工具链。这个环境有两处必须绕开的坑：
#   1) SwiftPM 默认把编译包在 sandbox-exec 里跑，本机不允许应用进程沙箱 → 必须加 --disable-sandbox
#   2) 默认的编译缓存/临时目录在沙箱外，会被拒写 → 统一改到 ~/.cache/fumd
set -euo pipefail
cd "$(dirname "$0")/.."

export TMPDIR="$HOME/.cache/fumd/tmp"
export CLANG_MODULE_CACHE_PATH="$HOME/.cache/fumd/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$HOME/.cache/fumd/swift-module-cache"
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"

APP_DISPLAY_NAME="FU MD"
APP="build/${APP_DISPLAY_NAME}.app"
MODE="${1:-build}"

# 版本号单一来源：Sources/FUMD/AppVersion.swift
APP_VERSION=$(grep -o 'current = "[0-9.]*"' Sources/FUMD/AppVersion.swift | head -1 | cut -d'"' -f2)
APP_VERSION="${APP_VERSION:-0.1.0}"

echo "▶︎ 编译（release）"
swift build -c release --disable-sandbox

echo "▶︎ 组装 .app（版本 ${APP_VERSION}）"
/bin/rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

/bin/cp ".build/release/FUMD" "$APP/Contents/MacOS/FUMD"

BUNDLE=".build/release/FUMD_FUMD.bundle"
if [ -d "$BUNDLE" ]; then
  /bin/cp -R "$BUNDLE" "$APP/Contents/Resources/"
else
  echo "⚠️ 未找到资源 bundle: $BUNDLE"
  exit 1
fi

if [ -f "Assets/AppIcon.icns" ]; then
  /bin/cp "Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
  echo "⚠️ 缺少 Assets/AppIcon.icns（可运行 Scripts/make-icon.sh 生成）"
fi

# 许可证：每一份分发包都要带上条款（PolyForm 的 Notices 条款要求）
if [ -f "LICENSE" ]; then
  /bin/cp "LICENSE" "$APP/Contents/Resources/LICENSE"
fi

# 第三方组件合规说明（Vditor 等 MIT/BSD 组件的许可与版本）
COMPLIANCE="docs/04-开源合规/第三方组件与许可.md"
if [ -f "$COMPLIANCE" ]; then
  /bin/cp "$COMPLIANCE" "$APP/Contents/Resources/第三方组件与许可.md"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleExecutable</key><string>FUMD</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.fumd.editor</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- 不恢复上次的窗口：启动时总是先出现主窗口，避免恢复出不可见的窗口 -->
    <key>NSQuitAlwaysKeepsWindows</key><false/>
    <!-- 窗口不可见时也不要让系统自动终止应用：导出面板关闭后进程被回收会切断 PDF 的异步渲染 -->
    <key>NSDisableAutomaticTermination</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Markdown 文档</string>
            <key>CFBundleTypeRole</key><string>Editor</string>
            <key>LSHandlerRank</key><string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

codesign --force -s - "$APP"
echo "✅ $APP"
du -sh "$APP"

# 出安装包：把 .app 和一个 Applications 替身放进 dmg（拖进「应用程序」即可安装）
# 注意：hdiutil 需要创建 /dev 设备节点，在受限沙箱里可能失败，需在普通终端执行。
if [ "$MODE" = "dmg" ]; then
  DMG="build/FU-MD.dmg"
  STAGE="build/dmg-staging"
  /bin/rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  /bin/cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$APP_DISPLAY_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" 2>&1 | grep -v WARNING || true
  /bin/rm -rf "$STAGE"
  if [ -f "$DMG" ]; then
    echo "✅ 安装包：${DMG}  ($(du -h "$DMG" | cut -f1))"
  else
    echo "❌ 未能生成 ${DMG}（hdiutil 失败，请在普通终端重跑：Scripts/build-app.sh dmg）"
    exit 1
  fi
  exit 0
fi

if [ "$MODE" = "run" ]; then
  echo "▶︎ 启动"
  open "$APP"
fi
