# FU MD 项目完整文档

> 轻量级 macOS Markdown 编辑器 · Typora 式真·所见即所得即时渲染
>
> 文档版本：v0.1.5 ｜ 更新日期：2026-10-15 ｜ 平台：macOS 13+
>
> 适用范围：FU MD 的维护者与二次开发者。使用说明见仓库根 [README.md](../../README.md)。

---

## 目录

1. [项目概述](#1-项目概述)
2. [功能特性](#2-功能特性)
3. [技术选型与依据](#3-技术选型与依据)
4. [项目结构](#4-项目结构)
5. [架构设计](#5-架构设计)
6. [各模块实现说明](#6-各模块实现说明)
7. [构建与使用指南](#7-构建与使用指南)
8. [开发过程中解决的问题](#8-开发过程中解决的问题)
9. [已知限制与后续方向](#9-已知限制与后续方向)
10. [许可与合规声明](#10-许可与合规声明)
11. [变更记录](#11-变更记录)

---

## 1. 项目概述

### 1.1 项目背景

需求起源于「做一个轻量级的 Mac Markdown 编辑器」。早期方案曾基于 MarkText（Electron）二次开发，但发现方案过重（node_modules 约 3GB、安装包 100MB+、启动慢、内存占用高），遂全部清理，重新制定技术方案。

最终确定的方向：

| 决策项 | 结论 |
| --- | --- |
| 技术栈 | Swift / SwiftUI 原生开发 |
| 功能范围 | 类似 Typora |
| 编辑体验 | 真·所见即所得即时渲染（无双栏、无模式切换） |
| 应用名称 | FU MD |

### 1.2 基本信息

| 项 | 值 |
| --- | --- |
| 应用名称 | FU MD |
| Bundle ID | `com.fumd.editor` |
| 版本 | 0.1.0 (Build 1) |
| 最低系统 | macOS 13.0 (Ventura) |
| 语言/框架 | Swift 5.9 + SwiftUI + AppKit + WebKit |
| 构建系统 | SwiftPM（无需 Xcode 工程，仅 Command Line Tools） |
| 编辑内核 | Vditor 4.0.0（MIT 协议，IR 即时渲染模式，本地离线打包，已裁剪） |
| 最终产物 | `FU MD.app`，约 **13 MB**，ad-hoc 签名 |
| 源码仓库 | <https://github.com/fufer97/FU-MD>（公开，Release 提供 dmg 下载） |
| 版本号来源 | `Sources/FUMD/AppVersion.swift`（单一来源，打包与发版脚本都从这里取值） |

### 1.3 核心体验

输入 Markdown 语法即刻渲染成排版结果：输入 `# ` 变标题、`**x**` 变粗体、`- ` 变列表——和 Typora 一样的「打字即在排版」体验。没有左侧源码栏，没有预览按钮，没有编辑/预览模式切换。

---

## 2. 功能特性

### 2.1 编辑能力（Vditor IR 内核内置）

| 能力 | 说明 |
| --- | --- |
| GFM 全量语法 | 标题、列表、表格、任务列表、删除线、自动链接等 |
| 数学公式 | KaTeX 引擎，行内 `$...$` 与独立 `$$...$$` |
| 图表 | Mermaid（流程图、时序图、甘特图等） |
| 代码高亮 | highlight.js，明暗两套配色 |
| 脚注、引用、图片 | 完整支持 |

### 2.2 文件管理

| 功能 | 说明 |
| --- | --- |
| 打开 | `⌘O`，支持多选，过滤 `.md` / `.markdown` |
| 保存 / 另存为 | `⌘S` / `⇧⌘S`，原子写入，UTF-8 |
| 最近打开 | 接入系统 `NSDocumentController` 最近列表 |
| 未保存关闭提示 | 三按钮弹窗：存储 / 取消 / 不存储；窗口红点脏标记同步 |
| 拖拽与 Dock 打开 | 拖文件到窗口或 Dock 图标均可打开 |
| 多窗口 | `⌘N` 新建窗口；打开文件时复用「空白未编辑」窗口 |
| 文件关联 | Info.plist 注册 Markdown 文档类型（Alternate 级别） |

### 2.3 视图与主题

| 功能 | 说明 |
| --- | --- |
| 明暗主题 | 跟随系统自动切换（监听 `AppleInterfaceThemeChanged`），编辑区/内容区/代码高亮三套联动 |
| 大纲侧栏 | `⌘\` 切换，从渲染后的标题节点实时收集，点击平滑滚动跳转 |
| 状态栏 | 底部显示文件路径（未保存时显示「未命名（未保存）」）与字数/字符统计 |
| 窗口标题 | 随文件名实时更新，未打开文件显示「未命名」 |

### 2.4 导出

| 格式 | 实现 |
| --- | --- |
| HTML | 取渲染后的 HTML，内联内容主题 CSS + KaTeX CSS，单文件自包含 |
| PDF | 隐藏 WKWebView 按 A4 宽（794pt）加载导出 HTML，动态测量高度后 `createPDF` |

### 2.5 快捷键汇总

| 快捷键 | 功能 |
| --- | --- |
| `⌘N` | 新建窗口 |
| `⌘O` | 打开文件 |
| `⌘S` | 保存 |
| `⇧⌘S` | 另存为 |
| `⌘W` | 关闭窗口（脏文档触发确认） |
| `⌘\` | 显示/隐藏大纲侧栏 |

---

## 3. 技术选型与依据

### 3.1 为什么是 Swift 原生壳 + Vditor，而不是纯 SwiftUI 或纯 Electron

| 方案 | 体积 | 评估 |
| --- | --- | --- |
| Electron（MarkText 改造） | ~3GB 源码仓 / 100MB+ 安装包 | 已否决：过重 |
| 纯 Swift 重写编辑器 | ~几 MB | 已否决：Markdown 即时渲染编辑器逻辑极复杂（光标、选区、语法树增量更新），重写成本不可控 |
| **Swift 原生壳 + WKWebView 嵌 Vditor IR（本方案）** | **13MB** | 兼得：原生窗口/菜单/文件体验 + 成熟开源 IR 内核 |

### 3.2 关键组件

- **Vditor**：B3log 开源 Markdown 编辑器，MIT 协议。`ir` 模式即 Typora 式即时渲染，内置 GFM/KaTeX/Mermaid/代码高亮，支持中文，可完全离线（cdn 指向本地目录）。
- **WKWebView**：承载编辑器页面；`websiteDataStore = .nonPersistent()` 不留浏览痕迹。
- **SwiftUI**：窗口、菜单、侧栏、状态栏与整体状态驱动。

### 3.3 无 Xcode 构建体系

本机仅有 Command Line Tools，无完整 Xcode，因此：

- 用 `Package.swift`（SwiftPM）管理可执行目标与资源；
- 用 `Scripts/build-app.sh` 手工组装 `.app` bundle（二进制 + 资源 bundle + Info.plist + 图标）；
- 用 `codesign --force -s -` 做 ad-hoc 签名。

---

## 4. 项目结构

```
FU-MD/                                   # 家目录：~/Documents/FU-MD
├── Package.swift                        # SwiftPM 清单：可执行目标 FUMD，macOS 13+
├── README.md                            # 面向使用者：下载安装、功能、构建、许可
├── LICENSE                              # PolyForm Noncommercial 1.0.0
├── Sample.md                            # 功能验证样例（覆盖主要语法）
├── .gitignore
├── Assets/
│   ├── icon_1024.png                    # 图标原图（AI 生成）
│   ├── icon_1024.jpg
│   └── AppIcon.icns                     # make-icon.sh 产物（随仓库提供）
├── Scripts/
│   ├── build-app.sh                     # release 构建 + 组装 .app + ad-hoc 签名（build/run/dmg）
│   ├── release.sh                       # 改版本号 → 出 dmg → 提交推送 → 发 GitHub Release
│   ├── fetch-vditor.sh                  # 拉取并裁剪 Vditor 内核（升级内核时才需要）
│   └── make-icon.sh                     # sips + iconutil 生成 icns
├── Sources/FUMD/
│   ├── FUMDApp.swift                    # App 入口、AppDelegate、窗口视图组装
│   ├── AppVersion.swift                 # 版本号单一来源
│   ├── EditorBridge.swift               # WKWebView 桥接核心（JS ↔ Swift）
│   ├── EditorWebView.swift              # NSViewRepresentable 封装 WKWebView
│   ├── DocumentStore.swift              # 文档状态（URL/脏标记/内容/统计/大纲）+ CloseGuard
│   ├── OpenCoordinator.swift            # 多窗口/文件打开协调（复用空白窗口）
│   ├── MenuCommands.swift               # 原生菜单与快捷键
│   ├── OutlineSidebar.swift             # 大纲侧栏
│   ├── StatusBarView.swift              # 底部状态栏
│   ├── ThemeManager.swift               # 系统明暗主题监听
│   ├── ExportService.swift              # HTML / PDF 导出
│   └── Resources/
│       └── editor/
│           ├── index.html               # 编辑器宿主页（隐藏工具栏、去边框）
│           ├── editor.js                # JS 侧桥接层 + Vditor 初始化
│           └── vditor/                  # Vditor 4.0.0 内核（已裁剪）
│               ├── VERSION              # 内核版本号
│               ├── LICENSE              # Vditor 的 MIT 许可正文（随包分发）
│               └── dist/
├── docs/                                # 项目文档（按阶段归档）
│   ├── 01-技术方案/                      # 已采纳与本已被否决的两份方案
│   ├── 02-项目文档/                      # 本文档
│   ├── 03-界面截图/                      # 界面截图与采集说明
│   └── 04-开源合规/                      # 第三方组件版本、许可与义务
└── build/                               # 构建产物（不入库）
    ├── FU MD.app                        # 最终产物（13MB）
    └── FU-MD.dmg                        # 安装包（build-app.sh dmg）
```

> 说明：`vditor/dist` 原始约 23MB，已裁剪未使用的 9 个大型渲染引擎，保留 IR 必需部分后约 11MB（含 KaTeX 字体、Mermaid、内容主题 CSS 等）。裁剪清单与复现方式见 `Scripts/fetch-vditor.sh` 的 `KEEP_JS`，许可说明见 [../04-开源合规/第三方组件与许可.md](../04-开源合规/第三方组件与许可.md)。

---

## 5. 架构设计

### 5.1 总体分层

```
┌─────────────────────────────────────────────┐
│  SwiftUI 层                                  │
│  FUMDApp / MenuCommands / OutlineSidebar    │
│  StatusBarView / EditorWebView              │
├─────────────────────────────────────────────┤
│  状态层（ObservableObject）                   │
│  DocumentStore（文档状态）                    │
│  OpenCoordinator（全局窗口/打开协调, 单例）     │
│  ThemeManager（系统主题监听, 单例）            │
├─────────────────────────────────────────────┤
│  桥接层                                      │
│  EditorBridge ── WKScriptMessage("fumd") ── │
│       ↕ evaluateJavaScript / postMessage    │
├─────────────────────────────────────────────┤
│  Web 层（WKWebView）                         │
│  index.html + editor.js + Vditor IR         │
└─────────────────────────────────────────────┘
```

### 5.2 JS ↔ Swift 双向桥接协议

**通道约定**（重命名后已统一为 FUMD）：

- 消息通道名：`fumd`（Swift `add(proxy, name: "fumd")` ↔ JS `messageHandlers.fumd.postMessage`）
- JS 全局桥对象：`window.FUMDBridge`

**JS → Swift**（`postMessage`，异步单向）：

| 消息 type | 载荷 | 说明 |
| --- | --- | --- |
| `ready` | — | Vditor 初始化完成；Swift 随后补发主题、排队内容、聚焦、请求大纲 |
| `contentChanged` | `markdown`、`stats{characters,words,lines}` | 输入防抖 300ms 后上报内容与统计 |
| `outline` | `items[{index,level,text}]` | 标题大纲（从渲染节点收集，`#` 个数定级别） |

**Swift → JS**（`evaluateJavaScript`，直接函数调用）：

| 调用 | 说明 |
| --- | --- |
| `FUMDBridge.setValue({markdown})` | 设置编辑器内容（未 ready 前排队） |
| `FUMDBridge.getValue()` | 取当前 Markdown 源码（保存时用，返回值） |
| `FUMDBridge.getHtml()` | 取渲染后 HTML（导出时用，返回值） |
| `FUMDBridge.setTheme(true/false)` | 切换明暗主题 |
| `FUMDBridge.requestOutline()` | 主动请求一次大纲 |
| `FUMDBridge.scrollToHeading(index)` | 大纲点击跳转（平滑滚动） |
| `FUMDBridge.focus()` | 编辑器聚焦 |

### 5.3 关键设计决策

| 决策 | 理由 |
| --- | --- |
| 打开文件复用「空白未编辑」窗口 | 接近原生文档应用的体验；`OpenCoordinator` 维护候选窗口弱引用表 |
| Swift 侧值排队（`queuedValue`） | 文件打开可能早于 WebView ready，ready 后统一补发，避免丢内容 |
| 内容同步从 WKWebView 拉取（`getValue()`）再写盘 | 保证保存的永远是编辑器里的真实状态，Swift 侧缓存仅用于脏判断与标题 |
| 字数统计放在 JS 侧 | Vditor 4.0 移除了 `getStatistics`，自行实现（见 6.2） |
| 主题用 `DistributedNotificationCenter` 监听 | 比 SwiftUI `colorScheme` 更早感知，可同步推送进 WebView |
| 资源用 `.copy("Resources")` 整目录拷贝 | 避免 SwiftPM 对海量 vditor 静态资源做逐文件处理 |

---

## 6. 各模块实现说明

### 6.1 FUMDApp.swift — 入口与窗口组装

- `@main FUMDApp`：声明 `WindowGroup(id: "editor")`，挂 `AppCommands` 菜单。
- `AppDelegate`：实现 `application(_:open:)` 支持 Dock/拖拽打开，转交 `OpenCoordinator`；最后一个窗口关闭即退出应用。
- `EditorContext`：每窗口持有 `DocumentStore` + `EditorBridge` 并互相引用。
- `EditorContent`：组装「大纲侧栏（可选）+ 编辑区 + 状态栏」垂直布局；`navigationTitle` 绑定 `store.displayName`（store 以 `@ObservedObject` 放在同一视图层，保证文件名变化即时刷新标题）。
- `WindowConfigurator`：借一个零尺寸 `NSView` 的 `viewDidMoveToWindow` 时机拿到 `NSWindow`，挂 `CloseGuard`（脏文档关闭确认）并向 `OpenCoordinator` 注册窗口；**若此刻窗口 `isVisible == false`，补一次 `makeKeyAndOrderFront(nil)` + `NSApp.activate(ignoringOtherApps: true)`** —— 由文档启动时 SwiftUI 不会自动置前（见第 8 节第 13 条），没有这一步用户双击 `.md` 只会看到菜单栏切过去、没有窗口。

### 6.2 editor.js — 编辑器初始化与桥接

- 以 IR 模式创建 Vditor：`toolbar: []`（隐藏工具栏）、`typewriterMode: false`、`cache: {enable:false}`、`cdn: 'vditor'`（本地相对路径，完全离线）、`lang: 'zh_CN'`。
- 输入事件防抖 300ms 后上报 `contentChanged`（Markdown 源码 + 统计）与 `outline`。
- **字数统计自实现**（Vditor 4.0 移除了 `getStatistics`）：

```javascript
function computeStats(value) {
  var lines = value ? value.split('\n').length : 0;
  var cjk = (value.match(/[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]/g) || []).length;
  var latin = (value.match(/[A-Za-z0-9][A-Za-z0-9'’\-_]*/g) || []).length;
  var characters = (value.replace(/\s/g, '')).length;
  return { characters: characters, words: cjk + latin, lines: lines };
}
```

规则：中日韩文字每个字符算一个词，英文/数字连续串算一个词，字符数为去空白后长度——对中文文档友好。

- 大纲收集：从 `#editor .vditor-ir__node[data-type="heading"]` 取标题节点，克隆后移除语法标记（`.vditor-ir__marker`）得到纯文本，`#` 个数决定级别。

### 6.3 DocumentStore.swift — 文档状态与关闭守卫

- 状态：`fileURL`、`isDirty`、`markdown`（缓存，用于脏判断）、`stats`、`outline`，均为 `@Published`。
- `load(url:)`：UTF-8 读取失败弹窗提示；成功后设置状态、推送给编辑器、记入系统最近列表。
- `save()`：已有 URL 直接写；无 URL 转入 `saveAs()`（NSSavePanel，过滤 markdown 类型，默认名「未命名.md」）。
- `write(to:)`：**先从编辑器 `getValue()` 拉取真实内容**再原子写盘，成功后清脏标记。
- `CloseGuard`（`NSWindowDelegate`）：把 `isDirty` 同步到窗口红点（`isDocumentEdited`）；`windowShouldClose` 时脏文档弹三按钮确认（存储/取消/不存储），选存储则异步保存成功后再关窗。

### 6.4 OpenCoordinator.swift — 多窗口与打开协调

- `requestOpen(url)`：若有「空白且未编辑」的候选窗口则直接在该窗口加载；否则记录 pending URL 并 `openWindowAction` 开新窗口。
- `claimPendingForNewWindow()`：新窗口 `onAppear` 时领取待打开文件，避免错投到旧窗口。
- `register(window:store:)` / `activeStore()`：维护「窗口 ↔ store」弱引用表，菜单动作（保存/导出）作用于当前 key window 对应的文档。
- `showOutline`、`isDark` 为全局发布属性，驱动所有窗口。

### 6.5 ThemeManager.swift — 系统主题跟随

监听分布式通知 `AppleInterfaceThemeChanged`，用 `NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])` 判定当前是否暗色，写入 `OpenCoordinator.isDark`；`EditorContent` 订阅后调用 `bridge.setTheme(dark:)` 推进 WebView，JS 侧同步切换 Vditor 编辑区主题、内容主题与代码高亮三件套。

### 6.6 ExportService.swift — HTML / PDF 导出

- 统一从编辑器取渲染后 HTML，包裹为自包含文档：内联「content-theme（light/dark）CSS + katex.min.css」，正文限宽 820px 居中。
- HTML：直接写盘。
- PDF：创建 794×1123（A4 @96dpi）隐藏 WKWebView，`loadHTMLString` 以 KaTeX 目录为 baseURL（保证字体相对路径可解析），轮询等待加载完成（最多 10 秒），动态量取文档高度后 `createPDF` 导出（completion API 用 `withCheckedThrowingContinuation` 包装为 async）。

### 6.7 MenuCommands.swift — 菜单与快捷键

在「新建」之后插入打开/保存/另存为/导出菜单组，在「侧栏」之后插入大纲开关（`⌘\`）。所有动作通过 `OpenCoordinator.activeStore()` 定位当前文档。

### 6.8 构建脚本

| 脚本 | 职责 | 要点 |
| --- | --- | --- |
| `build-app.sh` | 打包 .app / dmg | 设 `TMPDIR` 与模块缓存到 `~/.cache/fumd/` 并加 `--disable-sandbox`（绕过 SwiftPM 沙箱限制）→ 拷二进制与资源 bundle → 从 `AppVersion.swift` 取版本写入 Info.plist（含文档关联、`NSQuitAlwaysKeepsWindows=false`、`NSDisableAutomaticTermination=true`）→ ad-hoc 签名 → 可选 `hdiutil` 出 dmg |
| `release.sh` | 一条命令发版 | 改版本号 → 出 dmg → `git` 提交推送 → `gh release create`（附件名预先改成 `FU-MD-<版本>.dmg`，避免 GitHub 把空格换成点） |
| `fetch-vditor.sh` | 升级内核 | 版本钉在 `VDITOR_VERSION`（当前 4.0.0）；按 `KEEP_JS` 裁剪，保留 MIT 许可正文与版本号文件 |
| `make-icon.sh` | 生成图标 | `sips` 批量缩放 10 个尺寸 → `iconutil` 合成 icns |

> 脚本中文件操作统一使用 `/bin/rm`、`/bin/mv`、`/bin/cp` 绝对路径（规避环境自定义 rm 包装脚本的兼容问题）。

---

## 7. 构建与使用指南

### 7.1 环境要求

- macOS 13+，已装 Command Line Tools（`xcode-select --install`）
- 无需完整 Xcode

### 7.2 从源码构建

```bash
cd ~/Documents/FU-MD

# 打包（输出 build/FU MD.app）
Scripts/build-app.sh

# 打包并启动
Scripts/build-app.sh run

# 出安装包（输出 build/FU-MD.dmg）
Scripts/build-app.sh dmg

# 可选：重新生成应用图标（需 Assets/icon_1024.png）
Scripts/make-icon.sh
```

编辑器内核已随仓库提供，克隆后直接构建即可，不需要联网。

### 7.2.1 升级编辑器内核

```bash
# 重新拉取并裁剪 Vditor（版本见脚本里的 VDITOR_VERSION）
Scripts/fetch-vditor.sh
```

升级后需要同步更新 [../04-开源合规/第三方组件与许可.md](../04-开源合规/第三方组件与许可.md) 的版本号与许可状态。

### 7.2.2 发版

```bash
# 改版本号 → 出 dmg → 提交推送 → 发 GitHub Release
Scripts/release.sh 0.2 "这次改了什么"

# 只改版本号并检查，不构建不发布
Scripts/release.sh 0.2 "说明" --dry-run
```

### 7.3 直接使用

双击 `build/FU MD.app` 即可。首次启动若被 Gatekeeper 拦截（ad-hoc 签名所致）：

```bash
xattr -d com.apple.quarantine "build/FU MD.app"
```

### 7.4 功能验证

打开项目自带的 `Sample.md`，覆盖验证：标题/列表/任务列表/表格/代码高亮/引用/行内与独立公式/链接/脚注的即时渲染，以及大纲收集、字数统计、明暗切换与导出。

---

## 8. 开发过程中解决的问题

| # | 问题 | 解决方案 |
| --- | --- | --- |
| 1 | Electron 方案过重（3GB 仓库、100MB+ 包） | 整体废弃，改为 Swift 原生 + Vditor，产物缩至 13MB |
| 2 | `UTType.markdown` 系统未内置 | `UTType(importedAs: "net.daringfireball.markdown")` 自行导入 |
| 3 | `WKWebView.createPDF` 缺 completionHandler 编译错 | `withCheckedThrowingContinuation` 包装 completion API 为 async |
| 4 | `isBestMatched(by:)` API 不存在 | 改用 `bestMatch(from: [.aqua, .darkAqua])` 判定暗色 |
| 5 | 窗口标题不随文件名更新 | 将 `navigationTitle` 拆到独立视图层，`store` 以 `@ObservedObject` 注入保证发布订阅生效 |
| 6 | Vditor 4.0 移除 `getStatistics` | JS 侧自实现统计（CJK 单字计一词，见 6.2） |
| 7 | 环境自定义 `rm` 包装脚本在 `set -u` 下崩溃 | 脚本内文件操作改用 `/bin/rm` 等绝对路径 |
| 8 | SwiftPM 不支持带空格的项目目录名 | 项目目录命名 `FU-MD`（连字符），`.app` 产物保持显示名 `FU MD` |
| 9 | JS 桥缺 `focus` 方法导致打开文件后无法自动聚焦 | `FUMDBridge` 补充 `focus()`（调用 `vditor.focus()`） |
| 10 | **重命名遗漏导致桥接断裂**：Swift 调 `LightMarkBridge.*` 而 JS 只暴露 `FUMDBridge`；JS 发消息用 `messageHandlers.lightmark` 而 Swift 注册的是 `fumd` —— 单向调用全部静默失败 | 全量检索替换，两端通道统一为 `FUMDBridge` / `fumd`，重新构建验证 |
| 11 | **导出的公式是 LaTeX 源码、没有排版**（2026-10-15 实测发现）：`vditor.getHTML()` 对公式只给出 `<span\|div class="language-math">` 容器与原始源码，导出文件里 `class="katex"` 出现 0 次；编辑器内显示正常，说明缺的是导出链路上的一次 KaTeX 排版 | `editor.js` 在 `getHtml()` 返回前，对正文里的 `.language-math` 节点跑一遍全局 `katex.render`（按 `span` / `div` 区分行内与独立公式，渲染失败保留原始源码）；`index.html` 显式加载 `katex.min.js`，不再依赖 Vditor 的按需加载。验证：导出 HTML 的 `class="katex"` 由 0 变为 7，PDF 中行内公式 `E = mc²` 与独立公式积分均正确排版 |
| 12 | **窗口不可见时，关闭导出面板会连带退出应用**（2026-10-15 实测发现）：带文件启动时编辑器窗口曾处于 `onscreen=false` 的不可见状态，导出面板因此成了唯一可见窗口，面板一关闭（保存与取消都算）就触发退出；HTML 导出是面板返回后同步写盘尚能完成，PDF 导出在面板关闭后才开始异步渲染，进程被回收即拿不到文件 | `Info.plist` 补上 `NSQuitAlwaysKeepsWindows=false`（不恢复出不可见窗口）与 `NSDisableAutomaticTermination=true`（窗口都不可见时也不被系统自动终止），与 FU ToDo 的做法一致。验证：同一启动条件下窗口恢复可见（`onscreen=true`），导出面板关闭后应用存活，HTML 与 PDF 均正常落盘 |
| 13 | **Finder 双击 `.md` 打不开、窗口是空的**（2026-10-15 用户报障 + 日志定位）：由文档启动时 SwiftUI 把窗口创建出来却**从不置前**，窗口从 onAppear 起 `isVisible=false`、`isMiniaturized=false`、未被遮挡，且 `NSApp.windows` 里能看到它；文件其实已经加载成功（窗口标题已变成文件名），只是窗口不显示，用户只看到菜单栏切到 FU MD | 诊断日志（临时写入 `/tmp/fumd-diag.log`，排查后已移除）确认后，在 `WindowConfigurator` 拿到窗口时补一次显式前置：窗口不可见才 `makeKeyAndOrderFront(nil)` + `NSApp.activate(ignoringOtherApps: true)`。验证：双击路径下窗口从 2 秒到 15 秒持续 `onscreen=true`，标题 `Sample.md`、正文渲染完整（字数 180 / 字符 397）；不带文件启动的常规路径不受影响 |

---

## 9. 已知限制与后续方向

### 9.1 已知限制

- 导出的 HTML 内联 KaTeX 字体时用的是相对路径（`url(fonts/KaTeX_*.woff2)`），文件被移动或单独分享后公式字体可能回退为系统字体；把导出文件与内核的 `fonts/` 目录一起分发可避免。
- ad-hoc 签名，首次启动需移除 quarantine 属性。
- 大纲仅收集标题，不支持拖拽调序。
- 内核已裁剪至约 11MB（原发行包约 23MB）；若要继续减小体积，需要评估 KaTeX 字体子集与 i18n 语言包的精简空间。

### 9.2 暂不支持

文件树、多标签页、自动保存、图床上传、导出 Word/LaTeX。

### 9.3 可选演进方向

- 独立开发者签名 + 公证，去除 Gatekeeper 提示
- 自动保存与版本快照
- 自定义主题 CSS 注入
- 更多导出格式（Word / 图片 / LaTeX）

---

## 10. 许可与合规声明

- 本应用代码为独立编写，未使用、未逆向 Typora 的任何代码或资源。
- 本项目自行编写的代码按 **PolyForm Noncommercial License 1.0.0** 授权（见仓库根 `LICENSE`）：个人、学习、研究与非营利 / 教育 / 政府用途可用，**商业使用需另行取得授权**。打包时 `LICENSE` 会被拷入 `FU MD.app/Contents/Resources/`。
- 编辑内核 [Vditor](https://github.com/Vanessa219/vditor) 4.0.0 采用 **MIT 协议**发行，其许可正文随内核存放于 `Sources/FUMD/Resources/editor/vditor/LICENSE`，符合开源合规要求。
- 代码高亮（highlight.js，BSD-3-Clause）、公式（KaTeX，MIT）、图表（Mermaid，MIT）均为 Vditor 发行包内置的宽松协议组件。
- 各组件的版本、许可正文位置与分发义务详见 [../04-开源合规/第三方组件与许可.md](../04-开源合规/第三方组件与许可.md)。

---

## 11. 变更记录

| 版本 | 日期 | 变更点 | 影响范围 |
| --- | --- | --- | --- |
| v0.1.5 | 2026-10-15 | 修复 Finder 双击 `.md` 时窗口不显示（由文档启动时 SwiftUI 不把窗口置前）：`WindowConfigurator` 补一次显式前置（随应用 **0.1.3** 发布） | 各模块实现（6.1 节）、踩坑记录（第 8 节第 13 条） |
| v0.1.4 | 2026-10-15 | 修复窗口不可见时关闭导出面板会退出应用：`Info.plist` 补 `NSQuitAlwaysKeepsWindows=false` 与 `NSDisableAutomaticTermination=true`（随应用 **0.1.2** 发布） | 构建脚本（6.8 节）、踩坑记录（第 8 节第 12 条）、已知限制（9.1 节） |
| v0.1.3 | 2026-10-15 | 修复导出公式未排版：`editor.js` 的 `getHtml()` 返回前补一次 KaTeX 排版，`index.html` 显式加载 KaTeX（随应用 **0.1.1** 发布） | 各模块实现（6.2 节）、踩坑记录（第 8 节第 11 条）、已知限制（9.1 节） |
| v0.1.2 | 2026-10-15 | 补入导出功能的实测结论：导出 HTML/PDF 中公式未排版（原始 LaTeX）、窗口不可见时关闭导出面板会退出应用（PDF 导出受影响）、导出字体相对路径问题 | 已知限制（9.1 节） |
| v0.1.1 | 2026-10-15 | 项目从 TRAE 工作目录迁至 `~/Documents/FU-MD` 并建立 git 仓库；新增 `docs/` 分阶段归档、`LICENSE`、`AppVersion.swift`（版本号单一来源）、`Scripts/release.sh`；`build-app.sh` 增加 dmg 模式与沙箱规避；Vditor 内核钉版 4.0.0 并补齐 MIT 许可正文 | 目录结构（第 4 节）、构建与发版命令（第 7 节）、脚本职责（6.8 节）、许可声明（第 10 节） |
| v0.1.0 | 2026-10-15 | 首版全量文档：功能、技术选型、架构与桥接协议、各模块实现、踩坑记录 | 全文 |
