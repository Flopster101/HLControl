class HeadphoneStatus {
  final bool isConnected;
  final bool isConnecting;
  final String deviceName;
  final int batteryPercent;

  // Settings values
  final String ancMode;
  final int ancIntensity;
  final String eqPreset;
  final bool gameMode;
  final bool windNoise;
  final bool multipoint;
  final bool wearDetection;
  final int autoShutdownIndex; // 0=30m, 1=1h, 2=3h, 3=5h, 4=Never
  final String spatialAudioMode; // Off, Static, Dynamic
  final String spatialScene; // Music, Sport, Movie
  final String? error;

  HeadphoneStatus({
    required this.isConnected,
    required this.isConnecting,
    required this.deviceName,
    required this.batteryPercent,
    required this.ancMode,
    required this.ancIntensity,
    required this.eqPreset,
    required this.gameMode,
    required this.windNoise,
    required this.multipoint,
    required this.wearDetection,
    required this.autoShutdownIndex,
    required this.spatialAudioMode,
    required this.spatialScene,
    this.error,
  });

  factory HeadphoneStatus.disconnected() {
    return HeadphoneStatus(
      isConnected: false,
      isConnecting: false,
      deviceName: 'Disconnected',
      batteryPercent: 0,
      ancMode: 'Normal (Off)',
      ancIntensity: 0,
      eqPreset: 'Default',
      gameMode: false,
      windNoise: false,
      multipoint: false,
      wearDetection: false,
      autoShutdownIndex: 4,
      spatialAudioMode: 'Off',
      spatialScene: 'Music',
    );
  }

  HeadphoneStatus copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? deviceName,
    int? batteryPercent,
    String? ancMode,
    int? ancIntensity,
    String? eqPreset,
    bool? gameMode,
    bool? windNoise,
    bool? multipoint,
    bool? wearDetection,
    int? autoShutdownIndex,
    String? spatialAudioMode,
    String? spatialScene,
    String? error,
  }) {
    return HeadphoneStatus(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      deviceName: deviceName ?? this.deviceName,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      ancMode: ancMode ?? this.ancMode,
      ancIntensity: ancIntensity ?? this.ancIntensity,
      eqPreset: eqPreset ?? this.eqPreset,
      gameMode: gameMode ?? this.gameMode,
      windNoise: windNoise ?? this.windNoise,
      multipoint: multipoint ?? this.multipoint,
      wearDetection: wearDetection ?? this.wearDetection,
      autoShutdownIndex: autoShutdownIndex ?? this.autoShutdownIndex,
      spatialAudioMode: spatialAudioMode ?? this.spatialAudioMode,
      spatialScene: spatialScene ?? this.spatialScene,
      error: error ?? this.error,
    );
  }
}
