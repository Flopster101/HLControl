import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/bluetooth_device.dart';
import '../models/headphone_status.dart';
import 'headphone_service.dart';

class AndroidHeadphoneService implements HeadphoneService {
  static const MethodChannel _methodChannel = MethodChannel('com.flopster101.hlcontrol/bluetooth');
  static const EventChannel _eventChannel = EventChannel('com.flopster101.hlcontrol/bluetooth_events');

  // Protocol Constants
  static const int opWrite = 0x80;
  static const int opRead = 0xC0;
  static const int opResponse = 0x00;
  static const int opNotify = 0x02;

  static const int cmdGetDeviceInfo = 2;
  static const int cmdSetDeviceInfo = 8;
  static const int cmdGetDeviceRunInfo = 9;
  static const int cmdReportDeviceStatus = 14;
  static const int cmdSendDeviceFile = 18;

  static const int ordDevName = 0;
  static const int ordDevBattery = 2;

  static const int ordRunAutoShutdown = 5;
  static const int ordRunAncStatus = 9;
  static const int ordRunGameMode = 11;
  static const int ordRunEqMode = 12;
  static const int ordRunAntiLeak = 15;
  static const int ordRunLdac = 16;
  static const int ordRunMultipoint = 17;
  static const int ordRunSpatialAudio = 18;
  static const int ordRunSpatialScene = 19;
  static const int ordRunWindNoise = 20;
  static const int ordRunWearDetection = 21;
  static const int ordRunWearState = 22;

  static const Map<int, String> ancModes = {
    0: "Normal (Off)",
    1: "ANC On",
    2: "Transparency",
    3: "Wind Noise (KANG_FENG)",
    4: "Adaptive Auto-ANC"
  };

  static const Map<int, String> eqPresets = {
    0: "Default",
    1: "Vocal",
    2: "Rock",
    3: "Classical",
    4: "Popularity",
    5: "Bass",
    6: "Subwoofer",
    7: "Soft",
    8: "Custom/Customize",
    15: "Custom/Customize",
    240: "Custom/Customize"
  };

  AndroidHeadphoneService() {
    _status = HeadphoneStatus.disconnected();
    _controller = StreamController<HeadphoneStatus>.broadcast(onListen: () {
      _controller.add(_status);
    });

    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final ev = event['event'] as String?;
        final val = event['value'];

        if (ev == 'status') {
          if (val == 'connecting') {
            _updateStatus(_status.copyWith(isConnecting: true, isConnected: false));
          } else if (val == 'connected') {
            _updateStatus(_status.copyWith(isConnecting: false, isConnected: true));
            // Trigger status query once connected
            _queryStatus();
          } else if (val == 'disconnected' || val == 'failed') {
            _updateStatus(HeadphoneStatus.disconnected());
          }
        } else if (ev == 'data') {
          final bytesList = List<int>.from(val as List);
          _handleIncomingBytes(bytesList);
        }
      }
    });
  }

  late HeadphoneStatus _status;
  late StreamController<HeadphoneStatus> _controller;
  final List<int> _rxBuffer = [];
  int _sequenceSn = 0;

  @override
  Stream<HeadphoneStatus> get statusStream => _controller.stream;

  @override
  HeadphoneStatus get currentStatus => _status;

  void _updateStatus(HeadphoneStatus newStatus) {
    _status = newStatus;
    if (!_controller.isClosed) {
      _controller.add(_status);
    }
  }

  @override
  Future<void> connect(String macAddress) async {
    _updateStatus(_status.copyWith(isConnecting: true, isConnected: false));
    try {
      await _methodChannel.invokeMethod('connect', {'mac': macAddress});
    } catch (e) {
      _updateStatus(HeadphoneStatus.disconnected().copyWith(error: e.toString()));
    }
  }

  @override
  Future<void> disconnect() async {
    _updateStatus(_status.copyWith(isConnecting: false, isConnected: false));
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (_) {}
  }

  @override
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>('checkPermissions') ?? false;
      if (!granted) {
        await _methodChannel.invokeMethod<bool>('requestPermissions');
      }

      final List<dynamic>? list = await _methodChannel.invokeMethod<List<dynamic>>('getPairedDevices');
      if (list == null) return [];
      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return BluetoothDevice(
          name: map['name'] as String? ?? 'Unknown',
          macAddress: map['mac'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<BluetoothDevice>> scanDevices() async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>('checkPermissions') ?? false;
      if (!granted) {
        final req = await _methodChannel.invokeMethod<bool>('requestPermissions') ?? false;
        if (!req) return await getPairedDevices();
      }

      final List<dynamic>? list = await _methodChannel.invokeMethod<List<dynamic>>('startScan');
      final scanned = (list ?? []).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return BluetoothDevice(
          name: map['name'] as String? ?? 'Unknown',
          macAddress: map['mac'] as String? ?? '',
        );
      }).toList();

      final paired = await getPairedDevices();
      final seen = <String>{};
      final combined = <BluetoothDevice>[];
      for (final d in [...paired, ...scanned]) {
        if (d.macAddress.isNotEmpty && seen.add(d.macAddress)) {
          combined.add(d);
        }
      }
      return combined.isNotEmpty ? combined : paired;
    } catch (_) {
      return await getPairedDevices();
    }
  }

  // --- Protocol Parsing Helpers ---

  Uint8List buildPacket(int opCode, int cmdId, int sequenceSn, [Uint8List? payloadData]) {
    final payloadLen = payloadData?.length ?? 0;
    final totalLen = payloadLen + 1;
    final builder = BytesBuilder();
    builder.add([0xAA, 0xBB, 0xCC]); // START_PREFIX
    builder.addByte(opCode);
    builder.addByte(cmdId);
    builder.addByte((totalLen >> 8) & 0xFF);
    builder.addByte(totalLen & 0xFF);
    builder.addByte(sequenceSn & 0xFF);
    if (payloadData != null && payloadData.isNotEmpty) {
      builder.add(payloadData);
    }
    builder.add([0xDD, 0xEE, 0xFF]); // END_SUFFIX
    return builder.toBytes();
  }

  Uint8List buildSettingTlv(int attrId, Uint8List valueBytes) {
    final length = valueBytes.length + 1;
    final builder = BytesBuilder();
    builder.addByte(length);
    builder.addByte(attrId);
    builder.add(valueBytes);
    return builder.toBytes();
  }

  Map<int, Uint8List> parseTlvBlocks(Uint8List payload, {bool hasStatusByte = false}) {
    var data = payload;
    if (hasStatusByte && data.isNotEmpty) {
      data = data.sublist(1);
    }
    final attrs = <int, Uint8List>{};
    var idx = 0;
    while (idx < data.length) {
      if (idx + 2 > data.length) break;
      final attrLen = data[idx];
      if (attrLen < 1) break;
      final attrId = data[idx + 1];
      final valLen = attrLen - 1;
      if (idx + 2 + valLen > data.length) break;
      final val = data.sublist(idx + 2, idx + 2 + valLen);
      attrs[attrId] = val;
      idx += 2 + valLen;
    }
    return attrs;
  }

  Map<int, Uint8List> parseConfigBlocks(Uint8List payload, {bool hasStatusByte = false}) {
    var data = payload;
    if (hasStatusByte && data.isNotEmpty) {
      data = data.sublist(1);
    }
    final configs = <int, Uint8List>{};
    var idx = 0;
    while (idx < data.length) {
      if (idx + 3 > data.length) break;
      final length = data[idx];
      if (length < 2) break;
      final configId = (data[idx + 1] << 8) | data[idx + 2];
      final valLen = length - 2;
      if (idx + 3 + valLen > data.length) break;
      final val = data.sublist(idx + 3, idx + 3 + valLen);
      configs[configId] = val;
      idx += 3 + valLen;
    }
    return configs;
  }

  // --- Read & Write Loop ---

  Future<void> _writePacket(int opCode, int cmdId, [Uint8List? payload]) async {
    _sequenceSn = (_sequenceSn + 1) & 0xFF;
    final packet = buildPacket(opCode, cmdId, _sequenceSn, payload);
    try {
      await _methodChannel.invokeMethod('write', {'bytes': packet});
    } catch (_) {}
  }

  Future<void> _writeSetting(int attrId, int val) async {
    final tlv = buildSettingTlv(attrId, Uint8List.fromList([val]));
    await _writePacket(opRead, cmdSetDeviceInfo, tlv);
    await Future.delayed(const Duration(milliseconds: 150));
    await _queryStatus();
  }

  Future<void> _queryStatus() async {
    // 1. Query name (Command 2, MASK_QUERY_NAME = 1)
    final nameMask = Uint8List(4).. [3] = 1;
    await _writePacket(opRead, cmdGetDeviceInfo, nameMask);
    await Future.delayed(const Duration(milliseconds: 150));

    // 2. Query battery (Command 2, MASK_QUERY_BATTERY = 4)
    final batMask = Uint8List(4).. [3] = 4;
    await _writePacket(opRead, cmdGetDeviceInfo, batMask);
    await Future.delayed(const Duration(milliseconds: 150));

    // 3. Query run info (Command 9, combined mask 8362528 = 0x7F9A20)
    final maskBytes = Uint8List(4);
    const combinedMask = 8362528; // 0x7F9A20 (ANC, Game, EQ, Anti-leak, LDAC, Multipoint, Spatial Audio, Spatial Scene, Wind Noise, Wear Det, Wear State, Auto-shutdown)
    maskBytes[0] = (combinedMask >> 24) & 0xFF;
    maskBytes[1] = (combinedMask >> 16) & 0xFF;
    maskBytes[2] = (combinedMask >> 8) & 0xFF;
    maskBytes[3] = combinedMask & 0xFF;
    await _writePacket(opRead, cmdGetDeviceRunInfo, maskBytes);
    await Future.delayed(const Duration(milliseconds: 150));

    // 4. Query EQ Preset (Command 243, config 7)
    await _writePacket(opRead, 243, Uint8List.fromList([0x00, 0x07]));
    await Future.delayed(const Duration(milliseconds: 150));

    // 5. Query ANC Level (Command 243, config 11)
    await _writePacket(opRead, 243, Uint8List.fromList([0x00, 0x0B]));
  }

  void _handleIncomingBytes(List<int> bytes) {
    _rxBuffer.addAll(bytes);
    _parseBuffer();
  }

  void _parseBuffer() {
    final startPrefix = [0xAA, 0xBB, 0xCC];
    final endSuffix = [0xDD, 0xEE, 0xFF];

    while (_rxBuffer.length >= 9) {
      var startIndex = -1;
      for (var i = 0; i <= _rxBuffer.length - 3; i++) {
        if (_rxBuffer[i] == startPrefix[0] &&
            _rxBuffer[i + 1] == startPrefix[1] &&
            _rxBuffer[i + 2] == startPrefix[2]) {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) {
        if (_rxBuffer.length > 2) {
          _rxBuffer.removeRange(0, _rxBuffer.length - 2);
        }
        break;
      }

      if (startIndex > 0) {
        _rxBuffer.removeRange(0, startIndex);
      }

      if (_rxBuffer.length < 7) {
        break;
      }

      final opCode = _rxBuffer[3];
      final cmdId = _rxBuffer[4];
      final totalLen = (_rxBuffer[5] << 8) | _rxBuffer[6];
      final expectedLength = 7 + totalLen + 3;

      if (_rxBuffer.length < expectedLength) {
        break;
      }

      final isSuffixValid = _rxBuffer[expectedLength - 3] == endSuffix[0] &&
          _rxBuffer[expectedLength - 2] == endSuffix[1] &&
          _rxBuffer[expectedLength - 1] == endSuffix[2];

      if (!isSuffixValid) {
        _rxBuffer.removeAt(0);
        continue;
      }

      // Payload starts after sequence number (index 8) and ends before suffix
      final payloadLen = totalLen > 0 ? totalLen - 1 : 0;
      final payload = payloadLen > 0
          ? Uint8List.fromList(_rxBuffer.sublist(8, 8 + payloadLen))
          : Uint8List(0);
      _rxBuffer.removeRange(0, expectedLength);

      _processIncomingPacket(opCode, cmdId, payload);
    }
  }

  void _processIncomingPacket(int opCode, int cmdId, Uint8List payload) {
    final hasStatus = (opCode & 0x40) == 0;

    if (cmdId == cmdGetDeviceRunInfo || cmdId == cmdReportDeviceStatus) {
      final attrs = parseTlvBlocks(payload, hasStatusByte: hasStatus);
      _updateStatusFromAttrs(attrs);
    } else if (cmdId == cmdGetDeviceInfo) {
      final attrs = parseTlvBlocks(payload, hasStatusByte: hasStatus);
      _updateDeviceInfoFromAttrs(attrs);
    } else if (cmdId == 243) {
      final configs = parseConfigBlocks(payload, hasStatusByte: hasStatus);
      if (configs.containsKey(7)) {
        final val = configs[7]!;
        if (val.isNotEmpty) {
          final eqStr = eqPresets[val[0]];
          if (eqStr != null) {
            _updateStatus(_status.copyWith(eqPreset: eqStr));
          }
        }
      }
      if (configs.containsKey(11)) {
        final val = configs[11]!;
        if (val.length >= 2) {
          _updateStatus(_status.copyWith(ancIntensity: val[1]));
        } else if (val.isNotEmpty) {
          _updateStatus(_status.copyWith(ancIntensity: val[0]));
        }
      }
    }
  }

  void _updateStatusFromAttrs(Map<int, Uint8List> attrs) {
    var updated = _status.copyWith(isConnected: true, isConnecting: false);

    if (attrs.containsKey(ordRunAncStatus)) {
      final val = attrs[ordRunAncStatus]![0];
      updated = updated.copyWith(ancMode: ancModes[val] ?? 'Unknown');
    }
    if (attrs.containsKey(ordRunEqMode)) {
      final val = attrs[ordRunEqMode]![0];
      final eqStr = eqPresets[val];
      if (eqStr != null) {
        updated = updated.copyWith(eqPreset: eqStr);
      }
    }
    if (attrs.containsKey(ordRunGameMode)) {
      updated = updated.copyWith(gameMode: attrs[ordRunGameMode]![0] == 1);
    }
    if (attrs.containsKey(ordRunWindNoise)) {
      updated = updated.copyWith(windNoise: attrs[ordRunWindNoise]![0] == 1);
    }
    if (attrs.containsKey(ordRunMultipoint)) {
      updated = updated.copyWith(multipoint: attrs[ordRunMultipoint]![0] == 1);
    }
    if (attrs.containsKey(ordRunLdac)) {
      updated = updated.copyWith(ldac: attrs[ordRunLdac]![0] == 1);
    }
    if (attrs.containsKey(ordRunWearDetection)) {
      updated = updated.copyWith(wearDetection: attrs[ordRunWearDetection]![0] == 1);
    }
    if (attrs.containsKey(ordRunAntiLeak)) {
      updated = updated.copyWith(antiLeak: attrs[ordRunAntiLeak]![0] == 1);
    }
    if (attrs.containsKey(ordRunAutoShutdown)) {
      final val = attrs[ordRunAutoShutdown]![0];
      int? shutdownIdx;
      if (val == 1) {
        shutdownIdx = 0;
      } else if (val == 2) {
        shutdownIdx = 1;
      } else if (val == 6) {
        shutdownIdx = 2;
      } else if (val == 10) {
        shutdownIdx = 3;
      } else if (val == 255) {
        shutdownIdx = 4;
      }
      updated = updated.copyWith(autoShutdownIndex: shutdownIdx);
    }
    if (attrs.containsKey(ordRunSpatialAudio)) {
      final val = attrs[ordRunSpatialAudio]![0];
      String mode = 'Off';
      if (val == 0) {
        mode = 'Dynamic';
      } else if (val == 1) {
        mode = 'Static';
      } else if (val == 2) {
        mode = 'Off';
      }
      updated = updated.copyWith(spatialAudioMode: mode);
    }
    if (attrs.containsKey(ordRunSpatialScene)) {
      final val = attrs[ordRunSpatialScene]![0];
      String scene = 'Music';
      if (val == 0) {
        scene = 'Music';
      } else if (val == 1) {
        scene = 'Sport';
      } else if (val == 2) {
        scene = 'Movie';
      }
      updated = updated.copyWith(spatialScene: scene);
    }

    _updateStatus(updated);
  }

  void _updateDeviceInfoFromAttrs(Map<int, Uint8List> attrs) {
    var updated = _status;
    if (attrs.containsKey(ordDevName)) {
      final nameBytes = attrs[ordDevName]!;
      final name = utf8.decode(nameBytes, allowMalformed: true).replaceAll('\x00', '').trim();
      if (name.isNotEmpty) {
        updated = updated.copyWith(deviceName: name);
      }
    }
    if (attrs.containsKey(ordDevBattery)) {
      final batBytes = attrs[ordDevBattery]!;
      if (batBytes.length == 1) {
        updated = updated.copyWith(
          batteryPercent: batBytes[0],
          batteryLeft: null,
          batteryRight: null,
          batteryCase: null,
        );
      } else if (batBytes.length >= 2) {
        final bLeft = batBytes[0];
        final bRight = batBytes[1];
        final bCase = batBytes.length >= 3 ? batBytes[2] : null;
        updated = updated.copyWith(
          batteryPercent: bLeft,
          batteryLeft: bLeft,
          batteryRight: bRight,
          batteryCase: bCase,
        );
      }
    }
    _updateStatus(updated);
  }

  // --- HeadphoneService API Implementations ---

  @override
  Future<void> setAncMode(int mode) async {
    await _writeSetting(4, mode);
  }

  @override
  Future<void> setAncLevel(int level) async {
    // Config ID 11 (opcode 242, opRead): payload is [length=4, config_id_hi=0, config_id_lo=11, 1, level]
    await _writePacket(opRead, 242, Uint8List.fromList([4, 0, 11, 1, level]));
    await Future.delayed(const Duration(milliseconds: 150));
    await _queryStatus();
  }

  @override
  Future<void> setGameMode(bool enabled) async {
    await _writeSetting(5, enabled ? 1 : 0);
  }

  @override
  Future<void> setWindNoise(bool enabled) async {
    await _writeSetting(12, enabled ? 1 : 0);
  }

  @override
  Future<void> setMultipoint(bool enabled) async {
    await _writeSetting(9, enabled ? 1 : 0);
  }

  @override
  Future<void> setLdac(bool enabled) async {
    await _writeSetting(8, enabled ? 1 : 0);
  }

  @override
  Future<void> setWearDetection(bool enabled) async {
    await _writeSetting(13, enabled ? 1 : 0);
  }

  @override
  Future<void> setAntiLeak(bool enabled) async {
    await _writeSetting(7, enabled ? 1 : 0);
  }

  @override
  Future<void> setAutoShutdown(int timerVal) async {
    await _writeSetting(0, timerVal);
  }

  @override
  Future<void> setSpatialAudio(String mode) async {
    int val = 2; // Off
    if (mode == 'Dynamic') val = 0;
    if (mode == 'Static') val = 1;
    await _writeSetting(10, val);
  }

  @override
  Future<void> setSpatialScene(int sceneIdx) async {
    await _writeSetting(11, sceneIdx);
  }

  @override
  Future<void> setEqPreset(int presetIdx) async {
    final isS40 = _status.eqType == 's40';
    final writeVal = isS40 ? (const {0: 0, 1: 6, 2: 2, 3: 7, 4: 3}[presetIdx] ?? presetIdx) : presetIdx;
    await _writeSetting(2, writeVal);
    // Also send Config 7
    final cfgPayload = Uint8List.fromList([3, 0, 7, writeVal]);
    await _writePacket(opRead, 242, cfgPayload);
    await Future.delayed(const Duration(milliseconds: 150));
    await _queryStatus();
  }

  @override
  Future<void> setCustomEq(List<double> gains) async {
    const frequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    final items = <String>[];
    for (var i = 0; i < frequencies.length; i++) {
      final g = i < gains.length ? gains[i] : 0.0;
      items.add('1,${g.toStringAsFixed(1)},${frequencies[i]},1.0');
    }
    final line = '0.0,0.0,${frequencies.length},${items.join(',')},';
    final eqFileStr = '$line\n$line';
    final fileBytes = utf8.encode(eqFileStr);
    final fileLen = fileBytes.length;

    final paramsData = Uint8List(3 + fileLen);
    paramsData[0] = (fileLen >> 8) & 0xFF;
    paramsData[1] = fileLen & 0xFF;
    paramsData[2] = 0x01; // file type EQ
    paramsData.setRange(3, 3 + fileLen, fileBytes);

    await _writePacket(opWrite, cmdSendDeviceFile, paramsData);
    await Future.delayed(const Duration(milliseconds: 150));
    await setEqPreset(240);
  }

  @override
  Future<void> setGesture(int gestureType, int leftFunc, int rightFunc) async {
    final payload = Uint8List.fromList([5, 0, 2, gestureType, leftFunc, rightFunc]);
    await _writePacket(opRead, 242, payload);
    await Future.delayed(const Duration(milliseconds: 150));
    await _queryStatus();
  }

  @override
  Future<void> renameDevice(String newName) async {
    var nameBytes = utf8.encode(newName);
    if (nameBytes.length > 30) nameBytes = nameBytes.sublist(0, 30);
    final payload = Uint8List(nameBytes.length + 3);
    payload[0] = nameBytes.length + 2;
    payload[1] = 0;
    payload[2] = 8;
    payload.setRange(3, 3 + nameBytes.length, nameBytes);
    await _writePacket(opRead, 242, payload);
    await Future.delayed(const Duration(milliseconds: 150));
    await _queryStatus();
  }

  @override
  Future<void> findDevice(bool play) async {
    final payload = Uint8List.fromList([4, 0, 9, play ? 1 : 0, 3]);
    await _writePacket(opRead, 242, payload);
    await Future.delayed(const Duration(milliseconds: 150));
    await _queryStatus();
  }

  @override
  Future<void> refreshStatus() async {
    await _queryStatus();
  }

  @override
  void dispose() {
    disconnect();
    _controller.close();
  }
}
