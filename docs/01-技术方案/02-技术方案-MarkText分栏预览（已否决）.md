# 计划：基于 MarkText 打造分栏预览版 Mac Markdown 编辑器

> 工作代号：LightMark（已定名 **FU MD**）
> 日期：2026-10-15
> 状态：**已否决** —— 该方案过重（源码仓约 3GB、安装包 100MB+），已改为《01-技术方案-Swift原生即时渲染（已采纳）》

---

## 一、总结（Summary）

基于 **MarkText**（MIT 开源协议，2026 年已恢复活跃维护，最新 v0.21.x）进行二次开发，打造一款 Mac 端 Markdown 编辑器：

1. **新增「分栏实时预览」模式**：左侧 CodeMirror 源码编辑，右侧实时渲染预览（MarkText 原生没有此模式，本次核心开发内容）；
2. **保留并强化主题系统**：沿用现有多主题，预览区样式与主题联动，支持跟随系统亮暗。

**合规声明**：
- 不逆向、不提取 Typora 的任何代码或资源（违反其许可协议与知识产权）；
- MarkText 采用 MIT 协议，法律上允许修改与再分发，义务是**保留原版权声明与 LICENSE 文件**；
- 成品将改名（如 LightMark），避免与官方 MarkText 混淆。

**用户已确认的决策**：
| 决策项 | 选择 |
|---|---|
| 技术栈 | Electron，基于 MarkText 二次开发 |
| 编辑体验 | 分栏实时预览（左源码 + 右预览） |
| MVP 功能范围 | 主题系统（文件树/标签/导出等功能随 Fork 免费继承，不在本次新增范围） |

---

## 二、现状分析（Current State Analysis）

### 2.1 MarkText 项目现状（2026-10 调研）

- 仓库：`https://github.com/marktext/marktext`，MIT 协议，约 56.8K Star；
- 2022-03（v0.17.1）后沉寂四年，**2026-05 复活**：5 月发布 v0.19.0，当前已到 v0.21.x，日常有提交；
- 仓库已重组为 **pnpm monorepo**：`packages/desktop`（Electron 桌面应用）+ `packages/muya`（所见即所得编辑器内核，独立包 `@muyajs/core`，原独立仓库已并入主仓）。

### 2.2 与本任务相关的架构要点

- **主进程**（`packages/desktop/src/main/`）：IO、原生对话框、窗口管理、文件系统监听、IPC；
- **渲染进程**（`packages/desktop/src/renderer/`）：Vue 3 + Pinia，承载 Muya 所见即所得编辑器 **和 CodeMirror 源码编辑器** 两种视图；
- **已有源码模式**：基于 CodeMirror（行号、自动换行），编辑内容经约 1s 防抖提交回状态管理（`LISTEN_FOR_CONTENT_CHANGE`）——这是分栏模式左栏的直接复用对象；
- **已有 HTML 渲染管线**：HTML 导出基于 `marked` 解析 + `DOMPurify` 消毒，代码高亮用 Prism——分栏模式右栏直接复用此管线，保证预览与导出观感一致；
- **已有主题系统**：多套 CSS 主题（如 Cadmium Light、Material Dark），Muya 样式与 Prism 亮/暗主题分离存放；
- **编辑形态**：所见即所得（默认）、源码模式、打字机模式、专注模式——**没有分栏模式**，路线图曾把「源码模式加预览」列为规划项，正好由本计划实现。

### 2.3 风险与已知问题

| 风险 | 应对 |
|---|---|
| 代码库大，首次构建可能踩坑（native 模块、pnpm 版本） | 阶段 0 优先把原版 `pnpm dev` 跑通作为基线，再动代码 |
| 网上文档多为旧目录结构（`src/renderer/...`），v0.21.x 已改 monorepo | 所有文件路径以实际克隆代码为准，阶段 0 完成路径勘探后再编码 |
| macOS 未签名应用的 Gatekeeper 拦截 | 自用场景 ad-hoc 签名 + `xattr -d com.apple.quarantine` 清除隔离标记 |
| 官方 v0.21.0 的 arm64 包曾有签名损坏问题（仅影响官方预编译包，不影响源码构建） | 我们从源码自行构建，不受影响 |

---

## 三、实施步骤（Proposed Changes）

### 阶段 0：环境准备与基线跑通

1. 检查本机工具链：`node`（>= 18/20，以仓库 `package.json` engines 为准）、`pnpm`、`git`；
2. `git clone https://github.com/marktext/marktext.git` 到本项目工作区；
3. `pnpm install` → `pnpm dev`（或仓库规定的启动脚本）跑通原版应用，确认基线可用；
4. **路径勘探**（写代码前必做，以实际代码为准）：
   - 源码模式组件（对应旧结构的 `sourceCode.vue`）及其 CodeMirror 初始化配置；
   - 视图形态的状态定义与切换逻辑（Pinia store / preferences）；
   - 应用菜单与快捷键注册位置（main process menu + keybinding，macOS 键位表）；
   - 主题 CSS 的存放与加载机制；
   - HTML 导出工具（marked + DOMPurify 封装）的位置与签名。

### 阶段 1：新增「分栏实时预览」模式（核心）

**交互设计**：
- 新编辑形态 `split`，与现有 `source`（源码模式）并列；
- 入口三处：菜单「视图 → 分栏模式」、macOS 快捷键（候选 `Cmd+Alt+P`，实现时避开现有键位冲突）、底部/顶栏切换按钮（若现有形态按钮存在则并列加入）；
- 布局：左右各 50%，中间可拖拽分隔条；窄窗口（< 700px）自动退化为单栏源码模式。

**实现要点**：
1. **左栏**：复用源码模式组件（CodeMirror 实例），不改动其编辑与防抖提交逻辑；
2. **右栏**：新建 `PreviewPane` 组件，渲染管线复用导出模块的 `marked + DOMPurify`，附加 Prism 代码高亮；
3. **渲染时机**：监听同一份内容变更状态，300ms 防触发器式防抖重渲染；仅在分栏模式激活时渲染，避免后台开销；
4. **滚动同步**（MVP 策略）：按源码/预览滚动百分比近似同步；预览内标题元素打锚点，做基于最近标题的粗对齐（不做完整 AST 行级映射，留作后续迭代）；
5. **状态与 IPC**：形态切换走现有 preferences/视图状态通道，不新开 IPC 面。

**MVP 渲染范围**：GFM 全量（标题/列表/表格/任务列表/代码块高亮/引用/图片/链接）+ 删除线；KaTeX 公式与 Mermaid 图表若复用现有依赖成本低则接入，否则列入后续迭代（在计划中按「尽力接入、不承诺」处理）。

### 阶段 2：主题系统（MVP 功能）

1. 沿用现有主题切换（Cadmium Light、Material Dark 等），不重写机制；
2. **预览区主题联动**：`PreviewPane` 样式消费现有主题 CSS 变量/类名，保证分栏左右观感一致；预览排版参考 GitHub 风格的可读性标准（字号、行高、代码块、表格边框）；
3. **跟随系统亮暗**：若现有版本已支持则验证即可；没有则新增 `auto` 主题选项，监听 `nativeTheme` 的 `prefers-color-scheme` 自动切换；
4. **自定义主题**：沿用/补齐用户自定义 CSS 注入入口（官方近期有 custom CSS 相关修复，说明机制存在），提供一个「打开主题目录」菜单项便于用户放自定义 CSS。

### 阶段 3：Mac 打包与交付

1. `electron-builder` 产出 dmg（本机为 Apple Silicon，优先 arm64；脚本保留 x64 目标）；
2. 应用更名（LightMark）+ 区分图标，避免与官方 MarkText 混淆；
3. **保留 LICENSE 与原版权声明**（MIT 义务），在「关于」页注明 based on MarkText (MIT)；
4. ad-hoc 签名，输出本地安装验证步骤（含清除 quarantine 的说明）。

### 明确不做（本次范围外）

- 不裁剪 MarkText 现有功能（文件树、多标签、导出等全部保留）；
- 不做精确 AST 级滚动映射、不做协同编辑、不做云同步；
- 不改动 Muya 所见即所得内核（零接触，降低回归风险）。

---

## 四、假设与决策记录（Assumptions & Decisions）

| # | 决策 | 理由 |
|---|---|---|
| D1 | 基于官方仓库 fork 二次开发，而非从零写 | 用户明确选择；文件树/标签/导出/主题免费继承 |
| D2 | 预览渲染用 `marked + DOMPurify`（与导出管线一致），不引入 markdown-it | 减少新依赖；预览与导出结果一致 |
| D3 | 左栏复用源码模式的 CodeMirror 组件 | 官方已有成熟实现（行号/换行/防抖提交），零重复造轮 |
| D4 | 滚动同步 MVP 用百分比 + 标题锚点近似 | 精确映射工作量大且易碎，先满足可用性 |
| D5 | 分栏为「第三形态」而非替换默认所见即所得 | 不破坏原有用户体验，回归风险最小 |
| D6 | 不逆向 Typora，仅参考其公开交互理念 | 法律合规红线 |
| D7 | 应用改名避免冒用 MarkText 品牌 | 商标与社区礼仪 |

---

## 五、验证方式（Verification）

1. **基线**：阶段 0 完成后 `pnpm dev` 启动原版，确认所见即所得/源码模式/主题切换正常；
2. **分栏功能**：打开含标题/表格/代码块/任务列表的示例 md → 切分栏 → 左侧输入 `# 标题`、表格语法，右侧 ≤300ms 内正确渲染；代码块有语法高亮；
3. **滚动同步**：长文档（500+ 行）滚动左栏，右栏按比例跟随；
4. **主题联动**：切换明暗主题，预览区同步换肤无撕裂；跟随系统模式下切换 macOS 外观自动响应；
5. **回归**：所见即所得模式、源码模式、文件打开/保存、导出 HTML/PDF 均不受影响；
6. **打包**：`electron-builder` 产出 dmg，拷贝到 `/Applications` 启动验证（含 quarantine 处理）。

---

## 参考资料

- MarkText 仓库：https://github.com/marktext/marktext （MIT License）
- MarkText v0.21.x 发布说明：https://newreleases.io/project/github/marktext/marktext/release/v0.21.0
- Star History 2026-05 独立 Markdown 编辑器盘点：https://www.star-history.com/blog/standalone-markdown-editor/
- MarkText 架构解读（社区）：https://blog.csdn.net/gitblog_00394/article/details/154590580
