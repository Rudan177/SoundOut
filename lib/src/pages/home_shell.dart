import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../widgets/concert_navigation_dock.dart';
import '../widgets/desktop_entry_sheet.dart';
import '../widgets/mini_player.dart';
import '../widgets/ui_helpers.dart';
import 'audio_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final model = AppScope.read(context);
      unawaited(maybeOfferShortcutPermission(context, model));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    const miniHeight = 76.0;
    final dockInset = NavigationDock.insetOf(context);
    final playerVisible = model.playback.active;
    final pageBottom = dockInset + (playerVisible ? miniHeight + 8 : 0) + 18;
    final snackBarBottom = dockInset + (playerVisible ? miniHeight + 8 : 0) + 8;
    final audio = model.audioById(model.playback.audioId);

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) {
          _selectTab(0);
        }
      },
      child: Scaffold(
        body: HomeChromeInsets(
          snackBarBottom: snackBarBottom,
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView(
                  controller: _pageController,
                  physics: const PageScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  onPageChanged: (index) {
                    if (index != _index) {
                      setState(() => _index = index);
                    }
                  },
                  children: [
                    AudioPage(bottomPadding: pageBottom),
                    SettingsPage(
                      bottomPadding: pageBottom,
                      onOpenAudioTab: () => _selectTab(0),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.16),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: playerVisible
                          ? Padding(
                              key: const ValueKey('mini-player'),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              child: MiniPlayer(
                                snapshot: model.playback,
                                audio: audio,
                                onStop: () => model.stop(),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('mini-empty')),
                    ),
                    NavigationDock(
                      selectedIndex: _index,
                      onSelected: _selectTab,
                      destinations: const [
                        NavigationDockDestination(
                          icon: Icons.library_music_outlined,
                          label: '导入音频',
                        ),
                        NavigationDockDestination(
                          icon: Icons.tune_rounded,
                          label: '设置',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
