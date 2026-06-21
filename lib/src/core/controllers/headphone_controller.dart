import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../ui/theme/theme_controller.dart';
import '../models/bluetooth_device.dart';
import '../models/headphone_status.dart';
import '../services/headphone_service.dart';
import '../services/linux_service.dart';
import '../services/simulation_service.dart';

class HeadphoneController extends ChangeNotifier {
  HeadphoneController(this.themeController) {
    _initService();
    themeController.addListener(_onThemeSettingsChanged);
  }

  final ThemeController themeController;
  late HeadphoneService _service;
  StreamSubscription<HeadphoneStatus>? _statusSub;
  HeadphoneStatus _status = HeadphoneStatus.disconnected();

  HeadphoneStatus get status => _status;
  bool get isConnected => _status.isConnected;
  bool get isConnecting => _status.isConnecting;
  String get deviceName => _status.deviceName;
  int get batteryPercent => _status.batteryPercent;

  void _initService() {
    _statusSub?.cancel();

    if (themeController.isMockConnected) {
      _service = SimulationHeadphoneService(themeController);
    } else {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Fallback to Simulation for now on Android until AndroidService is built
        _service = SimulationHeadphoneService(themeController);
      } else {
        _service = LinuxHeadphoneService();
      }
    }

    _status = _service.currentStatus;
    _statusSub = _service.statusStream.listen((newStatus) {
      _status = newStatus;
      notifyListeners();
    });
  }

  void _onThemeSettingsChanged() {
    final shouldBeMock = themeController.isMockConnected;
    // Check if we need to switch services
    final isMockActive = _service is SimulationHeadphoneService;
    if (shouldBeMock != isMockActive) {
      // Clean up old service
      if (_service is LinuxHeadphoneService) {
        (_service as LinuxHeadphoneService).dispose();
      } else if (_service is SimulationHeadphoneService) {
        (_service as SimulationHeadphoneService).dispose();
      }

      _initService();
      notifyListeners();
    }
  }

  Future<void> connect(String macAddress) async {
    await _service.connect(macAddress);
  }

  Future<void> disconnect() async {
    await _service.disconnect();
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await _service.getPairedDevices();
  }

  Future<void> setAncMode(int mode) async {
    await _service.setAncMode(mode);
  }

  Future<void> setGameMode(bool enabled) async {
    await _service.setGameMode(enabled);
  }

  Future<void> setWindNoise(bool enabled) async {
    await _service.setWindNoise(enabled);
  }

  Future<void> setMultipoint(bool enabled) async {
    await _service.setMultipoint(enabled);
  }

  Future<void> setWearDetection(bool enabled) async {
    await _service.setWearDetection(enabled);
  }

  Future<void> setAutoShutdown(int choiceIndex) async {
    // Map choiceIndex (0=30m, 1=1h, 2=3h, 3=5h, 4=Never) to Liesheng protocol byte values:
    // 0 -> 1 (30 mins)
    // 1 -> 2 (1 hour)
    // 2 -> 6 (3 hours)
    // 3 -> 10 (5 hours)
    // 4 -> 255 (Never)
    int byteVal;
    switch (choiceIndex) {
      case 0: byteVal = 1; break;
      case 1: byteVal = 2; break;
      case 2: byteVal = 6; break;
      case 3: byteVal = 10; break;
      case 4: byteVal = 255; break;
      default: byteVal = 255;
    }
    await _service.setAutoShutdown(byteVal);
  }

  Future<void> setSpatialAudio(bool enabled) async {
    await _service.setSpatialAudio(enabled);
  }

  Future<void> setSpatialScene(int sceneIdx) async {
    await _service.setSpatialScene(sceneIdx);
  }

  Future<void> setEqPreset(int presetIdx) async {
    await _service.setEqPreset(presetIdx);
  }

  Future<void> renameDevice(String newName) async {
    await _service.renameDevice(newName);
  }

  Future<void> refreshStatus() async {
    await _service.refreshStatus();
  }

  @override
  void dispose() {
    themeController.removeListener(_onThemeSettingsChanged);
    _statusSub?.cancel();
    if (_service is LinuxHeadphoneService) {
      (_service as LinuxHeadphoneService).dispose();
    } else if (_service is SimulationHeadphoneService) {
      (_service as SimulationHeadphoneService).dispose();
    }
    super.dispose();
  }
}
