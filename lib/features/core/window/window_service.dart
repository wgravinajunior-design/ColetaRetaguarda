import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Controla o tamanho/posição da janela no desktop.
/// - Login: janela pequena, do tamanho do card, centralizada.
/// - App (após login): tela cheia (maximizada).
class WindowService {
  /// Tamanho da janela na tela de login (aproximadamente o tamanho do card).
  static const Size loginSize = Size(430, 720);

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Inicializa o window_manager. Chamar no main() antes do runApp.
  /// Já deixa a janela no modo login (pequena e centralizada).
  static Future<void> init() async {
    if (!_isDesktop) return;
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: loginSize,
      center: true,
      titleBarStyle: TitleBarStyle.normal,
      skipTaskbar: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.center();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  /// Modo login: janela pequena, do tamanho do card, centralizada.
  static Future<void> modoLogin() async {
    if (!_isDesktop) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    }
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setSize(loginSize);
    await windowManager.center();
  }

  /// Modo app: tela cheia (maximizada).
  static Future<void> modoApp() async {
    if (!_isDesktop) return;
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.maximize();
  }
}
