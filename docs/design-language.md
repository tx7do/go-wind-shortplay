# 设计语言规范（Design Language）— GoWind ShortPlay（风印短剧）

> **定位**：本仓双端（React 管理后台 + Flutter App）视觉语言权威值表。任何颜色、圆角、尺寸、动效的调整，**先改本文档，再同步代码**；禁止只改代码不改文档。
> **分工**：
> - **管理后台**（第 2–4 章）继承上游 [go-wind-admin](https://github.com/tx7do/go-wind-admin) `docs/design-language.md` 的 vben 深蓝系规范（本仓只保留 react 端）。上游全文（含 ele / vben 端、对比度实测与沿革）是权威细本；本章收录**本仓实际消费的值**与本仓落点，两处冲突时以上游 + 本仓代码实值为准并回写本文档。
> - **Flutter App**（第 5 章）是 shortplay 特有的 C 端品牌设计语言，本仓自管。

---

## 1. 基本决策与理由

| 端 | 决策 | 理由 |
|---|---|---|
| admin | 主题模型与主色沿用底座 vben 深蓝 `hsl(212 100% 45%)` | 企业中后台审美；与 go-wind-admin / go-wind-cms 生态同源，底座同步不产生视觉漂移 |
| admin | 暗色中性色近黑蓝 `#0B0F19` 系 | 上游 react 端六轮定稿（2026-08-24），已随底座移植 |
| admin | 字体栈在底座基础上**补显式 CJK 名** | antd 默认栈无 CJK 名，中文回退不可控；本仓 `styles/global.css` 的 body 栈与 antd token `fontFamily` 保持同一份（§3） |
| app | **刻意去 MD3 化**：品牌渐变玫瑰红→紫 + 自绘导航 + 自建组件 | 国内 C 端短视频审美基线：高饱和品牌色、大圆角、重标题字重；MD3 默认的粉彩容器 / 胶囊指示器 / 水波纹与该基线相悖 |
| 双端 | 品牌名「风印短剧 / GoWind ShortPlay」 | 图标、文案、aria-label 一律用现名 |

---

## 2. Token 权威值表（admin）

约定：HSL 写法 `hsl(H S% L%)`；react 端 antd token 直接填色值字符串。自定义 CSS 一律引用 antd 生成的 `--ant-*` 变量或 `semantic-text.css` 的 `--gowind-*` 档，**组件内禁止裸色值**。

### 2.1 品牌色与语义色

| Token | 值 | ≈HEX | 用途 |
|---|---|---|---|
| `--primary` | `hsl(212 100% 45%)` | `#006BE6` | 主色；react 端 colorInfo 同值 |
| `--success` | `hsl(144 57% 58%)` | `#57D188` | 成功 |
| `--warning` | `hsl(42 84% 61%)` | `#EFBD48` | 警告 |
| `--destructive` | `hsl(348 100% 61%)` | `#FF3860` | 危险/错误 |
| `--primary-foreground` | `hsl(0 0% 98%)` | `#FAFAFA` | 主色上的文字 |

**语义色当文字用**（Tag 文字态、link/text/plain 按钮、链接等）不许直接用基准色（白底上 destructive 3.51 / success 1.93 / warning 1.74）：统一走「向中性墨（浅色）/ 向白（暗色）混色」的文字档 `--gowind-{primary,success,warning,danger}-text`（`styles/semantic-text.css`，浅 primary 90%→`#0162D2` / 暗 70%→`#4D97EE`，success/warning 50%/90%，destructive 70%/90%）。实底 success/warning 按钮前景用暗墨 `#0B0F19`（亮暗同值）；danger 实底与徽标数字回各 UI 库原生白字（用户裁决，暗墨坐红底刺眼）。

**暗色下 antd `darkAlgorithm` 自派生一套语义色**，浅色的「深墨前景」规则在暗色是倒退——浅色专属规则一律限定 `html[data-theme='light']` / `.light-mode`，暗色另走文字档。

### 2.2 中性色 · 浅色模式

| Token | 值 | 说明 |
|---|---|---|
| canvas（页面画布） | `#F1F3F6` | 大底，卡片在其上"浮起"（`lightTheme.ts` colorBgLayout） |
| surface（卡片/容器） | `#FFFFFF` | 卡片、表格容器、顶栏、侧栏 |
| 边框 | `#E4E4E7` | 通用边框（≈ zinc-200；`LIGHT_PALETTE.borderCard`） |
| 文字-主 / 常规 | `#1F2937` / `#374151` | 标题重点 / 正文（`semantic-text.css`） |
| 文字-次要 | `#676E7C` | `constants.ts` 的 `SECONDARY_TEXT_LIGHT`；辅助说明、描述表标签（在白/画布/卡片灰/表头灰上全部 ≥ 4.5） |
| 文字-占位 | antd 出厂档（浅色不覆写） | 刻意保留 `rgba(0,0,0,.25)`：占位档的判据是与**同控件已输入值**的分离度，antd 档分离 6.06 倍优于钉 `#9CA3AF` 的 5.78 倍 |

浅色卡片投影：静止 `0 1px 2px rgba(0,0,0,.05)`、悬浮 `0 4px 12px rgba(0,0,0,.08)`（`styles/global.css`）；同一层级、无叠放关系的并列容器必须同档（搜索卡与列表卡亮色同静止档、暗色同为 none）。

### 2.3 中性色 · 暗色模式

明度随层级递增，"越向前越亮"：

| 层级 | 值 | 用途 |
|---|---|---|
| L0 大底 | `#0B0F19` | 页面画布、Layout 大背景 |
| L1 表面 | `#111827` | 卡片、抽屉、表格容器、侧栏、顶栏；**输入控件与表面同层**，仅靠边框区分 |
| 浮层 | `#1C2128` | 下拉、弹窗、Popover、折叠侧栏的弹出子菜单（`Menu.darkPopupBg`） |
| 表头 | `#1F2937` | 表格表头独立次级色（antd 不给 token，react 端只作观感目标） |

配套定稿（勿改）：

- **边框要"拒绝隐形"**：输入类 `rgba(148,163,184,.22)`（hover `.4`）、通用 `rgba(148,163,184,.28)`、卡片描边/分隔线 = 8% 白 `rgba(255,255,255,.08)`（5% 时卡片与大底糊成一片，禁止回退）。
- **文字三阶**：主 `#F8FAFC`、次 `#8B949E`（`SECONDARY_TEXT_DARK`）、三级/placeholder `#6E7681`（placeholder 2026-10 由 `#9CA3AF` 下调——判据是与已输入值的分离度 4.39 倍；字段无真 label、占位符即字段名时（认证页）上抬次要档 `#8B949E` 并补 `aria-label`）；表单标签 `#DCE3ED`。
- **投影必须用黑**：浮层 `0 6px 16px rgba(0,0,0,.45), 0 3px 6px rgba(0,0,0,.3)`（darkAlgorithm 派生的白投影在暗底不可见）；暗色卡片投影 `none`（靠 L1 面 + 8% 白描边分离）。
- 主色 α 衍生（随 2.1 主色联动）：行 hover `rgba(0,107,230,.08)`、选中 `.15`、focus 柔光 `0 0 0 3px rgba(0,107,230,.12)`。

### 2.4 圆角

控件（按钮/输入/选择）**8px**；卡片/抽屉/弹窗 **12px**（`borderRadiusLG`）；认证面板 **24px**；胶囊（Tag/开关）999px。

### 2.5 字体

**本仓栈**（`styles/global.css` body 与 `ThemeProvider` / `useThemeConfig` 的 antd `fontFamily` **同一份**，含显式 CJK 名——与上游 react 端"无 CJK 名"的差异是本仓有意为之）：

```
-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial,
'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', 'Source Han Sans SC', 'Noto Sans SC',
sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'
```

字号：控件 14 / 表格 13 / 卡片标题 16 / 页面标题 18；字重正文 400、标题与强调 600；表格数字列建议 `tabular-nums`。改栈必须 body 与 antd token 两处同步（§3）。

### 2.6 布局尺寸

| 项 | 值 |
|---|---|
| 侧栏展开 / 折叠 | 224px / 48px（折叠态不引入竖排标题，几何不可行，见上游 §2.6 结案） |
| 顶栏 / 页签栏 | 50px / 38px |
| 内容边距 | 16px；搜索卡/列表卡内缩 20px 四边、**只有一条来源**（pro 自带查询表单 padding 归零） |
| 搜索卡 → 列表卡 / 表格 → 分页器 | 16px / 16px |

### 2.7 动效

页面切换 `fade-slide` 240ms `ease-in-out`、位移 8px、只做起不做落；侧栏折叠**一条时钟**（参与属性统一 240ms `cubic-bezier(.4,0,.2,1)`，禁止多属性各带时长）；全局动效开关（`preferences.transition.enable`）与 `prefers-reduced-motion` 必须生效；内容 loading 骨架屏优先（出场阈值 250ms）。

---

## 3. Admin 落点索引（react 端）

| 本规范 | 本仓落点 |
|---|---|
| 主色/语义色 2.1 | `src/core/preferences/config/default.ts`（colorPrimary 等） |
| 暗色分层/边框/文字/placeholder 2.3 | `src/core/preferences/config/darkTheme.ts`（`DARK_PALETTE` + `darkThemeTokens`，含 `Menu.darkPopupBg`、`darkSubMenuItemBg`/`subMenuItemBg` = transparent） |
| 浅色画布/容器/边框/大圆角 2.2 | `src/core/preferences/config/lightTheme.ts`（`LIGHT_PALETTE` + `lightThemeTokens`）+ `styles/global.css` 卡片投影两档 |
| 次要文字档 2.2/2.3 | `src/core/preferences/config/constants.ts`（`SECONDARY_TEXT_LIGHT/DARK`）+ `styles/semantic-text.css`（`--gowind-*-text`，覆盖规则带 `!important`） |
| **字体同栈 2.5** | `src/styles/global.css` 的 body 栈 = `ThemeProvider/index.tsx` 与 `hooks/useThemeConfig.ts` 的 token `fontFamily`——**antd 组件字体与全局 body 同栈**（antd 默认栈无显式 CJK 名），两处任一改动必须三处同步 |
| 斑马纹/表格容器/投影/分隔线 4 | `src/components/common/ListTable/` + `src/styles/pro-components-dark.css` |
| 侧栏尺寸/折叠时钟 2.6/2.7 | `src/layouts/MainLayout/components/SiderMenu/index.tsx` + `src/styles/pro-layout-overrides.css` |
| 路由入场动效 2.7 | `src/layouts/MainLayout/index.tsx`（`.page-transition`，按 `preferences.transition.name` 挂档） |
| 偏好迁移 | `src/core/preferences/store/index.ts` persist v2：默认主题回归 vben 深蓝、圆角 8（仅内置 default 主题迁移，用户自选不受影响） |

---

## 4. 组件级视觉惯例（admin）

- **页面容器**：canvas 大底 → 搜索卡（surface）→ 工具栏 → 表格卡（surface + 阴影）；盒子（border/radius/shadow）打在宿主卡片层，`.ant-table` 只留网格线。
- **表格**：无边框；**斑马纹默认开**（`ListTable` 的 `striped` 缺省 true，页面可显式关；`rowClassName` 叠加不覆盖）。色值：亮 `var(--ant-color-fill-quaternary)`、暗 `rgba(255,255,255,.03)`（antd 同名 token 暗色是 `.06` 重一倍，故显式落规范值不走 token）；占位行（暂无数据）不吃条纹；固定列条纹走 `background-image` + hover 清除，防 sticky 透字。
- **侧边栏菜单交互态**：悬停中性灰遮罩（8px 圆角）；**选中 = 主色实底 + 白字 + 8px 圆角药丸**，禁止左侧竖条 / 淡底 / 字重加粗；**父级展开链路只做文字/图标提亮，不铺底色**——必须在 token 层关（`darkSubMenuItemBg` 出厂 `#000c17` 更黑，只删 CSS 会露出藏青井），且 `darkSubMenuItemBg` / `subMenuItemBg` 两个键都要写（cssVar 模式下喂不同变量）。折叠弹出的子菜单浮层容器 = `#1C2128`（`Menu.darkPopupBg`，出厂藏青 `#001529` 与本仓暗色蓝黑系不同源）。
- **按钮**：主按钮一律 UI 库原生扁平实色 + 原生 `0 2px 0` 底投影，禁顶部高光渐变与品牌色发光投影；hover 改 `background-color`/`color`，禁 `filter: brightness()`；**禁用态一律去实底**（中性 rgba 底 + 25% 字），不许"主色底变浅一档"。
- **实底主色标"位置"不标"次级动作"**：列表面板里的"新建 X"用中性描边，避免与导航选中同色同形。
- **列表加载态**：首屏骨架 / 表内刷新 Spin / 失败错误态+重试，阈值 250ms；骨架复用页面 columns、两向 scroll 都接；列表 `request` 不许自己 catch（错误抛给 `ListTable` 带原始对象内联展示——全仓铁律 1）。
- **抽屉/表单**：输入控件底与表面同层、`rgba(148,163,184,.22)` 边框区分；focus 主色边框 + 3px 12% 柔光；抽屉遮罩 `rgba(0,0,0,.6)`、宽度基准 480；抽屉底部区与体同色、靠 8% 白发丝线分隔（antd v6 的分隔线变量是 `--ant-color-split`，`--ant-border-color-split` 是 v5 旧名，写错整条静默失效）。
- **认证页**：画布深底 + 实底表面卡（24px 圆角、主色柔影）；暗色占位符上抬次要档并补 `aria-label`（字段无 label 时占位符即字段名）。
- **页签栏**：chrome 形态 38px；选中走温和配方（浅 = 主色 15% 底 + 主色文字档、暗 = 中性灰底 + 正常亮文字），禁主色描边/发光/底部指示线/字重加粗。
- **错误/兜底页、全局搜索面板、默认头像**等其余惯例细本见上游 `go-wind-admin/docs/design-language.md` §4（本仓按需裁剪采用）。

---

## 5. Flutter App 端品牌设计语言（shortplay 特有）

### 5.1 基本决策：去 MD3 化

国内 C 端短视频审美基线：**高饱和品牌色 + 大圆角 + 重标题字重**；刻意避开 MD3 默认的粉彩容器 / 胶囊指示器 / 全域水波纹观感。Material 3 仅作骨架（ColorScheme/组件基类），品牌层全部自建。**新页面必须沿用本章语言**；改任何值先改本章再改代码。

### 5.2 品牌色（`core/themes/app_colors.dart` → `BrandColor`）

| Token | 值 | 用途 |
|---|---|---|
| `rose` | `#FF3D77` | 品牌主色（App 图标渐变起点）；点赞 / 主 CTA 同色 |
| `violet` | `#8B5CF6` | 品牌渐变终点（紫） |
| `roseDeep` | `#E62E66` | 深一档玫瑰红（白底小字号文本，保对比度） |
| `roseBright` | `#FF5C8F` | 暗色模式主色（黑底上提亮一档） |
| `collect` | `#FFB43A` | 收藏/星标（琥珀黄，与点赞红区分） |
| `gradient` | rose → violet，135°（左上→右下） | 品牌渐变（与 App 图标同源） |

### 5.3 亮 / 暗语义色板（同文件 `LightPalette` / `DarkPalette`）

| 层级 | 亮色 | 暗色 |
|---|---|---|
| 页面背景 bg | `#F5F6FA` | `#0C0C12` |
| 表面 surface | `#FFFFFF` | `#16161E` |
| 卡片 card | — | `#1E1E28` |
| 输入底 inputFill | `#F2F3F8` | `#23232E` |
| 素材底 chipFill | `#F1F2F7` | `#23232E` |
| 分隔 divider | `#ECECF2` | `#262631` |
| SnackBar | `#2B2B33` / 字 `#F5F5FA` | `#2E2E3A` / 字 `#F5F5FA` |

暗色是**深空黑微紫调**（非死黑非蓝灰），与 admin 端近黑蓝系（§2.3）分属两套——C 端沉浸观感与中后台层级观感各自成立，不互相拉齐。亮暗两套经 `themes/dark_theme.dart` / `light_theme.dart` 映射进 `ColorScheme`。

### 5.4 组件规范（`core/widgets/`）

- **GradientButton**：品牌渐变主按钮，**仅页面级 CTA 使用**（登录/发布/关注等）；普通实心按钮走 FilledButton 主题，不得滥用渐变。缺省胶囊形（radius 100）、高 48、白字，rose α 投影；禁用态去渐变改中性 α 底。
- **EmptyState**：统一空态/引导态——图标软底圆 + 标题 + 副标题 + 可选渐变操作；`onDark` 用于视频黑底沉浸页（图标/文案反白）；矮窗口下可滚动防溢出。
- **AppBottomNavBar**：**自绘底导**（无 MD3 胶囊指示器/水波纹）：图标 + 小字标签，选中态品牌色加重（亮 `rose` / 暗 `roseBright`），角标品牌红胶囊；**实体栏**（不透明，与抖音一致仅顶部栏沉入视频，底栏不与视频叠加），顶部分隔线 6% 发丝线。
- **BrandLogoMark**：品牌标（渐变底 + 播放键）代码绘制，免资产依赖；圆角 `size*0.28`、rose α 柔影。
- **feed 互动件**：`feed_progress_bar.dart`（观看进度）、`like_burst.dart`（点赞爆裂动效）属沉浸层品牌反馈。

### 5.5 品牌图标资产

母版与渲染脚本在 `frontend/app/assets/brand/`；**v3 渐变白标为正式方案**（法律安全：纯自绘渐变 + 白色播放键），全平台图标（Android mipmap / adaptive、iOS AppIcon、Web favicon/icons、Windows ico）由母版重渲染，**重渲染须 DPR:1**。中间候选稿（v1/v2/v4/v5）仅留档，不再使用。

### 5.6 设置页（`features/settings/`）

系统设置全屏路由 `/settings`，游客可用（外观/语言是设备级偏好）：主题模式 / 语言切换等经 `core/preference` 持久化，控件样式沿用本章组件。

---

## 6. 治理规则

1. **本文档先行**：视觉值变更 = 改本文档 → 同步代码 → 亮/暗两态截图对照，一个 PR 完成。admin 端若改动与上游共管的值（§2.1–2.4），须同步回上游 go-wind-admin 仓库，避免下次底座同步回退。
2. **禁止硬编码**：组件内不得出现裸色值/裸圆角——admin 走 antd token / `--ant-*` / `--gowind-*`；app 走 `BrandColor` / `LightPalette` / `DarkPalette` / `ColorScheme`。
3. **新增语义色**：先入值表（§2.1 或 §5.2），再落代码，含文字档与暗色档。
4. **App 新页面必须沿用 §5 语言**：CTA 用 GradientButton、空态用 EmptyState、底导不自绘第二份；发现 MD3 默认观感残留（胶囊指示器/粉彩容器）按回归处理。
5. **门禁**：admin `pnpm run typecheck` + `pnpm run lint`；app `flutter analyze`（No issues found）+ `flutter test`。

---

## 7. 维护记录

- 2026-10-19 首版：admin 部分随底座同步（go-wind-admin `24f75c38` 水位）引入并按本仓实值裁剪收录（字体栈补 CJK、浅色 token 层、斑马纹默认开、折叠浮层收口、认证页占位符提档）；app 部分随品牌改版定稿（品牌更名风印、v3 渐变白标、去 MD3 化组件体系）。此前代码注释中的 `docs/design-language.md` 引用自本版起全部可解析。
