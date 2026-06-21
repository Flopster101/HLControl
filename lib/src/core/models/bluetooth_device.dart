class BluetoothDevice {
  final String macAddress;
  final String name;

  BluetoothDevice({
    required this.macAddress,
    required this.name,
  });

  factory BluetoothDevice.fromJson(Map<String, dynamic> json) {
    return BluetoothDevice(
      macAddress: json['mac'] ?? json['mac_address'] ?? '',
      name: json['name'] ?? 'Unknown Device',
    );
  }
}
