# SoundOut 开发标准

本文档规定 SoundOut 的版本、界面、Flutter、原生 Android、数据、权限、构建与验收标准。后续修改默认按本文执行。

- 当前版本：`0.2.2:01-BS08`
- 应用 ID：`com.rudan.soundout`
- 最低 Android：API 24
- 目标 Android：API 36
- 技术栈：Flutter 3.47+ / Dart 3.13+ / Kotlin / Android SDK 36

## 1. 版本管理

1. 正式交付必须递增版本号，不允许沿用上一版权本号。
2. `pubspec.yaml` 使用语义化版本，例如 `0.1.2+3`。
3. Android `versionName` 使用带构建标识的格式，例如 `0.1.2:01-AS03`。
4. 每次发版必须同步更新以下位置：
   - `pubspec.yaml`
   - `android/app/build.gradle.kts` 的 `versionName`
   - `assets/version.json`（版本号、构建号、`versionCode`、更新内容）
   - 设置页「关于 SoundOut」的版本值
   - 关于页版本胶囊与应用信息
   - 开源许可页 `applicationVersion`
   - `README.md`
   - `dist/` 中 APK 文件名
5. 不允许只改关于页而不改 APK 包内版本，反之亦然。
6. 每次发版更新 `dist/SHA256SUMS.txt`，并创建 GitHub Release，上传 APK 与校验文件。
7. `assets/version.json` 必须与 `pubspec.yaml` 的版本、`versionName` 保持一致；应用内更新检测以该文件的 `versionCode` 与 `versionName` 为准。

## 2. Flutter 代码规范

1. 使用 `dart format` 保持格式统一。
2. 提交前必须通过：
   ```bash
   flutter analyze
   flutter test
   ```
3. 不引入承担单一小功能的第三方依赖；优先使用 Flutter SDK 与原生 Android API。
4. 状态管理保持轻量：当前使用 `ChangeNotifier` + `InheritedNotifier`，不要为此引入大型状态框架。
5. 页面拆分保持「页面 / 通用组件 / 原生桥接 / 模型」边界，不在页面里直接操作 MethodChannel。
6. MethodChannel、EventChannel 名称保持：
   - `soundout/native`
   - `soundout/playback`
7. 异步操作必须处理 `context.mounted`；不能在 `await` 之后直接使用失效的 `BuildContext`。
8. 用户可见错误必须有反馈，不允许静默失败。

## 3. 界面与交互标准

### 3.1 整体风格

1. 使用 Material 3，主色沿用当前绿色体系。
2. 参考 FlClash / ConcertPlay 的留白、圆角、分组列表和浮动 Dock，不做通用模板化 UI。
3. 同时适配浅色、深色系统和 1.3 倍字体缩放。
4. 页面背景、卡片、浮层表面层级必须明确：
   - 页面：`surface`
   - 列表卡片：浅色 `surfaceContainerLowest`，深色 `surfaceContainerLow`
   - 浮层/菜单：`surfaceContainerLowest`（浅）或 `surfaceContainerHigh`（深）
5. 卡片圆角使用 20dp，浮层外层 24–28dp，内部行 16dp。
6. 分隔线统一 0.5px，颜色为 `onSurface` 8% 透明度。
7. 触控目标不小于 44dp；主要按钮高度 44–48dp。

### 3.2 底部 Tab

1. 使用项目内的 `NavigationDock` 实现，不替换为标准 Material NavigationBar。
2. 必须支持：
   - 点击切换
   - 页面左右滑动切换
   - 在 Dock 上横向拖动切换
   - 弹簧镜头、按压回弹、haptic
3. 改动 Dock 时必须对照 ConcertPlay / FlClash 的 `NavigationDock` 行为，不自行简化动画。
4. 页面底部留白使用 `NavigationDock.insetOf(context)`，禁止写死固定 bottom padding。

### 3.3 列表

1. 音频列表、设置列表统一使用分组卡片样式：单张白色/深色卡片内放多行，行间 0.5px 分隔。
2. 列表行最小高度 56dp，水平内边距 16dp；内容行使用 12dp 左右内边距。
3. 不显示原始 ID3 artist、文件大小等干扰信息；音频列表只显示标题和时长。
4. 默认音频用图标/轻量底色标记，不使用大面积高饱和背景。
5. 导入重复音频必须先去重，不允许产生重复行。

### 3.4 底部抽屉与菜单

1. 禁止直接使用默认 `showModalBottomSheet` 外观和默认 `PopupMenuButton`。
2. 选项、音频选择、桌面入口统一使用 `showAppSheet`：
   - 顶部圆角 28dp
   - 18px 背景模糊
   - 半透明表面
   - 17px 标题、右侧关闭按钮
   - 行间 0.5px 分隔
3. 音频更多菜单统一使用 `showAppPopupMenu`：
   - 外层圆角 24dp
   - 菜单项圆角 16dp
   - 图标 18dp
   - 选中项显示 check
4. 新菜单必须支持点击外部关闭、选中回调、危险操作红色。

### 3.5 音频滑块

1. 必须使用主题里的统一滑块样式：
   - `HandleThumbShape`
   - `GappedSliderTrackShape`
   - 轨道高度 16dp
   - 把手默认 4×32dp，按压 2×36dp
   - 轨道间隙 6dp
2. 禁止在业务页面单独覆盖成圆形 Material 滑块。
3. 拖动时更新本地值，`onChangeEnd` 才持久化。

### 3.6 图标与图片

1. 应用提供「初始品牌图标」「照片图标」与「自定义图标」：内置图标资源为 `assets/images/app_icon_original.png` 与 `assets/images/app_icon_photo.png`，Android 侧通过 `activity-alias` + mipmap 资源切换；自定义图标由用户从相册选择，保存在 `files/custom_icon.png`，用于应用内展示并生成桌面快捷方式（Android 不支持应用运行时直接替换桌面本体图标）。
2. 启动画面不展示应用图标；首次启动的引导页展示当前应用图标。
3. 快捷方式图标优先使用音频内嵌专辑封面，无封面才回退到通用音频图标。
4. 通知小图标必须是单色矢量图标，不能使用彩色照片。
5. 新增图片资源必须同时放入 Flutter assets 和 Android 对应密度目录（如需要）。

## 4. 原生 Android 标准

1. 文件导入使用 SAF（`ACTION_OPEN_DOCUMENT`），不申请存储权限。
2. 导入在后台线程完成，主线程只负责回传结果。
3. 原生与 Flutter 共享数据统一通过 `NativeStore`，不要各自维护一套副本。
4. 播放使用前台 `PlaybackService`：
   - 必须声明 `foregroundServiceType="mediaPlayback"`
   - 必须处理音频焦点、唤醒锁、通知停止
   - 播放结束必须释放 MediaPlayer 与通知
5. 快捷方式：
   - 动态快捷方式用于长按应用图标
   - 置顶快捷方式使用 `requestPinShortcut`
   - 快捷方式图片优先专辑封面
   - 删除音频时禁用相关已固定快捷方式
6. 小组件：
   - 使用 RemoteViews 原生组件
   - 当前标准尺寸为 **4×2**，`minWidth=250dp`、`minHeight=120dp`
   - 不要在未验证兼容性的情况下改回 4×1 或过小的 40dp 高度
   - 小组件配置使用原生 `WidgetConfigActivity`
   - 每个小组件实例独立保存选中的音频
7. 小组件/快捷方式系统添加：
   - 快捷方式使用 `requestPinShortcut`，触发系统「添加到主屏幕」确认
   - 小组件使用 `requestPinAppWidget`，触发系统固定小组件确认
   - 启动器不支持时只能提供手动添加说明，不得谎称已添加
   - 请求前保证 Activity 已恢复前台，避免窗口切换吞掉请求

## 5. 权限标准

1. `POST_NOTIFICATIONS`：首次在应用内播放时请求。
2. `INTERNET`：仅用于从 GitHub 读取 `version.json`、查询 Release 与下载更新安装包。
3. `REQUEST_INSTALL_PACKAGES`：更新时唤起系统安装器；运行时若未授权，跳转系统「安装未知应用」设置。
4. `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_MEDIA_PLAYBACK`、`WAKE_LOCK`：清单声明。
5. 快捷方式权限：
   - Android 8+ 优先使用 `requestPinShortcut` 的系统确认框
   - 小米 / 华为 / 荣耀 / OPPO / vivo 桌面不支持该 API 时，退回旧版 `INSTALL_SHORTCUT` 广播
   - 清单仅声明 `INSTALL_SHORTCUT` 与各 launcher 的兼容权限，运行时禁止申请，不得弹权限对话框
   - 厂商的「桌面快捷方式 / 创建桌面快捷方式」「自启动」开关只能引导用户去系统设置，不能伪造系统权限
4. 小组件兼容：
   - API 26+ 优先 `requestPinAppWidget`，不支持时按 ROM 给出对应的手动添加路径
   - 小组件信息声明 `configuration_optional` 与 `previewImage`，避免部分国产桌面因配置页或预览缺失而无法添加
   - 全部添加请求都必须有「打开权限设置」降级入口

## 6. 数据与文件

1. 音频文件位于 `files/audio/`，封面位于 `files/covers/`。
2. 库与设置存放在 SharedPreferences 的 `soundout` 文件：
   - `library`
   - `settings`
3. 音频记录必须包含：
   - `id`
   - `title`
   - `durationMs`
   - `path`
   - `coverPath`
   - `sizeBytes`
   - `addedAt`
   - `contentHash`
4. 导入去重规则：
   - 优先使用 SHA-256 `contentHash`
   - 老数据无 hash 时使用 `title + durationMs + sizeBytes` 兼容判断
   - 启动和导入后都执行去重，删除多余文件
5. 删除音频必须同时删除音频文件和封面，并同步刷新快捷方式、小组件、默认音频。
6. 音频始终本地处理，不上传；引入网络仅用于 GitHub 版本检测与更新下载，不引入统计/追踪 SDK。

## 7. 构建与打包

环境要求：Flutter 3.47+、Android SDK 36、JDK 21。

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build apk --release --split-per-abi
```

发布产物命名：

```text
SoundOut-<version>-<build>-arm64-v8a.apk
SoundOut-<version>-<build>-armeabi-v7a.apk
SoundOut-<version>-<build>-universal.apk
```

同时生成：

```bash
cd dist
sha256sum *.apk > SHA256SUMS.txt
```

当前 release 使用 debug 签名，仅用于本地安装测试；正式发布必须替换为正式签名。

## 8. 验收清单

每次交付前至少验证：

- [ ] 首次引导与多选导入
- [ ] 导入重复文件被去重，不出现重复行
- [ ] 列表只显示标题和时长，没有异常 artist/大小数据
- [ ] 音频删除后文件、快捷方式、小组件同步更新
- [ ] 播放、停止、重复次数、重复间隔、循环
- [ ] “直接播放”和“打开应用后播放”
- [ ] 系统快捷方式添加确认框正常出现，图标为专辑封面
- [ ] 系统小组件固定确认框正常出现，4×2 可实际添加到桌面
- [ ] 未配置小组件点按进入原生选择页，保存后播放
- [ ] Tab 点击、左右滑动、Dock 拖动
- [ ] 底部抽屉和更多菜单样式符合本文
- [ ] 音量滑块使用 FlClash 风格
- [ ] 深色模式、1.3 倍字体、返回行为
- [ ] 关于页版本号与实际 APK 一致
- [ ] `flutter analyze` 无问题，测试通过

## 9. 变更记录要求

每次版本提交必须说明：

1. 版本号变化
2. 功能变化
3. 原生/权限/兼容性变化
4. 已执行的验收项
5. 已知限制（例如特定启动器不支持自动固定小组件）

未完成上述内容，不视为可交付版本。
