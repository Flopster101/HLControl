import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/bluetooth_device.dart';
import '../models/headphone_status.dart';
import 'headphone_service.dart';

class LinuxHeadphoneService implements HeadphoneService {
  LinuxHeadphoneService() {
    _status = HeadphoneStatus.disconnected();
    _controller = StreamController<HeadphoneStatus>.broadcast(onListen: () {
      _controller.add(_status);
    });
  }

  late HeadphoneStatus _status;
  late StreamController<HeadphoneStatus> _controller;
  Process? _process;
  File? _scriptFile;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  @override
  Stream<HeadphoneStatus> get statusStream => _controller.stream;

  @override
  HeadphoneStatus get currentStatus => _status;

  Future<File> _extractScript() async {
    if (_scriptFile != null && await _scriptFile!.exists()) {
      return _scriptFile!;
    }
    final tempDir = Directory.systemTemp;
    final file = File(p.join(tempDir.path, 'hlcontrol_haylou_control.py'));

    // Always extract/overwrite on startup to ensure latest version is run
    final byteData = await rootBundle.load('assets/scripts/haylou_control.py');
    await file.writeAsBytes(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
    );

    await Process.run('chmod', ['+x', file.path]);
    _scriptFile = file;
    return file;
  }

  void _updateStatus(HeadphoneStatus newStatus) {
    _status = newStatus;
    _controller.add(_status);
  }

  @override
  Future<void> connect(String macAddress) async {
    if (_process != null) {
      await disconnect();
    }

    _updateStatus(_status.copyWith(isConnecting: true, isConnected: false));

    try {
      final script = await _extractScript();

      // Spawn python daemon in JSON mode
      _process = await Process.start('python3', [script.path, '--mac', macAddress, '--json']);

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
    try {
      final script = await _extractScript();
      // Run script in json mode with no MAC to scan paired devices
      final result = await Process.run('python3', [script.path, '--json']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        // The script prints connecting/failed status immediately, let's parse stdout line by line
        final lines = output.split('\n');
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final jsonMap = json.decode(line);
            if (jsonMap['connection_status'] == 'connecting' || jsonMap['connection_status'] == 'no_devices') {
              // The Python script prints connecting with mac and device_name
              if (jsonMap['mac'] != null) {
                return [
                  BluetoothDevice(
                    macAddress: jsonMap['mac'],
                    name: jsonMap['device_name'] ?? 'HAYLOU Headset',
                  )
                ];
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting paired devices: $e');
    }

    // Proactively query bluetoothctl as a backup to scan paired devices if python is slow
    try {
      final result = await Process.run('bluetoothctl', ['devices']);
      if (result.exitCode == 0) {
        final List<BluetoothDevice> devices = [];
        final output = result.stdout.toString();
        final regex = RegExp(r'Device\s+((?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})\s+(.*)');
        for (var line in output.split('\n')) {
          final match = regex.firstMatch(line);
          if (match != null) {
            final mac = match.group(1)!;
            final name = match.group(2)!;
            if (name.toLowerCase().contains('haylou') ||
                name.toLowerCase().contains('s40') ||
                name.toLowerCase().contains('s35') ||
                name.toLowerCase().contains('s30')) {
              devices.add(BluetoothDevice(macAddress: mac, name: name));
            }
          }
        }
        return devices;
      }
    } catch (_) {}

    return [];
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
          // Parse all settings properties
          final batteryStr = jsonMap['battery'] as String?;
          int batteryVal = 0;
          if (batteryStr != null && batteryStr != 'Unknown') {
            batteryVal = int.tryParse(batteryStr.replaceAll('%', '').trim()) ?? 0;
          }

          final ancStr = jsonMap['anc_mode'] as String? ?? 'Normal (Off)';
          final eqStr = jsonMap['eq_mode'] as String? ?? 'Default';

          final gameVal = jsonMap['game_mode'] == 'Enabled';
          final windVal = jsonMap['wind_noise'] == 'Enabled';
          final multiVal = jsonMap['multipoint'] == 'Enabled';
          final wearVal = jsonMap['wear_detection'] == 'Enabled';

          final shutdownStr = jsonMap['auto_shutdown'] as String?;
          int shutdownIdx = 4;
          if (shutdownStr != null) {
            if (shutdownStr.contains('30')) {
              shutdownIdx = 0;
            } else if (shutdownStr.contains('1 hour') || shutdownStr.contains('1 Hour')) {
              shutdownIdx = 1;
            } else if (shutdownStr.contains('3')) {
              shutdownIdx = 2;
            } else if (shutdownStr.contains('5')) {
              shutdownIdx = 3;
            }
          }

          final spatialVal = jsonMap['spatial_audio'] == 'Enabled';
          final sceneStr = jsonMap['spatial_scene'] as String? ?? 'Music';

          _updateStatus(HeadphoneStatus(
            isConnected: true,
            isConnecting: false,
            deviceName: jsonMap['device_name'] ?? 'HAYLOU S40',
            batteryPercent: batteryVal,
            ancMode: ancStr,
            ancIntensity: _status.ancIntensity, // preserved locally in UI
            eqPreset: eqStr,
            gameMode: gameVal,
            windNoise: windVal,
            multipoint: multiVal,
            wearDetection: wearVal,
            autoShutdownIndex: shutdownIdx,
            spatialAudioMode: spatialVal ? 'Static' : 'Off',
            spatialScene: sceneStr,
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
    final cmd = json.encode({'action': action, 'value': value});
    _process!.stdin.writeln(cmd);
  }

  @override
  Future<void> setAncMode(int mode) async {
    _sendCommand('set_anc', mode);
  }

  @override
  Future<void> setGameMode(bool enabled) async {
    _sendCommand('set_game_mode', enabled);
  }

  @override
  Future<void> setWindNoise(bool enabled) async {
    _sendCommand('set_wind_noise', enabled);
  }

  @override
  Future<void> setMultipoint(bool enabled) async {
    _sendCommand('set_multipoint', enabled);
  }

  @override
  Future<void> setWearDetection(bool enabled) async {
    _sendCommand('set_wear_detection', enabled);
  }

  @override
  Future<void> setAutoShutdown(int timerVal) async {
    _sendCommand('set_auto_shutdown', timerVal);
  }

  @override
  Future<void> setSpatialAudio(bool enabled) async {
    _sendCommand('set_spatial_audio', enabled);
  }

  @override
  Future<void> setSpatialScene(int sceneIdx) async {
    _sendCommand('set_spatial_scene', sceneIdx);
  }

  @override
  Future<void> setEqPreset(int presetIdx) async {
    _sendCommand('set_eq_preset', presetIdx);
  }

  @override
  Future<void> renameDevice(String newName) async {
    _sendCommand('rename', newName);
  }

  @override
  Future<void> refreshStatus() async {
    _sendCommand('get_status', null);
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
