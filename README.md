# SoundOut

把常用声音放到手边。导入几段音频，放到桌面，点一下就开始播放。

SoundOut 是一个 Flutter + 原生 Android 的轻量音频快捷播放器，界面与交互参考 FlClash 的 Material 3 风格。

后续修改请遵循 [开发标准](./DEVELOPMENT.md)。

- 版本：`0.2.2:01-BS08`
- 开发者：**ByRUDAN**
- 应用 ID：`com.rudan.soundout`

## 功能

- **首次引导**：引导导入一段或多段音频，也可以稍后再说。
- **多种导入**：调用 Android 原生文件选择器，支持一次多选，自动读取标题、艺术家、时长与内嵌封面。
- **图标快捷方式**：为每段音频生成 Android 动态快捷方式，图标优先使用音频内嵌专辑封面；长按桌面图标即可直接播放，也可以在应用内一键添加到桌面。
- **可滑动标签页**：底部导航栏移植自 ConcertPlay / FlClash 的浮动 Dock 实现，带弹簧镜头、按压回弹、拖动选择和滑动手感；页面也支持左右滑动切换。
- **分组列表与底部抽屉**：列表与设置分组参考 ConcertPlay 的视觉，使用白色分组卡、0.5px 分隔线；选项与音频选择使用自定义圆角底部抽屉。
- **桌面小组件**：原生 RemoteViews 小组件（4×2）。每个小组件实例可以独立选择音频，点按播放，点按齿轮重新选择。
- **后台播放**：原生前台 Service + MediaPlayer，支持锁屏后台播放、通知栏停止、音频焦点与唤醒锁。
- **播放设置**：默认音频、音量、是否与其他应用同时播放。
- **播放次数**：重复次数（1–10 次或循环）与重复间隔。
- **触发方式**：后台直接播放，或打开应用后播放。
- **关于页面**：版本号、开发者、开源许可与本地存储说明。
- **应用图标选择**：可在「设置 → 外观 → 应用图标」中切换初始品牌图标、照片图标，或从相册上传自定义图片；自定义图片用于应用内展示并生成带该图片的桌面快捷方式。
- **启动体验**：启动画面不展示图标，直接进入应用；首次启动的引导页保留当前应用图标。
- **原生体验**：Android 预测性返回、原生文件选择器、原生小组件配置页、原生通知与快捷方式。
- **纯净本地**：音频复制到应用私有目录，不上传网络；无第三方 Flutter 插件依赖。
- **在线更新**：从 GitHub 读取 `version.json` 与本机版本比对，发现新版本后从 GitHub Release 下载对应 ABI 的 APK 并唤起系统安装。仅版本检查与更新下载使用网络，音频始终留在本地。

## 使用

1. 首次打开，选择音频文件，可以一次选择多段。
2. 在首页点「添加到桌面」，选择「应用快捷方式」或「桌面小组件」发起系统添加请求。
3. 也可以长按桌面上的 SoundOut 图标，直接使用或拖动音频快捷方式。
4. 点按小组件的齿轮，选择该小组件要播放的音频并保存。
5. 点按小组件或快捷方式即可播放。通知栏、应用内迷你播放器都可以停止。
6. 若桌面没有出现添加提示，使用应用内的「没提示？」查看手动添加方法。
7. 在「设置 → 关于 → 检查更新」中可从 GitHub 获取最新版本并下载安装。

> Android 13 及以上首次在应用内播放时会请求通知权限。拒绝后音频仍可播放，但通知栏停止按钮不会显示。

> 快捷方式与小组件优先走系统确认框（`requestPinShortcut` / `requestPinAppWidget`）。小米、华为、荣耀、OPPO、vivo 等桌面不支持该 API 时，快捷方式会自动退回旧版 `INSTALL_SHORTCUT` 广播（清单声明、运行时不再申请权限，不会弹窗）；小组件则提示对应 ROM 的添加路径。若桌面未生效，可在提示框内直接打开该 ROM 的权限设置，允许「桌面快捷方式 / 创建桌面快捷方式」和「自启动」。

## 技术结构

```
lib/
  main.dart                     应用入口与主题/本地化
  src/
    app_model.dart             状态与原生桥接封装
    native_bridge.dart         MethodChannel / EventChannel
    models.dart                音频、设置、播放状态模型
    theme.dart                 Material 3 主题与系统栏样式
    pages/                     引导、音频、设置、关于、主页
    widgets/                   卡片、导航、迷你播放器、选项面板等
android/app/src/main/kotlin/com/rudan/soundout/
  MainActivity.kt              Flutter 引擎、频道、文件选择、权限
  AudioImporter.kt             SAF 多选导入、元数据/封面提取
  PlaybackService.kt           前台播放服务、重复播放、音频焦点
  PlaybackLaunchActivity.kt    快捷方式/小组件的透明启动入口
  AppShortcuts.kt              动态快捷方式同步
  SoundOutWidgetProvider.kt    原生小组件与更新
  WidgetConfigActivity.kt      原生小组件音频选择页
  NativeStore.kt               Flutter 与原生共享的本地数据
  LauncherIcon.kt              启动器图标切换（activity-alias）
  CustomIcon.kt                自定义图标导入与桌面快捷方式
```

音频库与设置保存在 SharedPreferences 中；音频文件位于应用私有目录 `files/audio`，封面位于 `files/covers`，自定义图标位于 `files/custom_icon.png`。

版本信息统一维护在 `assets/version.json`，同时作为 GitHub 上的远程版本源；更新流程由 `lib/src/update_service.dart` 与原生 `UpdateInstaller.kt` 完成。

## 构建

要求 Flutter 3.47+、Android SDK 36、JDK 21。

```bash
flutter pub get
flutter build apk --release
flutter build apk --release --split-per-abi
```

本项目的 release 构建默认沿用 debug 签名，仅用于本地测试。正式发布前请在
`android/app/build.gradle.kts` 中配置自己的签名。

## 已构建产物

`dist/` 中提供了可直接安装的 APK，选择其中一个安装即可：

| 文件 | 适用设备 | 大小 |
| --- | --- | --- |
| `SoundOut-0.2.2-01-BS08-arm64-v8a.apk` | 大多数现代 Android 手机（推荐） | 约 20 MB |
| `SoundOut-0.2.2-01-BS08-armeabi-v7a.apk` | 较旧的 32 位设备 | 约 17 MB |
| `SoundOut-0.2.2-01-BS08-universal.apk` | 所有 ABI，含模拟器 | 约 52 MB |

校验值在 `dist/SHA256SUMS.txt`。

## 说明

- 快捷方式与小组件均使用 Android 原生 API，不依赖第三方插件。
- 桌面启动器对快捷方式数量和小组件尺寸的支持可能不同；若启动器不支持自动固定小组件，会显示手动添加说明，并可改用音频快捷方式。
- 卸载应用会一并删除应用内保存的音频文件。
- 开源许可可在「设置 → 关于 → 开源许可」中查看。
