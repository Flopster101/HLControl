import '../models/bluetooth_device.dart';
import '../models/headphone_status.dart';

abstract class HeadphoneService {
  Stream<HeadphoneStatus> get statusStream;
  HeadphoneStatus get currentStatus;

  Future<void> connect(String macAddress);
  Future<void> disconnect();
  Future<List<BluetoothDevice>> getPairedDevices();

  Future<void> setAncMode(int mode); // 0=Normal, 1=ANC, 2=Transparency, 4=Adaptive
  Future<void> setGameMode(bool enabled);
  Future<void> setWindNoise(bool enabled);
  Future<void> setMultipoint(bool enabled);
  Future<void> setWearDetection(bool enabled);
  Future<void> setAutoShutdown(int timerVal); // Liesheng protocol timer byte (1, 2, 6, 10, 255)
  Future<void> setSpatialAudio(String mode);
  Future<void> setSpatialScene(int sceneIdx); // 0=Music, 1=Sport, 2=Movie
  Future<void> setEqPreset(int presetIdx); // 0-4
  Future<void> renameDevice(String newName);
  Future<void> refreshStatus();
}
