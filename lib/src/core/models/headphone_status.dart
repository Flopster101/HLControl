import 'device_model.dart';

class HeadphoneStatus {
  final bool isConnected;
  final bool isConnecting;
  final String deviceName;
  final int batteryPercent;
  final int? batteryLeft;
  final int? batteryRight;
  final int? batteryCase;

  // Settings values
  final String ancMode;
  final int ancIntensity;
  final String eqPreset;
  final bool? gameMode;
  final bool? windNoise;
  final bool? multipoint;
  final bool? ldac;
  final bool? wearDetection;
  final bool? antiLeak;
  final int? autoShutdownIndex; // 0=30m, 1=1h, 2=3h, 3=5h, 4=Never
  final String spatialAudioMode; // Off, Static, Dynamic
  final String spatialScene; // Music, Sport, Movie
  final Map<String, dynamic>? modelInfo;
  final Map<String, dynamic>? gestures;
  final String? error;

  HeadphoneStatus({
    required this.isConnected,
    required this.isConnecting,
    required this.deviceName,
    required this.batteryPercent,
    this.batteryLeft,
    this.batteryRight,
    this.batteryCase,
    required this.ancMode,
    required this.ancIntensity,
    required this.eqPreset,
    this.gameMode,
    this.windNoise,
    this.multipoint,
    this.ldac,
    this.wearDetection,
    this.antiLeak,
    this.autoShutdownIndex,
    required this.spatialAudioMode,
    required this.spatialScene,
    this.modelInfo,
    this.gestures,
    this.error,
  });

  bool get isTws => batteryLeft != null && batteryRight != null;

  DeviceModel get deviceModel => modelInfo != null
      ? DeviceModel.fromMap(modelInfo!)
      : DeviceModel.identify(deviceName);

  Map<String, dynamic> get modelCapabilities => deviceModel.capabilities;
  bool get hasAnc => deviceModel.hasAnc;
  bool get hasAncLevels => deviceModel.hasAncLevels;
  bool get hasSpatialAudio => deviceModel.hasSpatialAudio;
  bool get hasLdac => deviceModel.hasLdac;
  bool get hasGestures => deviceModel.hasGestures;
  bool get hasWearDetection => deviceModel.hasWearDetection;
  bool get hasAutoShutdown => deviceModel.hasAutoShutdown;
  bool get hasAntiLeak => deviceModel.hasAntiLeak;
  String get eqType => deviceModel.eqType;

  factory HeadphoneStatus.disconnected() {
    return HeadphoneStatus(
      isConnected: false,
      isConnecting: false,
      deviceName: 'Disconnected',
      batteryPercent: 0,
      batteryLeft: null,
      batteryRight: null,
      batteryCase: null,
      ancMode: 'Normal (Off)',
      ancIntensity: 0,
      eqPreset: 'Default',
      gameMode: false,
      windNoise: false,
      multipoint: false,
      ldac: false,
      wearDetection: false,
      antiLeak: false,
      autoShutdownIndex: 4,
      spatialAudioMode: 'Off',
      spatialScene: 'Music',
      modelInfo: null,
      gestures: null,
    );
  }

  HeadphoneStatus copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? deviceName,
    int? batteryPercent,
    int? batteryLeft,
    int? batteryRight,
    int? batteryCase,
    String? ancMode,
    int? ancIntensity,
    String? eqPreset,
    bool? gameMode,
    bool? windNoise,
    bool? multipoint,
    bool? ldac,
    bool? wearDetection,
    bool? antiLeak,
    int? autoShutdownIndex,
    String? spatialAudioMode,
    String? spatialScene,
    Map<String, dynamic>? modelInfo,
    Map<String, dynamic>? gestures,
    String? error,
  }) {
    return HeadphoneStatus(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      deviceName: deviceName ?? this.deviceName,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryLeft: batteryLeft ?? this.batteryLeft,
      batteryRight: batteryRight ?? this.batteryRight,
      batteryCase: batteryCase ?? this.batteryCase,
      ancMode: ancMode ?? this.ancMode,
      ancIntensity: ancIntensity ?? this.ancIntensity,
      eqPreset: eqPreset ?? this.eqPreset,
      gameMode: gameMode ?? this.gameMode,
      windNoise: windNoise ?? this.windNoise,
      multipoint: multipoint ?? this.multipoint,
      ldac: ldac ?? this.ldac,
      wearDetection: wearDetection ?? this.wearDetection,
      antiLeak: antiLeak ?? this.antiLeak,
      autoShutdownIndex: autoShutdownIndex ?? this.autoShutdownIndex,
      spatialAudioMode: spatialAudioMode ?? this.spatialAudioMode,
      spatialScene: spatialScene ?? this.spatialScene,
      modelInfo: modelInfo ?? this.modelInfo,
      gestures: gestures ?? this.gestures,
      error: error ?? this.error,
    );
  }
}
