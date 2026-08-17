class DeviceModel {
  final String key;
  final int pid;
  final String name;
  final String displayName;
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

  const DeviceModel({
    required this.key,
    required this.pid,
    required this.name,
    required this.displayName,
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

  Map<String, dynamic> get capabilities => {
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
  };

  Map<String, dynamic> toCapabilitiesMap() {
    return {
      'key': key,
      'pid': pid,
      'name': name,
      'form_factor': formFactor,
      'capabilities': capabilities,
    };
  }

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    final caps = map['capabilities'] as Map<String, dynamic>? ?? const {};
    return DeviceModel(
      key: map['key'] as String? ?? 'GENERIC',
      pid: (map['pid'] as num?)?.toInt() ?? 0,
      name: map['name'] as String? ?? 'Haylou Device',
      displayName: map['name'] as String? ?? 'Haylou Device',
      formFactor: map['form_factor'] as String? ?? 'tws',
      hasAnc: caps['has_anc'] as bool? ?? true,
      hasAncLevels: caps['has_anc_levels'] as bool? ?? true,
      hasSpatialAudio: caps['has_spatial_audio'] as bool? ?? false,
      hasLdac: caps['has_ldac'] as bool? ?? false,
      hasTwsBattery: caps['has_tws_battery'] as bool? ?? true,
      hasGestures: caps['has_gestures'] as bool? ?? true,
      hasWearDetection: caps['has_wear_detection'] as bool? ?? false,
      hasAutoShutdown: caps['has_auto_shutdown'] as bool? ?? true,
      hasAntiLeak: caps['has_anti_leak'] as bool? ?? false,
      eqType: caps['eq_type'] as String? ?? 'standard',
    );
  }

  static const List<DeviceModel> knownModels = [
    DeviceModel(
      key: 'S40',
      pid: 34,
      name: 'Haylou S40',
      displayName: 'Haylou S40 (Over-Ear Flagship)',
      formFactor: 'headband',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: true,
      hasLdac: true,
      hasTwsBattery: false,
      hasGestures: false,
      hasWearDetection: false,
      hasAutoShutdown: false,
      hasAntiLeak: false,
      eqType: 's40',
    ),
    DeviceModel(
      key: 'S35',
      pid: 16,
      name: 'Haylou S35 ANC',
      displayName: 'Haylou S35 ANC (Over-Ear)',
      formFactor: 'headband',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: false,
      hasGestures: false,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'S30',
      pid: 20,
      name: 'Haylou S30',
      displayName: 'Haylou S30 (Over-Ear)',
      formFactor: 'headband',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: false,
      hasGestures: false,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'HD01',
      pid: 39,
      name: 'Haylou FlowLoop S33',
      displayName: 'Haylou FlowLoop S33 / HD01 (Over-Ear)',
      formFactor: 'headband',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: false,
      hasGestures: false,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'X2',
      pid: 18,
      name: 'Haylou W1 ANC',
      displayName: 'Haylou W1 ANC / X2 (TWS)',
      formFactor: 'tws',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'T016',
      pid: 22,
      name: 'Haylou Mori Pro',
      displayName: 'Haylou Mori Pro (TWS)',
      formFactor: 'tws',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'T016P',
      pid: 36,
      name: 'Haylou Mori Plus',
      displayName: 'Haylou Mori Plus (TWS)',
      formFactor: 'tws',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'T021',
      pid: 37,
      name: 'Haylou Flowbuds N55',
      displayName: 'Haylou Flowbuds N55 (TWS Wear Detection)',
      formFactor: 'tws',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: true,
      hasAutoShutdown: false,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'HT02',
      pid: 38,
      name: 'Haylou Flowbuds N50',
      displayName: 'Haylou Flowbuds N50 (TWS)',
      formFactor: 'tws',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: false,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'HT03',
      pid: 41,
      name: 'Haylou Flowbuds N70',
      displayName: 'Haylou Flowbuds N70 (TWS)',
      formFactor: 'tws',
      hasAnc: true,
      hasAncLevels: true,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: false,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'HT06',
      pid: 40,
      name: 'Haylou Flowbuds N10',
      displayName: 'Haylou Flowbuds N10 (TWS Entry)',
      formFactor: 'tws',
      hasAnc: true,
      hasAncLevels: false,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: false,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'X1',
      pid: 17,
      name: 'Haylou X1 2023',
      displayName: 'Haylou X1 2023 (TWS Non-ANC)',
      formFactor: 'tws',
      hasAnc: false,
      hasAncLevels: false,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'T013',
      pid: 21,
      name: 'Haylou X1 Plus',
      displayName: 'Haylou X1 Plus (TWS)',
      formFactor: 'tws',
      hasAnc: false,
      hasAncLevels: false,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'X1L',
      pid: 33,
      name: 'Haylou X1 ACE',
      displayName: 'Haylou X1 ACE (TWS Gaming)',
      formFactor: 'tws',
      hasAnc: false,
      hasAncLevels: false,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'BC04',
      pid: 19,
      name: 'Haylou Purfree Lite',
      displayName: 'Haylou Purfree Lite / BC04 (Bone Conduction)',
      formFactor: 'open_ear',
      hasAnc: false,
      hasAncLevels: false,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: false,
      hasGestures: false,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: true,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'OW02',
      pid: 32,
      name: 'Haylou Earhook 1',
      displayName: 'Haylou Earhook 1 (Open-Ear)',
      formFactor: 'open_ear',
      hasAnc: false,
      hasAncLevels: false,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
    DeviceModel(
      key: 'OW03',
      pid: 25,
      name: 'Haylou Airfree',
      displayName: 'Haylou Airfree (Open-Ear)',
      formFactor: 'open_ear',
      hasAnc: false,
      hasAncLevels: false,
      hasSpatialAudio: false,
      hasLdac: false,
      hasTwsBattery: true,
      hasGestures: true,
      hasWearDetection: false,
      hasAutoShutdown: true,
      hasAntiLeak: false,
      eqType: 'standard',
    ),
  ];

  static DeviceModel identify(String? name, {int? pid}) {
    if (pid != null && pid > 0) {
      for (final m in knownModels) {
        if (m.pid == pid) return m;
      }
    }

    final lower = (name ?? '').toLowerCase();
    if (lower.contains('s40')) return knownModels.firstWhere((m) => m.key == 'S40');
    if (lower.contains('s35')) return knownModels.firstWhere((m) => m.key == 'S35');
    if (lower.contains('s30')) return knownModels.firstWhere((m) => m.key == 'S30');
    if (lower.contains('s33') || lower.contains('flowloop') || lower.contains('hd01')) return knownModels.firstWhere((m) => m.key == 'HD01');
    if (lower.contains('w1') || lower.contains('t007')) return knownModels.firstWhere((m) => m.key == 'X2');
    if (lower.contains('mori plus') || lower.contains('t016p')) return knownModels.firstWhere((m) => m.key == 'T016P');
    if (lower.contains('mori') || lower.contains('t016')) return knownModels.firstWhere((m) => m.key == 'T016');
    if (lower.contains('n55') || lower.contains('t021')) return knownModels.firstWhere((m) => m.key == 'T021');
    if (lower.contains('n50') || lower.contains('ht02')) return knownModels.firstWhere((m) => m.key == 'HT02');
    if (lower.contains('n70') || lower.contains('ht03')) return knownModels.firstWhere((m) => m.key == 'HT03');
    if (lower.contains('n10') || lower.contains('ht06')) return knownModels.firstWhere((m) => m.key == 'HT06');
    if (lower.contains('x1 ace') || lower.contains('x1l')) return knownModels.firstWhere((m) => m.key == 'X1L');
    if (lower.contains('x1 plus') || lower.contains('t013')) return knownModels.firstWhere((m) => m.key == 'T013');
    if (lower.contains('x1') || lower.contains('t003')) return knownModels.firstWhere((m) => m.key == 'X1');
    if (lower.contains('purfree') || lower.contains('bc04')) return knownModels.firstWhere((m) => m.key == 'BC04');
    if (lower.contains('earhook') || lower.contains('ow02')) return knownModels.firstWhere((m) => m.key == 'OW02');
    if (lower.contains('airfree') || lower.contains('ow03')) return knownModels.firstWhere((m) => m.key == 'OW03');

    // Default: Fallback to S40 flagship model
    return knownModels.firstWhere((m) => m.key == 'S40');
  }
}
