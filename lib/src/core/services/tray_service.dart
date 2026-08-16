import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/headphone_controller.dart';
import '../../ui/theme/theme_controller.dart';

class TrayService with TrayListener {
  TrayService({
    required this.headphoneController,
    required this.themeController,
  });

  final HeadphoneController headphoneController;
  final ThemeController themeController;
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
      trayManager.addListener(this);

      const iconPath = 'assets/images/tray_headphones.png';
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
    } catch (e) {
      debugPrint('Failed to initialize TrayService: $e');
    }
  }

  Future<void> _updateMenu() async {
    if (!_isInitialized) return;

    final status = headphoneController.status;
    final isConnected = status.isConnected;

    final anc = status.ancMode.toLowerCase();
    final isOff = anc.contains('normal') || anc.contains('off') || anc == '0';
    final isAnc = (anc.contains('anc') && !anc.contains('adaptive')) || anc == '1';
    final isAware = anc.contains('transparen') || anc.contains('aware') || anc == '2';
    final isAdaptive = anc.contains('adaptive') || anc == '4';

    final spatial = status.spatialAudioMode.toLowerCase();
    final isSpatialOff = spatial == 'off';
    final isSpatialStatic = spatial == 'static';
    final isSpatialDynamic = spatial == 'dynamic';

    final deviceLabel = isConnected
        ? (status.deviceName.isNotEmpty ? status.deviceName : 'Headphones')
        : (themeController.lastConnectedName.isNotEmpty ? themeController.lastConnectedName : 'Headphones');

    final menu = Menu(
      items: [
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
        if (isConnected)
          MenuItem(
            key: 'disconnect',
            label: 'Disconnect ($deviceLabel)',
          )
        else
          MenuItem(
            key: 'connect',
            label: 'Connect ($deviceLabel)',
          ),
        MenuItem.separator(),

        // 5. App Controls
        MenuItem(
          key: 'open_app',
          label: 'Open HLControl',
        ),
        MenuItem(
          key: 'quit',
          label: 'Quit',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  void _handleAction(String key) {
    final now = DateTime.now();
    // Debounce rapid duplicate invocations
    if (_lastActionKey == key && now.difference(_lastActionTime).inMilliseconds < 350) {
      return;
    }
    _lastActionTime = now;
    _lastActionKey = key;

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

  void dispose() {
    if (_isInitialized) {
      headphoneController.removeListener(_updateMenu);
      themeController.removeListener(_updateMenu);
      trayManager.removeListener(this);
      trayManager.destroy();
      _isInitialized = false;
    }
  }
}
