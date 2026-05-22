import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class _TrayWindowListener extends WindowListener {
  @override
  void onWindowClose() {
    windowManager.hide();
  }
}

class TrayService {
  static final TrayService _instance = TrayService._();
  TrayService._();
  factory TrayService() => _instance;

  final SystemTray _tray = SystemTray();
  final _TrayWindowListener _listener = _TrayWindowListener();

  VoidCallback? onTimerToggle;

  Future<void> init() async {
    await windowManager.setPreventClose(true);
    windowManager.addListener(_listener);

    await _tray.initSystemTray(
      iconPath: 'assets/icon.png',
      toolTip: 'Companion',
    );

    await _updateMenu(isTimerRunning: false);
  }

  Future<void> updateTimerState(bool running) async {
    await _updateMenu(isTimerRunning: running);
  }

  Future<void> _updateMenu({required bool isTimerRunning}) async {
    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Показать',
        onClicked: (_) => windowManager.show(),
      ),
      MenuItemLabel(
        label: 'Скрыть',
        onClicked: (_) => windowManager.hide(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: isTimerRunning ? 'Остановить таймер' : 'Запустить таймер',
        onClicked: (_) {
          onTimerToggle?.call();
          _updateMenu(isTimerRunning: !isTimerRunning);
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Выход',
        onClicked: (_) {
          windowManager.destroy();
          _tray.destroy();
        },
      ),
    ]);
    await _tray.setContextMenu(menu);
  }

  void dispose() {
    windowManager.removeListener(_listener);
  }
}
