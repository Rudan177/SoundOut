import 'package:flutter/material.dart';

import '../haptics.dart';

class HomeChromeInsets extends InheritedWidget {
  const HomeChromeInsets({
    super.key,
    required this.snackBarBottom,
    required super.child,
  });

  final double snackBarBottom;

  static HomeChromeInsets? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeChromeInsets>();
  }

  @override
  bool updateShouldNotify(HomeChromeInsets oldWidget) {
    return oldWidget.snackBarBottom != snackBarBottom;
  }
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final bottomInset = HomeChromeInsets.maybeOf(context)?.snackBarBottom ?? 16;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: action == null ? 2 : 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
        action: action,
      ),
    );
}

Future<bool> showDeleteAudioDialog(BuildContext context, String title) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text('删除这段音频？'),
        content: Text('「$title」将从音频库中移除，使用它的快捷方式和小组件也会同步更新。'),
        actions: [
          TextButton(
            onPressed: () {
              AppHaptics.tap();
              Navigator.of(context).pop(false);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () {
              AppHaptics.tap();
              Navigator.of(context).pop(true);
            },
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
