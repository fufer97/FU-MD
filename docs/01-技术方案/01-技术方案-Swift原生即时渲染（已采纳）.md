# 计划：LightMark — Swift 原生轻量 Mac Markdown 编辑器（Typora 式即时渲染）

> 工作代号：LightMark（现已定名 **FU MD**，本方案为已采纳方案）
> 日期：2026-10-15（取代同目录下旧方案 `02-技术方案-MarkText分栏预览（已否决）.md`）

---

## 一、总结（Summary）

放弃 MarkText/Electron 二开方案，改为**从零构建原生轻量应用**：

1. **技术栈**：Swift/SwiftUI 原生壳 + WKWebView 嵌入 **Vditor IR（即时渲染）模式** 编辑器内核；
2. **核心体验**：Typora 式**真·所见即所得**——输入 `# ` 立刻变大标题、`**x**` 立刻变粗体，无预览栏、无模式切换；
3. **功能范围**：对齐 Typora 的核心日常功能（见第三节），不做文件树/多标签等重型功能；
4. **清理**：完全删除旧 MarkText 工作（3.0GB），停止残留后台任务。

**预期效果**：安装包约 5–15MB（Electron 方案约 100MB+），启动秒开，内存占用低，原生 Mac 菜单/窗口/快捷键体验。

**合规声明**：Vditor 为 MIT 开源协议（B3log），可自由使用与再分发；不逆向、不引用 Typora 任何代码或资源。

**用户已确认的决策**：

| 决策项 | 选择 |
|---|---|
| 技术栈 | Swift/SwiftUI 原生 |
| 功能范围 | 类似 Typora |
| 编辑体验 | 真·所见即所得即时渲染（IR） |
| 旧工作处理 | 完全删除 |

---

## 二、现状分析（Current State Analysis）

### 2.1 旧工作盘点（待清理）

| 项目 | 位置 | 状态 |
|---|---|---|
| MarkText 仓库 + 构建产物 | `/Users/fufu/lightmark/marktext` | 2.8GB，含 node_modules、dist |
| 构建辅助工具（node22、python3） | `/Users/fufu/lightmark/tools` | 随仓库一起删除 |
| 工作区符号链接 | 工作区/`marktext` → `~/lightmark/marktext` | 删除链接 |
| 残留后台任务 | 11 个旧 dev/build 进程（job-338f… 等） | 已因沙箱限制报错卡死，需逐个停止 |
| 旧计划文档 | `.trae/documents/marktext-split-view-editor-plan.md` | 保留归档，仅作历史记录 |

### 2.2 本机工具链（2026-10-15 实测）

- Swift **6.2.3**（arm64-apple-macosx28.0）✅ 可用；
- **无 Xcode**，仅 Command Line Tools（`xcodebuild` 不可用）→ **不能建 .xcodeproj**；
- 结论：采用 **SwiftPM 纯命令行构建 + 脚本组装 .app bundle**（成熟做法，CLT 自带 macOS SDK，SwiftUI/AppKit 可正常编译）。

### 2.3 方案核心依据（已调研确认）

- **Vditor**（https://github.com/Vanessa219/vditor ，MIT）：内置三种模式，其中 **IR（即时渲染）模式正是 Typora 的交互形态**；
- 内置能力免开发：GFM 全量、KaTeX 数学公式、Mermaid/流程图/甘特图、代码高亮（Prism 体系）、任务列表、脚注、emoji、字数统计、大纲提取、XSS 消毒；
- 纯 JS 库，`dist/` 约 5MB，打包进 app 离线可用，与 WKWebView 完美适配；
- Swift 侧只做：窗口/菜单/文件 IO/主题/大纲/导出/打包 —— 边界清晰，代码量小。

---

## 三、功能范围（类似 Typora 的 MVP）

| # | 功能 | 实现来源 | 备注 |
|---|---|---|---|
| 1 | IR 即时渲染编辑（标题/粗斜体/列表/引用/代码块/链接图片/表格/任务列表/删除线/脚注） | Vditor 内置 | 核心体验 |
| 2 | 数学公式（KaTeX）、Mermaid 图表、代码高亮 | Vditor 内置 | 配置开启 |
| 3 | 打开/保存/另存为（.md/.markdown） | Swift 开发 | 原生 NSOpenPanel/NSSavePanel |
| 4 | 最近打开列表 | Swift 开发 | NSDocumentController |
| 5 | 未保存关闭提示（脏状态） | Swift 开发 | 标题栏 Edited 圆点 + 询问框 |
| 6 | 明暗主题跟随系统 | Vditor setTheme + Swift | 编辑区/内容区/代码高亮三套联动 |
| 7 | 文档大纲侧栏（点击跳转） | Vditor 提取 + SwiftUI List | Typora 标志性功能 |
| 8 | 字数/字符统计状态栏 | Vditor getStatistics + Swift | 底部状态条 |
| 9 | 导出 HTML / PDF | Swift 开发 | HTML 用模板包裹，PDF 用 WKWebView createPDF |
| 10 | 拖拽 .md 到窗口/Dock 图标打开 | Swift 开发 | 文件关联（Info.plist） |

**明确不做（范围外）**：文件夹侧边栏/文件树、多标签页、源码/分屏模式切换、图床与图片上传、自动保存、云同步、导出 Word/LaTeX、插件系统、拼写检查定制。以上留作后续迭代。

---

## 四、项目结构（文件级）

新建于工作区根目录 `LightMark/`：

```
LightMark/
├── Package.swift                    # macOS 13+，executableTarget，resources: .copy("Resources")
├── Sources/LightMark/
│   ├── LightMarkApp.swift           # @main SwiftUI App + AppDelegate 适配器（Dock 打开文件入口）
│   ├── OpenCoordinator.swift        # 单例：打开文件请求 → 复用空白窗口或新建窗口
│   ├── DocumentStore.swift          # ObservableObject：文件URL/脏状态/读写/最近列表
│   ├── EditorWebView.swift          # NSViewRepresentable 封装 WKWebView
│   ├── EditorBridge.swift           # WKScriptMessageHandler：JS↔Swift 消息路由（协议见 5.1）
│   ├── ThemeManager.swift           # 监听系统外观 → 通知 JS setTheme + 窗口背景防白闪
│   ├── MenuCommands.swift           # SwiftUI Commands：文件/导出/视图/帮助菜单与快捷键
│   ├── OutlineSidebar.swift         # 大纲侧栏（NavigationSplitView + List）
│   ├── StatusBarView.swift          # 底部字数统计条
│   └── ExportService.swift          # HTML/PDF 导出
├── Resources/editor/
│   ├── index.html                   # 编辑器页面（引 vditor 样式与脚本）
│   ├── editor.js                    # Vditor IR 初始化 + window.LightMarkBridge 桥接层
│   └── vditor/                      # Vditor dist（由脚本下载，.gitignore 忽略）
├── Scripts/
│   ├── fetch-vditor.sh              # curl 从 npm registry 拉 vditor tgz 解压（仅系统工具，无 node 依赖）
│   ├── build-app.sh                 # swift build -c release + 组装 LightMark.app + ad-hoc 签名
│   └── make-icon.sh                 # sips + iconutil：PNG → iconset → AppIcon.icns
├── Assets/
│   └── icon_1024.png                # 应用图标原图（用生成图工具产出）
├── .gitignore
└── README.md                        # 构建/运行/打包说明 + MIT 归属声明
```

**资源加载机制**：Package.swift 声明 `.copy("Resources")` → `swift build` 产出 `LightMark_LightMark.bundle` → dev 模式 `Bundle.module` 直接可用；打包时该 bundle 拷入 `.app/Contents/Resources/`，运行时统一经 `Bundle.module` 定位 `editor/index.html`，`loadFileURL(allowingReadAccessTo: editorRoot)` 保证 vditor 子资源可读。

---

## 五、关键设计

### 5.1 JS ↔ Swift 桥协议（EditorBridge）

**JS → Swift**（`window.webkit.messageHandlers.lightmark.postMessage({...})`）：

| type | payload | 触发时机 |
|---|---|---|
| `ready` | — | Vditor `after` 回调；Swift 补发初始文档与当前主题 |
| `contentChanged` | `{ markdown }` | Vditor `input` 回调 300ms 防抖；Swift 标脏 + 更新标题 |
| `stats` | `{ characters, words, lines }` | 与 contentChanged 同批上报 |
| `outline` | `{ items:[{level,text,index}] }` | Swift 请求或编辑防抖后回报 |

**Swift → JS**（`evaluateJavaScript`）：

| 调用 | 用途 |
|---|---|
| `LightMarkBridge.setValue(md)` | 打开文件/新建时灌入内容 |
| `LightMarkBridge.getValue(cb)` | 保存/导出前取 Markdown |
| `LightMarkBridge.setTheme(isDark)` | 主题联动（切 Vditor content/code 主题 + 自身配色） |
| `LightMarkBridge.requestOutline()` / `scrollToHeading(i)` | 大纲提取与跳转 |
| `LightMarkBridge.exportHtml(cb)` | 导出取渲染 HTML |

WKWebView 配置：`nonPersistent()` 数据存储（禁本地缓存）、消息 handler 名 `lightmark`。

### 5.2 文件管理（DocumentStore）

- 单窗口单文档（对齐 Typora 早期形态）；启动默认空白「未命名.md」；
- Cmd+S：若未保存过 → NSSavePanel；已保存 → `getValue` 异步取回后写入；成功后清除脏状态并 `noteNewRecentDocumentURL`；
- 关闭脏文档：`window.isDocumentEdited` 圆点 + NSAlert（保存/不保存/取消）；
- Dock 图标/拖拽打开：AppDelegate `application(_:open:)` → OpenCoordinator → 当前窗口干净且为空则复用，否则 `openWindow` 新窗口；
- 编码 UTF-8；外部修改检测（文件监听）列为范围外。

### 5.3 主题联动（ThemeManager）

- Swift 侧监听 `NSApp.effectiveAppearance`（darkAqua/aqua）→ 调 JS `setTheme(isDark)`；
- Vditor 三套主题资源随 dist 内置：`content-theme/dark|light` + `code-theme/github-dark|github`；
- 窗口背景色同步（暗色 `#1e1e1e` 系），编辑器加载期间不闪白。

### 5.4 打包（build-app.sh）

1. `swift build -c release`；
2. 组装 `LightMark.app/Contents/{MacOS, Resources}`：二进制 + `LightMark_LightMark.bundle` + `AppIcon.icns`；
3. 手写 `Info.plist`：`NSPrincipalClass=NSApplication`、`CFBundleDocumentTypes`（md/markdown 关联，角色 Editor）、`LSMinimumSystemVersion=13.0`、`NSHighResolutionCapable`；
4. `codesign --force -s -` ad-hoc 签名；可选 `hdiutil` 产 dmg；
5. README 记录本机运行验证步骤（首次启动若遇 Gatekeeper 拦截：`xattr -d com.apple.quarantine`）。

---

## 六、实施步骤

### 阶段 0：清理旧工作
1. 逐个 `TaskStop` 停止 11 个残留后台任务（job-338f… / job-6606… / job-0b20… / job-83f5… / job-8c1e… / job-d5c1… / job-5e15… / job-79bf… / job-6efb… / job-2048… / job-aaea… / job-0be1…）；
2. 删除工作区符号链接 `marktext`；
3. 删除 `/Users/fufu/lightmark` 整目录（3.0GB，用户已确认完全删除）；
4. 重置 todo 列表为新方案阶段。

### 阶段 1：骨架与 IR 打通（核心验证）
1. 建 `LightMark/` 目录与 Package.swift（macOS 13+）；
2. `fetch-vditor.sh` 下载 vditor dist → Resources/editor/vditor；
3. index.html + editor.js：`new Vditor(el, { mode:'ir', cache:false, … })`；
4. Swift：LightMarkApp + EditorWebView + EditorBridge，跑通 ready/contentChanged；
5. **验证**：`swift run` 启动窗口，输入 `# ` 立即变标题、`**x**` 立即加粗。

### 阶段 2：文件管理
1. DocumentStore：打开/保存/另存为/最近列表/脏状态/关闭确认；
2. MenuCommands：文件菜单 + 快捷键（Cmd+O/S/Shift+S/W、Cmd+N）；
3. 拖拽与 Dock 打开（OpenCoordinator）；
4. **验证**：全流程 打开→编辑→保存→重开→关闭提示。

### 阶段 3：主题
1. ThemeManager + JS setTheme 三套主题联动 + 防白闪；
2. **验证**：系统亮暗切换，编辑区/内容/代码高亮同步切换。

### 阶段 4：大纲 + 状态栏
1. OutlineSidebar（提取标题 → List → 点击 scrollToHeading）；
2. StatusBarView（字数/字符数）；
3. **验证**：编辑标题后大纲实时更新、点击跳转正确。

### 阶段 5：导出
1. ExportService：HTML（getHTML + 模板/CSS 内联）、PDF（离屏 WKWebView createPDF）；
2. **验证**：含公式/表格/代码块的文档导出正常打开。

### 阶段 6：图标与打包交付
1. 生成图标 → make-icon.sh → icns；
2. build-app.sh 产出 LightMark.app（+ 可选 dmg），ad-hoc 签名；
3. 端到端验证（见第七节）。

---

## 七、验证清单（交付前）

- [ ] `swift build` 通过；LightMark.app 双击可启动；
- [ ] IR 即时渲染：标题/粗斜体/列表/引用/代码块/表格/任务列表输入即渲染；
- [ ] KaTeX 公式与 Mermaid 图表渲染正常；
- [ ] 打开/保存/另存为/最近列表/脏标记/关闭确认全流程正常；
- [ ] 拖拽 .md 到窗口与 Dock 图标可打开；
- [ ] 系统明暗切换三套主题同步；
- [ ] 大纲跳转、字数统计正常；
- [ ] 导出 HTML/PDF 内容完整；
- [ ] 安装包体积 < 20MB。

---

## 八、假设与决策记录

| 决策 | 结论 | 理由 |
|---|---|---|
| 编辑器内核 | Vditor IR（MIT） | 完整复刻 Typora 即时渲染；自研 Swift 原生编辑器（TextKit）成本极高且语法覆盖难达标 |
| 应用壳 | SwiftUI + WKWebView | 原生窗口/菜单/文件体验 + Web 内核功能完整度，兼得 |
| 构建体系 | SwiftPM + 脚本组装 .app | 本机无 Xcode（仅 CLT）；避免引入 xcodegen 额外依赖 |
| 最低系统 | macOS 13+ | NavigationSplitView 等 API 需求，覆盖面足够 |
| Vditor 获取 | npm registry tgz + curl | 打包离线可用；仅依赖系统 curl/sed，删除旧 node 环境后无影响 |
| 签名 | ad-hoc | 自用无开发者账号 |
| 单位模型 | 单窗口单文档 | 贴近 Typora 使用习惯，避免 SwiftUI 多窗口文档管理复杂度 |
| 旧工作 | 全部删除（3.0GB + 链接 + 后台任务） | 用户明确确认 |
