import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/headphone_controller.dart';
import '../../ui/theme/theme_controller.dart';

class TrayService with TrayListener, WindowListener {
  TrayService({
    required this.headphoneController,
    required this.themeController,
    this.startHidden = false,
  });

  final HeadphoneController headphoneController;
  final ThemeController themeController;
  final bool startHidden;
  bool _isInitialized = false;

  DateTime _lastActionTime = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastActionKey = '';

  Future<void> init() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.linux &&
            defaultTargetPlatform != TargetPlatform.windows)) {
      return;
    }

    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);

      trayManager.addListener(this);

      final iconPath = defaultTargetPlatform == TargetPlatform.windows
          ? 'assets/images/tray_headphones.ico'
          : 'assets/images/tray_headphones.png';
      await trayManager.setIcon(iconPath);
      if (defaultTargetPlatform == TargetPlatform.windows) {
        try {
          await trayManager.setToolTip('HLControl');
        } catch (_) {}
      }

      _isInitialized = true;
      await _updateMenu();

      headphoneController.addListener(_updateMenu);
      themeController.addListener(_updateMenu);

      if (startHidden) {
        await windowManager.hide();
      }
    } catch (e) {
      debugPrint('Failed to initialize TrayService: $e');
    }
  }

  Future<void> _updateMenu() async {
    if (!_isInitialized) return;

    final status = headphoneController.status;
    final isConnected = status.isConnected;
    final isConnecting = status.isConnecting || headphoneController.isConnecting;

    final deviceLabel = isConnected
        ? (status.deviceName.isNotEmpty ? status.deviceName : 'Headphones')
        : (themeController.lastConnectedName.isNotEmpty ? themeController.lastConnectedName : 'Headphones');

    final List<MenuItem> items = [];

    if (isConnected) {
      final anc = status.ancMode.toLowerCase();
      final isOff = anc.contains('normal') || anc.contains('off') || anc == '0';
      final isAnc = (anc.contains('anc') && !anc.contains('adaptive')) || anc == '1';
      final isAware = anc.contains('transparen') || anc.contains('aware') || anc == '2';
      final isAdaptive = anc.contains('adaptive') || anc == '4';

      final spatial = status.spatialAudioMode.toLowerCase();
      final isSpatialOff = spatial == 'off';
      final isSpatialStatic = spatial == 'static';
      final isSpatialDynamic = spatial == 'dynamic';

      items.addAll([
        // 1. ANC Modes
        MenuItem.checkbox(
          key: 'anc_off',
          label: 'ANC: Off',
          checked: isOff,
        ),
        MenuItem.checkbox(
          key: 'anc_on',
          label: 'ANC: On',
          checked: isAnc,
        ),
        MenuItem.checkbox(
          key: 'anc_aware',
          label: 'ANC: Aware',
          checked: isAware,
        ),
        MenuItem.checkbox(
          key: 'anc_adaptive',
          label: 'ANC: Adaptive',
          checked: isAdaptive,
        ),
        MenuItem.separator(),

        // 2. Spatial Audio
        MenuItem.checkbox(
          key: 'spatial_off',
          label: 'Spatial Audio: Off',
          checked: isSpatialOff,
        ),
        MenuItem.checkbox(
          key: 'spatial_static',
          label: 'Spatial Audio: Static',
          checked: isSpatialStatic,
        ),
        MenuItem.checkbox(
          key: 'spatial_dynamic',
          label: 'Spatial Audio: Dynamic',
          checked: isSpatialDynamic,
        ),
        MenuItem.separator(),

        // 3. Quick Toggles
        MenuItem.checkbox(
          key: 'game_mode',
          label: 'Game Mode',
          checked: status.gameMode ?? false,
        ),
        MenuItem.checkbox(
          key: 'wind_noise',
          label: 'Wind Noise Reduction',
          checked: status.windNoise ?? false,
        ),
        MenuItem.separator(),

        // 4. Device Connection Action
        MenuItem(
          key: 'disconnect',
          label: 'Disconnect ($deviceLabel)',
        ),
        MenuItem.separator(),
      ]);
    } else if (isConnecting) {
      items.addAll([
        MenuItem(
          key: 'connecting',
          label: 'Connecting ($deviceLabel)...',
          disabled: true,
        ),
        MenuItem.separator(),
      ]);
    } else {
      if (themeController.lastConnectedMac.isNotEmpty) {
        items.addAll([
          MenuItem(
            key: 'connect',
            label: 'Connect ($deviceLabel)',
          ),
          MenuItem.separator(),
        ]);
      } else {
        items.addAll([
          MenuItem(
            key: 'disconnected',
            label: 'Disconnected',
            disabled: true,
          ),
          MenuItem.separator(),
        ]);
      }
    }

    // 5. App Controls
    items.addAll([
      MenuItem(
        key: 'open_app',
        label: 'Open HLControl',
      ),
      MenuItem(
        key: 'quit',
        label: 'Quit',
      ),
    ]);

    final menu = Menu(items: items);
    await trayManager.setContextMenu(menu);
  }

  void _handleAction(String key) {
    final now = DateTime.now();
    // Debounce rapid duplicate invocations
    if (_lastActionKey == key && now.difference(_lastActionTime).inMilliseconds < 350) {
      return;
    }
    _lastActionKey = key;
    _lastActionTime = now;

    switch (key) {
      case 'anc_off':
        headphoneController.setAncMode(0);
        break;
      case 'anc_on':
        headphoneController.setAncMode(1);
        break;
      case 'anc_aware':
        headphoneController.setAncMode(2);
        break;
      case 'anc_adaptive':
        headphoneController.setAncMode(4);
        break;
      case 'spatial_off':
        headphoneController.setSpatialAudio('Off');
        break;
      case 'spatial_static':
        headphoneController.setSpatialAudio('Static');
        break;
      case 'spatial_dynamic':
        headphoneController.setSpatialAudio('Dynamic');
        break;
      case 'game_mode':
        final current = headphoneController.status.gameMode ?? false;
        headphoneController.setGameMode(!current);
        break;
      case 'wind_noise':
        final current = headphoneController.status.windNoise ?? false;
        headphoneController.setWindNoise(!current);
        break;
      case 'disconnect':
        headphoneController.disconnect();
        break;
      case 'connect':
        if (themeController.lastConnectedMac.isNotEmpty) {
          headphoneController.connect(themeController.lastConnectedMac);
        }
        break;
      case 'open_app':
        _toggleWindow(forceShow: true);
        break;
      case 'quit':
        exit(0);
    }
  }

  Future<void> _toggleWindow({bool forceShow = false}) async {
    try {
      final isVisible = await windowManager.isVisible();
      if (forceShow || !isVisible) {
        await windowManager.show();
        await windowManager.focus();
      } else {
        await windowManager.hide();
      }
    } catch (e) {
      debugPrint('Error toggling window from tray: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    _toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key != null) {
      _handleAction(menuItem.key!);
    }
  }

  @override
  void onWindowClose() async {
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      if (themeController.minimizeToTray) {
        await windowManager.hide();
      } else {
        await windowManager.destroy();
        exit(0);
      }
    }
  }

  void dispose() {
    if (_isInitialized) {
      headphoneController.removeListener(_updateMenu);
      themeController.removeListener(_updateMenu);
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      trayManager.destroy();
      _isInitialized = false;
    }
  }
}
