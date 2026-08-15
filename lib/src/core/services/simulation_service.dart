import 'dart:async';
import '../../ui/theme/theme_controller.dart';
import '../models/bluetooth_device.dart';
import '../models/headphone_status.dart';
import 'headphone_service.dart';

class SimulationHeadphoneService implements HeadphoneService {
  SimulationHeadphoneService(this._themeController) {
    _status = HeadphoneStatus(
      isConnected: _themeController.isMockConnected,
      isConnecting: false,
      deviceName: 'HAYLOU S40 (Mock)',
      batteryPercent: _themeController.mockBatteryPercent,
      ancMode: 'ANC On',
      ancIntensity: 0,
      eqPreset: 'Default',
      gameMode: false,
      windNoise: false,
      multipoint: false,
      wearDetection: true,
      autoShutdownIndex: 4,
      spatialAudioMode: 'Off',
      spatialScene: 'Music',
    );
    _controller = StreamController<HeadphoneStatus>.broadcast(onListen: () {
      _controller.add(_status);
    });

    // Listen to changes in theme controller (e.g. if battery percentage is updated in settings)
    _themeController.addListener(_onThemeChanged);
  }

  final ThemeController _themeController;
  late HeadphoneStatus _status;
  late StreamController<HeadphoneStatus> _controller;

  @override
  Stream<HeadphoneStatus> get statusStream => _controller.stream;

  @override
  HeadphoneStatus get currentStatus => _status;

  void _onThemeChanged() {
    final newStatus = _buildStatusFromTheme();
    if (newStatus.isConnected != _status.isConnected ||
        newStatus.batteryPercent != _status.batteryPercent) {
      _status = newStatus;
      _controller.add(_status);
    }
  }

  HeadphoneStatus _buildStatusFromTheme() {
    return HeadphoneStatus(
      isConnected: _themeController.isMockConnected,
      isConnecting: false,
      deviceName: _status.deviceName,
      batteryPercent: _themeController.mockBatteryPercent,
      ancMode: _status.ancMode,
      ancIntensity: _status.ancIntensity,
      eqPreset: _status.eqPreset,
      gameMode: _status.gameMode,
      windNoise: _status.windNoise,
      multipoint: _status.multipoint,
      wearDetection: _status.wearDetection,
      autoShutdownIndex: _status.autoShutdownIndex,
      spatialAudioMode: _status.spatialAudioMode,
      spatialScene: _status.spatialScene,
    );
  }

  // Helper to update and notify
  void _updateStatus(HeadphoneStatus newStatus) {
    _status = newStatus;
    _controller.add(_status);
  }

  @override
  Future<void> connect(String macAddress) async {
    _themeController.setMockConnected(true);
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> disconnect() async {
    _themeController.setMockConnected(false);
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<List<BluetoothDevice>> getPairedDevices() async {
    return [
      BluetoothDevice(macAddress: '11:22:33:44:55:66', name: 'HAYLOU S40 (Mock)'),
      BluetoothDevice(macAddress: 'AA:BB:CC:DD:EE:11', name: 'HAYLOU S35 (Mock)'),
      BluetoothDevice(macAddress: 'AA:BB:CC:DD:EE:22', name: 'HAYLOU X1 (Mock)'),
      BluetoothDevice(macAddress: 'AA:BB:CC:DD:EE:33', name: 'Sony WH-1000XM4 (Mock)'),
      BluetoothDevice(macAddress: 'AA:BB:CC:DD:EE:44', name: 'JBL Tune 510BT (Mock)'),
      BluetoothDevice(macAddress: 'AA:BB:CC:DD:EE:55', name: 'HAYLOU Purfree Lite (Mock)'),
    ];
  }

  @override
  Future<List<BluetoothDevice>> scanDevices() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    return getPairedDevices();
  }

  @override
  Future<void> setAncMode(int mode) async {
    String ancStr;
    switch (mode) {
      case 0:
        ancStr = 'Normal (Off)';
        break;
      case 1:
        ancStr = 'ANC On';
        break;
      case 2:
        ancStr = 'Transparency';
        break;
      case 3:
        ancStr = 'Wind Noise (KANG_FENG)';
        break;
      case 4:
        ancStr = 'Adaptive Auto-ANC';
        break;
      default:
        ancStr = 'Normal (Off)';
    }
    _updateStatus(_status.copyWith(ancMode: ancStr));
  }

  @override
  Future<void> setAncLevel(int level) async {
    _updateStatus(_status.copyWith(ancIntensity: level));
  }

  @override
  Future<void> setGameMode(bool enabled) async {
    _updateStatus(_status.copyWith(gameMode: enabled));
  }

  @override
  Future<void> setWindNoise(bool enabled) async {
    _updateStatus(_status.copyWith(windNoise: enabled));
  }

  @override
  Future<void> setMultipoint(bool enabled) async {
    _updateStatus(_status.copyWith(multipoint: enabled));
  }

  @override
  Future<void> setLdac(bool enabled) async {
    _updateStatus(_status.copyWith(ldac: enabled));
  }

  @override
  Future<void> setWearDetection(bool enabled) async {
    _updateStatus(_status.copyWith(wearDetection: enabled));
  }

  @override
  Future<void> setAutoShutdown(int timerVal) async {
    // Map Liesheng timer values (1=30m, 2=1h, 6=3h, 10=5h, 255=Never) back to indices (0-4)
    int idx;
    if (timerVal == 1) {
      idx = 0;
    } else if (timerVal == 2) {
      idx = 1;
    } else if (timerVal == 6) {
      idx = 2;
    } else if (timerVal == 10) {
      idx = 3;
    } else {
      idx = 4;
    }
    _updateStatus(_status.copyWith(autoShutdownIndex: idx));
  }

  @override
  Future<void> setSpatialAudio(String mode) async {
    _updateStatus(_status.copyWith(spatialAudioMode: mode));
  }

  @override
  Future<void> setSpatialScene(int sceneIdx) async {
    String scene;
    switch (sceneIdx) {
      case 0: scene = 'Music'; break;
      case 1: scene = 'Sport'; break;
      case 2: scene = 'Movie'; break;
      default: scene = 'Music';
    }
    _updateStatus(_status.copyWith(spatialScene: scene));
  }

  @override
  Future<void> setEqPreset(int presetIdx) async {
    if (presetIdx == 15 || presetIdx == 240) {
      _updateStatus(_status.copyWith(eqPreset: 'Custom/Customize'));
      return;
    }
    final List<String> presets = ['Default', 'Subwoofer', 'Rock', 'Soft', 'Classical'];
    final presetName = (presetIdx >= 0 && presetIdx < presets.length) ? presets[presetIdx] : 'Default';
    _updateStatus(_status.copyWith(eqPreset: presetName));
  }

  @override
  Future<void> renameDevice(String newName) async {
    _updateStatus(_status.copyWith(deviceName: newName));
  }

  @override
  Future<void> findDevice(bool play) async {}

  @override
  Future<void> refreshStatus() async {}

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    _controller.close();
  }
}
