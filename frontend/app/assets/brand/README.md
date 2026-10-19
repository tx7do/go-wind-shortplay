# GoWind ShortPlay 品牌图标资产

正式图标：**v5「双臂风涡」**——玫红紫渐变（#FF3D77→#8B5CF6）底 + 白色双臂气旋（锥形笔画，中心成太极动势）。图形由参数化螺线生成（见下"重渲染管线"），勿手改 pathData。

## 文件说明

| 文件 | 用途 |
|---|---|
| `gw-icon-v5-vortex.svg` | 正式母版（圆角磁贴，128 viewBox / 1024 输出） |
| `gw-icon-v5-vortex-fullbleed.svg` | 满幅版（iOS AppIcon / Android 底层用，无圆角） |
| `gw-icon-v5-vortex-maskable.svg` | PWA maskable（满幅 + 图形缩至 88% 安全区） |
| `gw-icon-cand-K/L-vortex.svg`、`renders/cand-*.png` | 同族备选字形 |
| `gw-icon-v3-gradient*.svg`、`gw-icon-v1/v4-*.svg` | 历史方案存档（v3 风线播放键已淘汰；v1 抖音同款仅供演示，**勿商用**） |
| `renders/` | 全部平台尺寸 PNG 产物（v5 与 ios-*.png 为当前生效文件） |

## 已落地的生效文件（由 renders/ 分发）

- `web/icons/Icon-{192,512}.png`、`Icon-maskable-{192,512}.png`、`favicon.png`（圆角磁贴版，**四角真透明**）
- `windows/runner/resources/app_icon.ico`（多尺寸 16/24/32/48/64/128/256，各尺寸原生渲染；**小帧 BMP(DIB)、仅 256 帧可 PNG**——Windows 对小尺寸 PNG 帧会丢 alpha 合成到白底）
- `web/favicon.ico`（16/32/48，同样小帧 BMP）
- `android/.../mipmap-*/ic_launcher.png`（传统五档，**满幅方版**——系统蒙版会自己裁形，预置圆角+透明角会与蒙版叠加出缺口）+ `mipmap-anydpi-v26/ic_launcher.xml`（自适应：渐变背景 / 白色风涡前景 / monochrome）
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`（15 张，无 alpha）
- `windows/runner/resources/app_icon.ico`

## 重渲染管线（改参数后一键重出）

SVG 母版由参数化螺线 node 脚本烘焙 → 生成渲染 HTML → 本地静态服务 + Playwright 截图出 PNG → node 校验尺寸后分发 + ICO 包装。注意：

1. **Playwright 必须 `deviceScaleFactor: 1`**（默认 1.5 会把所有 PNG 放大 1.5 倍）；
2. **圆角磁贴截图必须 `omitBackground: true`**——默认会把透明底压成白角（2026-10-19 白角问题根因）；满幅版不受影响；
3. iOS 图标必须无 alpha（全不透明元素 Playwright 自动存 RGB，满足）；
4. ICO 打包：小帧必须 BMP(DIB 32bpp + AND mask)，仅 256 帧允许 PNG；
5. 改字形后需同步重生成 `android/.../drawable/ic_launcher_foreground.xml`（矢量前景，由母版 pathData 生成）。
