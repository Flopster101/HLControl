import 'dart:async';
import '../../ui/theme/theme_controller.dart';
import '../models/bluetooth_device.dart';
import '../models/device_model.dart';
import '../models/headphone_status.dart';
import 'headphone_service.dart';

typedef MockModelProfile = DeviceModel;
const List<DeviceModel> mockModelProfiles = DeviceModel.knownModels;

class SimulationHeadphoneService implements HeadphoneService {
  SimulationHeadphoneService(this._themeController) {
    _status = _buildStatusFromTheme();
    _controller = StreamController<HeadphoneStatus>.broadcast(onListen: () {
      _controller.add(_status);
    });

    _themeController.addListener(_onThemeChanged);
  }

  final ThemeController _themeController;
  late HeadphoneStatus _status;
  late StreamController<HeadphoneStatus> _controller;

  String _deviceName = '';
  String _ancMode = 'ANC On';
  int _ancIntensity = 0;
  String _eqPreset = 'Default';
  bool _gameMode = false;
  bool _windNoise = false;
  bool _multipoint = false;
  bool _ldac = true;
  bool _wearDetection = true;
  bool _antiLeak = false;
  int _autoShutdownIndex = 4;
  String _spatialAudioMode = 'Off';
  String _spatialScene = 'Music';

  final Map<String, dynamic> _gestures = {
    '1': {
      'type_id': 1,
      'type_name': 'Double Tap',
      'left_func': 1,
      'left_name': 'Play / Pause',
      'right_func': 3,
      'right_name': 'Next Track',
    },
    '2': {
      'type_id': 2,
      'type_name': 'Triple Tap',
      'left_func': 0,
      'left_name': 'Voice Assistant',
      'right_func': 7,
      'right_name': 'Game Mode',
    },
    '3': {
      'type_id': 3,
      'type_name': 'Long Press',
      'left_func': 6,
      'left_name': 'ANC Toggle',
      'right_func': 6,
      'right_name': 'ANC Toggle',
    },
  };

  @override
  Stream<HeadphoneStatus> get statusStream => _controller.stream;

  @override
  HeadphoneStatus get currentStatus => _status;

  void _onThemeChanged() {
    final newStatus = _buildStatusFromTheme();
    _updateStatus(newStatus);
  }

  HeadphoneStatus _buildStatusFromTheme() {
    final profile = mockModelProfiles.firstWhere(
      (p) => p.key == _themeController.mockDeviceKey,
      orElse: () => mockModelProfiles.first,
    );

    final isTws = profile.hasTwsBattery;
    final pct = _themeController.mockBatteryPercent;

    return HeadphoneStatus(
      isConnected: _themeController.isMockConnected,
      isConnecting: false,
      deviceName: _deviceName.isNotEmpty ? _deviceName : profile.name,
      batteryPercent: pct,
      batteryLeft: isTws ? pct : null,
      batteryRight: isTws ? (pct > 5 ? pct - 3 : pct) : null,
      batteryCase: isTws ? (pct > 10 ? pct + 5 : pct) : null,
      ancMode: profile.hasAnc ? _ancMode : 'Normal (Off)',
      ancIntensity: _ancIntensity,
      eqPreset: _eqPreset,
      gameMode: _gameMode,
      windNoise: _windNoise,
      multipoint: _multipoint,
      ldac: profile.hasLdac ? _ldac : false,
      wearDetection: profile.hasWearDetection ? _wearDetection : false,
      antiLeak: profile.hasAntiLeak ? _antiLeak : false,
      autoShutdownIndex: profile.hasAutoShutdown ? _autoShutdownIndex : 4,
      spatialAudioMode: profile.hasSpatialAudio ? _spatialAudioMode : 'Off',
      spatialScene: profile.hasSpatialAudio ? _spatialScene : 'Music',
      modelInfo: profile.toCapabilitiesMap(),
      gestures: profile.hasGestures ? _gestures : null,
    );
  }

  void _updateStatus(HeadphoneStatus newStatus) {
    _status = newStatus;
    if (!_controller.isClosed) {
      _controller.add(_status);
    }
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
    return mockModelProfiles.map((p) {
      return BluetoothDevice(
        macAddress: 'AA:BB:CC:DD:${p.key.hashCode.abs().toRadixString(16).padLeft(4, '0').toUpperCase().substring(0, 2)}:00',
        name: p.displayName,
      );
    }).toList();
  }

  @override
  Future<List<BluetoothDevice>> scanDevices() async {
    await Future.delayed(const Duration(milliseconds: 800));
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
    _ancMode = ancStr;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setAncLevel(int level) async {
    _ancIntensity = level;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setGameMode(bool enabled) async {
    _gameMode = enabled;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setWindNoise(bool enabled) async {
    _windNoise = enabled;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setMultipoint(bool enabled) async {
    _multipoint = enabled;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setLdac(bool enabled) async {
    _ldac = enabled;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setWearDetection(bool enabled) async {
    _wearDetection = enabled;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setAntiLeak(bool enabled) async {
    _antiLeak = enabled;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setAutoShutdown(int timerVal) async {
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
    _autoShutdownIndex = idx;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setSpatialAudio(String mode) async {
    _spatialAudioMode = mode;
    _updateStatus(_buildStatusFromTheme());
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
    _spatialScene = scene;
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setEqPreset(int presetIdx) async {
    if (presetIdx == 15 || presetIdx == 240) {
      _eqPreset = 'Custom/Customize';
      _updateStatus(_buildStatusFromTheme());
      return;
    }
    final List<String> presets = ['Default', 'Vocal', 'Rock', 'Classical', 'Popularity', 'Bass', 'Subwoofer', 'Soft', 'Outdoor'];
    _eqPreset = (presetIdx >= 0 && presetIdx < presets.length) ? presets[presetIdx] : 'Default';
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setCustomEq(List<double> gains) async {
    _eqPreset = 'Custom/Customize';
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> setGesture(int gestureType, int leftFunc, int rightFunc) async {
    final typeKey = gestureType.toString();
    _gestures[typeKey] = {
      'type_id': gestureType,
      'type_name': gestureType == 1 ? 'Double Tap' : (gestureType == 2 ? 'Triple Tap' : 'Long Press'),
      'left_func': leftFunc,
      'left_name': 'Func $leftFunc',
      'right_func': rightFunc,
      'right_name': 'Func $rightFunc',
    };
    _updateStatus(_buildStatusFromTheme());
  }

  @override
  Future<void> renameDevice(String newName) async {
    _deviceName = newName;
    _updateStatus(_buildStatusFromTheme());
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
