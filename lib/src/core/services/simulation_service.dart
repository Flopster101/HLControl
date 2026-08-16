import 'dart:async';
import '../../ui/theme/theme_controller.dart';
import '../models/bluetooth_device.dart';
import '../models/headphone_status.dart';
import 'headphone_service.dart';

class MockModelProfile {
  final String key;
  final String displayName;
  final String defaultName;
  final String formFactor;
  final bool hasAnc;
  final bool hasAncLevels;
  final bool hasSpatialAudio;
  final bool hasLdac;
  final bool hasTwsBattery;
  final bool hasGestures;
  final bool hasWearDetection;
  final bool hasAutoShutdown;
  final bool hasAntiLeak;
  final String eqType;

  const MockModelProfile({
    required this.key,
    required this.displayName,
    required this.defaultName,
    this.formFactor = 'tws',
    this.hasAnc = true,
    this.hasAncLevels = true,
    this.hasSpatialAudio = false,
    this.hasLdac = false,
    this.hasTwsBattery = true,
    this.hasGestures = true,
    this.hasWearDetection = false,
    this.hasAutoShutdown = true,
    this.hasAntiLeak = false,
    this.eqType = 'standard',
  });

  Map<String, dynamic> toCapabilitiesMap() {
    return {
      'key': key,
      'name': defaultName,
      'form_factor': formFactor,
      'capabilities': {
        'has_anc': hasAnc,
        'has_anc_levels': hasAncLevels,
        'has_spatial_audio': hasSpatialAudio,
        'has_ldac': hasLdac,
        'has_tws_battery': hasTwsBattery,
        'has_gestures': hasGestures,
        'has_wear_detection': hasWearDetection,
        'has_auto_shutdown': hasAutoShutdown,
        'has_anti_leak': hasAntiLeak,
        'eq_type': eqType,
      },
    };
  }
}

const List<MockModelProfile> mockModelProfiles = [
  MockModelProfile(
    key: 'S40',
    displayName: 'Haylou S40 (Over-Ear Flagship)',
    defaultName: 'HAYLOU S40 (Mock)',
    formFactor: 'headband',
    hasAnc: true,
    hasAncLevels: true,
    hasSpatialAudio: true,
    hasLdac: true,
    hasTwsBattery: false,
    hasGestures: false,
    hasWearDetection: false,
    hasAutoShutdown: false,
    eqType: 's40',
  ),
  MockModelProfile(
    key: 'S35',
    displayName: 'Haylou S35 ANC (Over-Ear)',
    defaultName: 'HAYLOU S35 ANC (Mock)',
    formFactor: 'headband',
    hasAnc: true,
    hasAncLevels: true,
    hasSpatialAudio: false,
    hasLdac: false,
    hasTwsBattery: false,
    hasGestures: false,
    hasWearDetection: false,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'S30',
    displayName: 'Haylou S30 (Over-Ear)',
    defaultName: 'HAYLOU S30 (Mock)',
    formFactor: 'headband',
    hasAnc: true,
    hasAncLevels: true,
    hasSpatialAudio: false,
    hasLdac: false,
    hasTwsBattery: false,
    hasGestures: false,
    hasWearDetection: false,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'HD01',
    displayName: 'Haylou FlowLoop S33 (Over-Ear)',
    defaultName: 'HAYLOU FlowLoop S33 (Mock)',
    formFactor: 'headband',
    hasAnc: true,
    hasAncLevels: true,
    hasSpatialAudio: false,
    hasLdac: false,
    hasTwsBattery: false,
    hasGestures: false,
    hasWearDetection: false,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'X2',
    displayName: 'Haylou W1 ANC / X2 (TWS)',
    defaultName: 'HAYLOU W1 ANC (Mock)',
    formFactor: 'tws',
    hasAnc: true,
    hasAncLevels: true,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'T016',
    displayName: 'Haylou Mori Pro (TWS)',
    defaultName: 'HAYLOU Mori Pro (Mock)',
    formFactor: 'tws',
    hasAnc: true,
    hasAncLevels: true,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'T021',
    displayName: 'Haylou Flowbuds N55 (TWS Wear Detection)',
    defaultName: 'HAYLOU Flowbuds N55 (Mock)',
    formFactor: 'tws',
    hasAnc: true,
    hasAncLevels: true,
    hasTwsBattery: true,
    hasGestures: true,
    hasWearDetection: true,
    hasAutoShutdown: false,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'HT02',
    displayName: 'Haylou Flowbuds N50 (TWS)',
    defaultName: 'HAYLOU Flowbuds N50 (Mock)',
    formFactor: 'tws',
    hasAnc: true,
    hasAncLevels: true,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: false,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'HT03',
    displayName: 'Haylou Flowbuds N70 (TWS)',
    defaultName: 'HAYLOU Flowbuds N70 (Mock)',
    formFactor: 'tws',
    hasAnc: true,
    hasAncLevels: true,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: false,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'HT06',
    displayName: 'Haylou Flowbuds N10 (TWS Entry)',
    defaultName: 'HAYLOU Flowbuds N10 (Mock)',
    formFactor: 'tws',
    hasAnc: true,
    hasAncLevels: false,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: false,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'X1',
    displayName: 'Haylou X1 2023 (TWS Non-ANC)',
    defaultName: 'HAYLOU X1 2023 (Mock)',
    formFactor: 'tws',
    hasAnc: false,
    hasAncLevels: false,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'T013',
    displayName: 'Haylou X1 Plus (TWS)',
    defaultName: 'HAYLOU X1 Plus (Mock)',
    formFactor: 'tws',
    hasAnc: false,
    hasAncLevels: false,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'X1L',
    displayName: 'Haylou X1 ACE (TWS Gaming)',
    defaultName: 'HAYLOU X1 ACE (Mock)',
    formFactor: 'tws',
    hasAnc: false,
    hasAncLevels: false,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'BC04',
    displayName: 'Haylou Purfree Lite (Bone Conduction)',
    defaultName: 'HAYLOU Purfree Lite (Mock)',
    formFactor: 'open_ear',
    hasAnc: false,
    hasAncLevels: false,
    hasTwsBattery: false,
    hasGestures: false,
    hasAutoShutdown: true,
    hasAntiLeak: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'OW02',
    displayName: 'Haylou Earhook 1 (Open-Ear)',
    defaultName: 'HAYLOU Earhook 1 (Mock)',
    formFactor: 'open_ear',
    hasAnc: false,
    hasAncLevels: false,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
  MockModelProfile(
    key: 'OW03',
    displayName: 'Haylou Airfree (Open-Ear)',
    defaultName: 'HAYLOU Airfree (Mock)',
    formFactor: 'open_ear',
    hasAnc: false,
    hasAncLevels: false,
    hasTwsBattery: true,
    hasGestures: true,
    hasAutoShutdown: true,
    eqType: 'standard',
  ),
];

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
      deviceName: _deviceName.isNotEmpty ? _deviceName : profile.defaultName,
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
