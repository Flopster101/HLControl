import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/bluetooth_device.dart';
import '../models/headphone_status.dart';
import 'headphone_service.dart';

class DesktopHeadphoneService implements HeadphoneService {
  DesktopHeadphoneService() {
    _status = HeadphoneStatus.disconnected();
    _controller = StreamController<HeadphoneStatus>.broadcast(onListen: () {
      _controller.add(_status);
    });
  }

  late HeadphoneStatus _status;
  late StreamController<HeadphoneStatus> _controller;
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  File? _scriptFile;

  @override
  Stream<HeadphoneStatus> get statusStream => _controller.stream;

  @override
  HeadphoneStatus get currentStatus => _status;

  Future<String> _findPythonExecutable() async {
    if (Platform.isWindows) {
      for (final cmd in ['python.exe', 'python', 'py.exe', 'py']) {
        try {
          final result = await Process.run('where', [cmd]);
          if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
            return cmd;
          }
        } catch (_) {}
      }
      return 'python';
    } else {
      for (final cmd in ['python3', 'python']) {
        try {
          final result = await Process.run('which', [cmd]);
          if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
            return cmd;
          }
        } catch (_) {}
      }
      return 'python3';
    }
  }

  Future<File> _extractScript() async {
    if (_scriptFile != null && await _scriptFile!.exists()) {
      return _scriptFile!;
    }

    final tempDir = Directory.systemTemp;
    final file = File(p.join(tempDir.path, 'hlcontrol_haylou_control.py'));

    // Extract asset python script
    final byteData = await rootBundle.load('assets/scripts/haylou_control.py');
    await file.writeAsBytes(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );

    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['+x', file.path]);
      } catch (_) {}
    }
    _scriptFile = file;
    return file;
  }

  void _updateStatus(HeadphoneStatus newStatus) {
    _status = newStatus;
    if (!_controller.isClosed) {
      _controller.add(_status);
    }
  }

  @override
  Future<void> connect(String macAddress) async {
    if (_process != null) {
      await disconnect();
    }

    _updateStatus(_status.copyWith(isConnecting: true, isConnected: false));

    try {
      final script = await _extractScript();
      final pythonCmd = await _findPythonExecutable();

      // Spawn python daemon in JSON mode
      _process = await Process.start(
        pythonCmd,
        [script.path, '--mac', macAddress, '--json'],
        mode: ProcessStartMode.normal,
      );

      // Stream stdout line by line
      _stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleStdoutLine, onError: _handleError, onDone: _handleDone);

      // Stream stderr for debug logs
      _stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            // Forward subprocess logs to Flutter terminal debug
            // ignore: avoid_print
            print('[Python Daemon Log]: $line');
          });

    } catch (e) {
      _updateStatus(HeadphoneStatus.disconnected().copyWith(error: 'Failed to start daemon: $e'));
    }
  }

  @override
  Future<void> disconnect() async {
    _updateStatus(_status.copyWith(isConnected: false, isConnecting: false));

    // Send command to disconnect daemon
    _sendCommand('disconnect', null);

    // Cleanup streams
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    await _stderrSub?.cancel();
    _stderrSub = null;

    // Terminate process
    _process?.kill();
    _process = null;

    _updateStatus(HeadphoneStatus.disconnected());
  }

  @override
  Future<List<BluetoothDevice>> getPairedDevices() async {
    if (Platform.isWindows) {
      try {
        const psCmd = 'Get-PnpDevice -Class Bluetooth -Status OK | Select-Object -Property FriendlyName, InstanceId | ConvertTo-Json -Compress';
        final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', psCmd]);
        if (result.exitCode == 0) {
          final out = result.stdout.toString().trim();
          if (out.isEmpty) return [];

          dynamic decoded;
          try {
            decoded = json.decode(out);
          } catch (_) {
            return [];
          }

          final List<dynamic> items = decoded is List ? decoded : [decoded];
          final devices = <BluetoothDevice>[];

          final haylouRegex = RegExp(r'(haylou|s40|s35|s30|s33|hd01|w1|mori|flowbuds|purfree|airfree|earhook|t003|t013|t016|t021|ht02|ht03|ht06|bc04|ow02|ow03|x1)', caseSensitive: false);

          for (final item in items) {
            final name = item['FriendlyName'] as String? ?? '';
            final instanceId = item['InstanceId'] as String? ?? '';

            final match = RegExp(r'DEV_([0-9A-Fa-f]{12})').firstMatch(instanceId);
            if (match != null && name.isNotEmpty) {
              final rawMac = match.group(1)!;
              final formattedMac = List.generate(6, (i) => rawMac.substring(i * 2, i * 2 + 2)).join(':').toUpperCase();

              if (haylouRegex.hasMatch(name)) {
                if (!devices.any((d) => d.macAddress == formattedMac)) {
                  devices.add(BluetoothDevice(macAddress: formattedMac, name: name));
                }
              }
            }
          }
          return devices;
        }
      } catch (_) {}
      return [];
    } else {
      try {
        final result = await Process.run('bluetoothctl', ['devices']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          final devices = <BluetoothDevice>[];
          final regex = RegExp(r'^Device\s+((?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})\s+(.*)$');

          final haylouRegex = RegExp(r'(haylou|s40|s35|s30|s33|hd01|w1|mori|flowbuds|purfree|airfree|earhook|t003|t013|t016|t021|ht02|ht03|ht06|bc04|ow02|ow03|x1)', caseSensitive: false);

          for (final line in lines) {
            final match = regex.firstMatch(line.trim());
            if (match != null) {
              final mac = match.group(1)!;
              final name = match.group(2)!.trim();
              if (haylouRegex.hasMatch(name)) {
                devices.add(BluetoothDevice(macAddress: mac, name: name));
              }
            }
          }
          return devices;
        }
      } catch (_) {}
      return [];
    }
  }

  @override
  Future<List<BluetoothDevice>> scanDevices() async {
    if (!Platform.isWindows) {
      try {
        await Process.run('timeout', ['4', 'bluetoothctl', 'scan', 'on']);
      } catch (_) {}
    }
    return getPairedDevices();
  }

  void _handleStdoutLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final jsonMap = json.decode(line);

      if (jsonMap['connection_status'] != null) {
        final statusStr = jsonMap['connection_status'] as String;

        if (statusStr == 'disconnected' || statusStr == 'failed' || statusStr == 'no_devices') {
          _updateStatus(HeadphoneStatus.disconnected().copyWith(
            error: jsonMap['error'] ?? (statusStr == 'failed' ? 'Connection failed' : null)
          ));
        } else if (statusStr == 'connecting') {
          _updateStatus(_status.copyWith(isConnecting: true, isConnected: false));
        } else if (statusStr == 'connected') {
          // Parse single and TWS battery
          final batteryStr = jsonMap['battery'] as String?;
          int batteryVal = _status.batteryPercent;
          if (batteryStr != null && batteryStr != 'Unknown' && !batteryStr.contains('L:')) {
            batteryVal = int.tryParse(batteryStr.replaceAll('%', '').trim()) ?? _status.batteryPercent;
          }

          int? parseBatteryPct(String? val) {
            if (val == null) return null;
            return int.tryParse(val.replaceAll('%', '').trim());
          }

          final bLeft = parseBatteryPct(jsonMap['battery_left'] as String?);
          final bRight = parseBatteryPct(jsonMap['battery_right'] as String?);
          final bCase = parseBatteryPct(jsonMap['battery_case'] as String?);

          // Parse ANC mode & intensity
          final rawAnc = jsonMap['anc_mode'] as String?;
          final ancStr = (rawAnc != null && rawAnc != 'Unknown') ? rawAnc : _status.ancMode;

          final ancLevelStr = jsonMap['anc_level'] as String?;
          int ancIntensity = _status.ancIntensity;
          if (ancLevelStr == 'High') {
            ancIntensity = 0;
          } else if (ancLevelStr == 'Medium') {
            ancIntensity = 1;
          } else if (ancLevelStr == 'Low') {
            ancIntensity = 2;
          }

          // Parse EQ preset
          final rawEq = jsonMap['eq_mode'] as String?;
          final eqStr = (rawEq != null && rawEq != 'Unknown') ? rawEq : _status.eqPreset;

          bool? parseNullableBool(String? val) {
            if (val == null || val == 'Unknown' || val == 'N/A') return null;
            return val == 'Enabled';
          }

          final gameVal = parseNullableBool(jsonMap['game_mode'] as String?) ?? _status.gameMode;
          final windVal = parseNullableBool(jsonMap['wind_noise'] as String?) ?? _status.windNoise;
          final multiVal = parseNullableBool(jsonMap['multipoint'] as String?) ?? _status.multipoint;
          final ldacVal = parseNullableBool(jsonMap['ldac'] as String?) ?? _status.ldac;
          final wearVal = parseNullableBool(jsonMap['wear_detection'] as String?) ?? _status.wearDetection;
          final antiLeakVal = parseNullableBool(jsonMap['anti_leak'] as String?) ?? _status.antiLeak;

          final shutdownStr = jsonMap['auto_shutdown'] as String?;
          int? shutdownIdx = _status.autoShutdownIndex;
          if (shutdownStr != null && shutdownStr != 'Unknown' && shutdownStr != 'N/A') {
            if (shutdownStr.contains('30')) {
              shutdownIdx = 0;
            } else if (shutdownStr.contains('1 hour') || shutdownStr.contains('1 Hour')) {
              shutdownIdx = 1;
            } else if (shutdownStr.contains('3')) {
              shutdownIdx = 2;
            } else if (shutdownStr.contains('5')) {
              shutdownIdx = 3;
            } else if (shutdownStr.contains('Never')) {
              shutdownIdx = 4;
            }
          }

          final rawSpatial = jsonMap['spatial_audio'] as String?;
          final spatialStr = (rawSpatial != null && rawSpatial != 'Unknown' && rawSpatial != 'N/A') ? rawSpatial : _status.spatialAudioMode;
          final rawScene = jsonMap['spatial_scene'] as String?;
          final sceneStr = (rawScene != null && rawScene != 'Unknown' && rawScene != 'N/A') ? rawScene : _status.spatialScene;

          final modelInfoMap = jsonMap['model_info'] as Map<String, dynamic>? ?? _status.modelInfo;
          final gesturesMap = jsonMap['gestures'] as Map<String, dynamic>? ?? _status.gestures;

          _updateStatus(HeadphoneStatus(
            isConnected: true,
            isConnecting: false,
            deviceName: jsonMap['device_name'] ?? _status.deviceName,
            batteryPercent: batteryVal,
            batteryLeft: bLeft ?? _status.batteryLeft,
            batteryRight: bRight ?? _status.batteryRight,
            batteryCase: bCase ?? _status.batteryCase,
            ancMode: ancStr,
            ancIntensity: ancIntensity,
            eqPreset: eqStr,
            gameMode: gameVal,
            windNoise: windVal,
            multipoint: multiVal,
            ldac: ldacVal,
            wearDetection: wearVal,
            antiLeak: antiLeakVal,
            autoShutdownIndex: shutdownIdx,
            spatialAudioMode: spatialStr,
            spatialScene: sceneStr,
            modelInfo: modelInfoMap,
            gestures: gesturesMap,
            error: jsonMap['error'],
          ));
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error parsing json line from daemon: $e');
    }
  }

  void _handleError(dynamic err) {
    _updateStatus(HeadphoneStatus.disconnected().copyWith(error: 'Daemon connection error: $err'));
  }

  void _handleDone() {
    _updateStatus(HeadphoneStatus.disconnected());
  }

  void _sendCommand(String action, dynamic value) {
    if (_process == null) return;
    final cmd = json.encode({'action': action, 'command': action, 'value': value});
    _process!.stdin.writeln(cmd);
  }

  @override
  Future<void> setAncMode(int mode) async {
    String ancStr;
    switch (mode) {
      case 0: ancStr = 'Normal (Off)'; break;
      case 1: ancStr = 'ANC On'; break;
      case 2: ancStr = 'Transparency'; break;
      case 3: ancStr = 'Wind Noise (KANG_FENG)'; break;
      case 4: ancStr = 'Adaptive Auto-ANC'; break;
      default: ancStr = 'Normal (Off)';
    }
    _updateStatus(_status.copyWith(ancMode: ancStr));
    _sendCommand('set_anc', mode);
  }

  @override
  Future<void> setAncLevel(int level) async {
    _updateStatus(_status.copyWith(ancIntensity: level));
    _sendCommand('set_anc_level', level);
  }

  @override
  Future<void> setGameMode(bool enabled) async {
    _updateStatus(_status.copyWith(gameMode: enabled));
    _sendCommand('set_game_mode', enabled);
  }

  @override
  Future<void> setWindNoise(bool enabled) async {
    _updateStatus(_status.copyWith(windNoise: enabled));
    _sendCommand('set_wind_noise', enabled);
  }

  @override
  Future<void> setMultipoint(bool enabled) async {
    _updateStatus(_status.copyWith(multipoint: enabled));
    _sendCommand('set_multipoint', enabled);
  }

  @override
  Future<void> setLdac(bool enabled) async {
    _updateStatus(_status.copyWith(ldac: enabled));
    _sendCommand('set_ldac', enabled);
  }

  @override
  Future<void> setWearDetection(bool enabled) async {
    _updateStatus(_status.copyWith(wearDetection: enabled));
    _sendCommand('set_wear_detection', enabled);
  }

  @override
  Future<void> setAntiLeak(bool enabled) async {
    _updateStatus(_status.copyWith(antiLeak: enabled));
    _sendCommand('set_anti_leak', enabled);
  }

  @override
  Future<void> setAutoShutdown(int timerVal) async {
    int idx;
    switch (timerVal) {
      case 1: idx = 0; break;
      case 2: idx = 1; break;
      case 6: idx = 2; break;
      case 10: idx = 3; break;
      default: idx = 4;
    }
    _updateStatus(_status.copyWith(autoShutdownIndex: idx));
    _sendCommand('set_auto_shutdown', timerVal);
  }

  @override
  Future<void> setSpatialAudio(String mode) async {
    final normalized = mode.toLowerCase();
    int val;
    switch (normalized) {
      case 'dynamic':
        val = 0;
        break;
      case 'static':
        val = 1;
        break;
      case 'off':
      default:
        val = 2;
        break;
    }
    String canonicalMode;
    switch (val) {
      case 0: canonicalMode = 'Dynamic'; break;
      case 1: canonicalMode = 'Static'; break;
      default: canonicalMode = 'Off'; break;
    }
    _updateStatus(_status.copyWith(spatialAudioMode: canonicalMode));
    _sendCommand('set_spatial_audio', val);
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
    _sendCommand('set_spatial_scene', sceneIdx);
  }

  @override
  Future<void> setEqPreset(int presetIdx) async {
    final standardPresets = ['Default', 'Vocal', 'Rock', 'Classical', 'Popularity', 'Bass', 'Subwoofer', 'Soft', 'Outdoor'];
    String presetName;
    if (presetIdx == 15 || presetIdx == 240) {
      presetName = 'Custom/Customize';
    } else if (presetIdx >= 0 && presetIdx < standardPresets.length) {
      presetName = standardPresets[presetIdx];
    } else {
      presetName = 'Default';
    }
    _updateStatus(_status.copyWith(eqPreset: presetName));
    _sendCommand('set_eq_preset', presetIdx);
  }

  @override
  Future<void> setCustomEq(List<double> gains) async {
    _updateStatus(_status.copyWith(eqPreset: 'Custom/Customize'));
    _sendCommand('set_custom_eq', gains);
  }

  @override
  Future<void> setGesture(int gestureType, int leftFunc, int rightFunc) async {
    if (_process == null) return;
    final cmd = json.encode({
      'action': 'set_gesture',
      'command': 'set_gesture',
      'gesture_type': gestureType,
      'left_func': leftFunc,
      'right_func': rightFunc,
    });
    _process!.stdin.writeln(cmd);
  }

  @override
  Future<void> renameDevice(String newName) async {
    _updateStatus(_status.copyWith(deviceName: newName));
    _sendCommand('rename', newName);
  }

  @override
  Future<void> findDevice(bool play) async {
    _sendCommand('find_device', play);
  }

  @override
  Future<void> refreshStatus() async {
    _sendCommand('get_status', null);
  }

  @override
  void dispose() {
    disconnect();
    _controller.close();
  }
}

typedef LinuxHeadphoneService = DesktopHeadphoneService;
