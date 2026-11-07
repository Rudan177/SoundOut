import 'package:flutter/material.dart';

import '../app_model.dart';
import '../haptics.dart';
import '../models.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_popup_menu.dart';
import '../widgets/app_sheet.dart';
import '../widgets/page_heading.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/desktop_entry_sheet.dart';
import '../widgets/ui_helpers.dart';
import 'about_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.bottomPadding,
    required this.onOpenAudioTab,
  });

  final double bottomPadding;
  final VoidCallback onOpenAudioTab;

  Future<void> _pickAppIcon(BuildContext context, AppSettings settings) async {
    final value = await showAppSheet<String>(
      context: context,
      title: '应用图标',
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: 3,
          separatorBuilder: (_, _) => Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 76,
            endIndent: 20,
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
          itemBuilder: (_, index) {
            final choices = [
              (defaultAppIcon, '初始品牌图标', '深绿底，播放与声波标识'),
              (appIconPhoto, '照片图标', '使用应用最初保存的照片'),
              (
                appIconCustom,
                settings.customIconPath == null ? '上传自定义图标' : '更换自定义图标',
                '从相册选择图片，并添加到桌面快捷方式',
              ),
            ];
            final choice = choices[index];
            final isSelected = settings.appIcon == choice.$1;
            return Material(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
              child: InkWell(
                onTap: () {
                  AppHaptics.tap();
                  Navigator.of(sheetContext).pop(choice.$1);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        if (choice.$1 == appIconCustom &&
                            settings.customIconPath == null)
                          _CustomIconPlaceholder(scheme: scheme)
                        else
                          AppIcon(icon: choice.$1, size: 44, radius: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                choice.$2,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                choice.$3,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (value == null || !context.mounted) return;
    if (value == appIconCustom) {
      try {
        final result = await AppScope.read(context).pickCustomIcon();
        if (!context.mounted || result.canceled) return;
        showAppSnackBar(
          context,
          result.pinned ? '自定义图标已保存，桌面快捷方式已添加' : '自定义图标已保存',
        );
      } catch (_) {
        if (context.mounted) showAppSnackBar(context, '无法读取所选图片，请重试');
      }
      return;
    }
    await _save(context, {'appIcon': value});
  }

  Future<void> _save(BuildContext context, Map<String, dynamic> patch) async {
    try {
      await AppScope.read(context).updateSettings(patch);
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, '保存失败，请重试');
    }
  }

  Future<void> _pinShortcut(BuildContext context, GlobalKey anchorKey) async {
    final model = AppScope.read(context);
    if (model.audios.isEmpty) {
      onOpenAudioTab();
      return;
    }
    final id = await showAppPopupMenu<String>(
      context: context,
      anchorKey: anchorKey,
      entries: [
        for (final audio in model.audios)
          AppMenuEntry(
            value: audio.id,
            label: audio.title,
            checked: model.defaultAudio?.id == audio.id,
          ),
      ],
    );
    if (id == null || !context.mounted) return;
    final audio = model.audioById(id);
    if (audio != null) {
      await pinAudioShortcut(context, model, audio);
    }
  }

  Future<void> _pinWidget(BuildContext context) async {
    await pinWidget(context, AppScope.read(context));
  }

  void _openAbout(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
  }

  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LicensePage(
          applicationName: 'SoundOut',
          applicationVersion: '0.3.0:01-BS16',
          applicationLegalese: 'ByRUDAN',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final settings = model.settings;
    const topPadding = 16.0;
    final defaultAudio = model.defaultAudio;
    final shortcutKey = GlobalKey();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('settings-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding, 20, 0),
              child: const PageHeading(title: '设置', subtitle: '播放与桌面入口'),
            ),
          ),
          SliverToBoxAdapter(
            child: SettingsSection(
              title: '音频',
              children: [
                if (model.audios.isEmpty)
                  SettingsRow(
                    icon: Icons.library_music_outlined,
                    title: '默认音频',
                    value: '未选择',
                    showChevron: true,
                    onTap: onOpenAudioTab,
                  )
                else
                  SettingsMenuRow<String>(
                    icon: Icons.library_music_outlined,
                    title: '默认音频',
                    value: defaultAudio?.title ?? '未选择',
                    selected: settings.defaultAudioId ?? '',
                    options: [
                      for (final audio in model.audios) (audio.id, audio.title),
                    ],
                    onChanged: (value) =>
                        _save(context, {'defaultAudioId': value}),
                  ),
                _VolumeTile(
                  value: settings.volume,
                  onChangedEnd: (value) => _save(context, {'volume': value}),
                ),
                SettingsSwitchRow(
                  icon: Icons.multitrack_audio_rounded,
                  title: '与其他应用同时播放',
                  value: settings.allowConcurrent,
                  onChanged: (value) =>
                      _save(context, {'allowConcurrent': value}),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SettingsSection(
              title: '播放次数',
              children: [
                SettingsMenuRow<int>(
                  icon: Icons.repeat_rounded,
                  title: '重复次数',
                  value: settings.playCountLabel,
                  selected: settings.playCount,
                  options: const [
                    (1, '1 次'),
                    (2, '2 次'),
                    (3, '3 次'),
                    (5, '5 次'),
                    (10, '10 次'),
                    (0, '循环播放'),
                  ],
                  onChanged: (value) => _save(context, {'playCount': value}),
                ),
                SettingsMenuRow<int>(
                  icon: Icons.timer_outlined,
                  title: '重复间隔',
                  value: settings.repeatIntervalLabel,
                  selected: settings.repeatIntervalMs,
                  options: const [
                    (0, '不等待'),
                    (500, '0.5 秒'),
                    (1000, '1 秒'),
                    (2000, '2 秒'),
                    (3000, '3 秒'),
                  ],
                  onChanged: (value) =>
                      _save(context, {'repeatIntervalMs': value}),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SettingsSection(
              title: '触发方式',
              children: [
                SettingsMenuRow<String>(
                  icon: Icons.touch_app_outlined,
                  title: '点按后',
                  value: settings.triggerModeLabel,
                  selected: settings.triggerMode,
                  options: const [('direct', '直接播放'), ('open_app', '打开应用后播放')],
                  onChanged: (value) => _save(context, {'triggerMode': value}),
                ),
                SettingsRow(
                  key: shortcutKey,
                  icon: Icons.bolt_outlined,
                  title: '应用快捷方式',
                  value: '添加',
                  onTap: () => _pinShortcut(context, shortcutKey),
                ),
                SettingsRow(
                  icon: Icons.widgets_outlined,
                  title: '桌面小组件',
                  value: '添加',
                  onTap: () => _pinWidget(context),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SettingsSection(
              title: '外观',
              children: [
                SettingsRow(
                  icon: Icons.apps_rounded,
                  title: '应用图标',
                  value: settings.appIconLabel,
                  showChevron: true,
                  onTap: () => _pickAppIcon(context, settings),
                ),
                SettingsSwitchRow(
                  icon: Icons.blur_on_rounded,
                  title: '液态玻璃',
                  subtitle: '卡片与浮层使用模糊透光玻璃质感',
                  value: settings.glassEffect,
                  onChanged: (value) => _save(context, {'glassEffect': value}),
                ),
                if (settings.glassEffect)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          '玻璃强度',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SegmentedControl<double>(
                            value: settings.glassStrength,
                            segments: const [
                              (0.0, '弱'),
                              (0.5, '中'),
                              (1.0, '强'),
                            ],
                            onChanged: (value) =>
                                _save(context, {'glassStrength': value}),
                          ),
                        ),
                      ],
                    ),
                  ),
                SettingsSwitchRow(
                  icon: Icons.vibration_rounded,
                  title: '点击震动',
                  subtitle: '按下按钮时给出轻微触感反馈',
                  value: settings.hapticsEnabled,
                  onChanged: (value) =>
                      _save(context, {'hapticsEnabled': value}),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SettingsSection(
              title: '关于',
              children: [
                SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: '关于 SoundOut',
                  value: '0.3.0:01-BS16',
                  showChevron: true,
                  onTap: () => _openAbout(context),
                ),
                SettingsRow(
                  icon: Icons.description_outlined,
                  title: '开源许可',
                  showChevron: true,
                  onTap: () => _openLicenses(context),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
        ],
      ),
    );
  }
}

class _CustomIconPlaceholder extends StatelessWidget {
  const _CustomIconPlaceholder({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Icon(
        Icons.add_photo_alternate_outlined,
        size: 21,
        color: scheme.primary,
      ),
    );
  }
}

class _VolumeTile extends StatefulWidget {
  const _VolumeTile({required this.value, required this.onChangedEnd});

  final double value;
  final ValueChanged<double> onChangedEnd;

  @override
  State<_VolumeTile> createState() => _VolumeTileState();
}

class _VolumeTileState extends State<_VolumeTile> {
  late double _value = widget.value;
  bool _dragging = false;
  late int _hapticStep;

  @override
  void initState() {
    super.initState();
    _hapticStep = (widget.value * 20).round();
  }

  void _handleChanged(double value) {
    final step = (value * 20).round();
    if (step != _hapticStep) {
      _hapticStep = step;
      AppHaptics.select();
    }
    setState(() {
      _dragging = true;
      _value = value;
    });
  }

  @override
  void didUpdateWidget(covariant _VolumeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (_value * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                percent == 0
                    ? Icons.volume_off_outlined
                    : Icons.volume_down_outlined,
                size: 17,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('播放音量', style: theme.textTheme.bodyLarge)),
              Text(
                '$percent%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: _value.clamp(0, 1).toDouble(),
            onChanged: _handleChanged,
            onChangeEnd: (value) {
              setState(() => _dragging = false);
              widget.onChangedEnd(value);
            },
          ),
        ],
      ),
    );
  }
}
