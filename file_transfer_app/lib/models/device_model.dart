import '../utils/constants.dart';

/// Device model representing a discovered device
class Device {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final DevicePlatform platform;
  final DateTime lastSeen;
  final String? publicKey;

  Device({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.platform,
    required this.lastSeen,
    this.publicKey,
  });

  /// Create device from JSON
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int,
      platform: DevicePlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => DevicePlatform.unknown,
      ),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      publicKey: json['publicKey'] as String?,
    );
  }

  /// Convert device to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'platform': platform.name,
      'lastSeen': lastSeen.toIso8601String(),
      'publicKey': publicKey,
    };
  }

  /// Copy with modifications
  Device copyWith({
    String? name,
    String? ipAddress,
    int? port,
    DevicePlatform? platform,
    DateTime? lastSeen,
    String? publicKey,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      platform: platform ?? this.platform,
      lastSeen: lastSeen ?? this.lastSeen,
      publicKey: publicKey ?? this.publicKey,
    );
  }

  /// Get platform icon
  String getPlatformIcon() {
    switch (platform) {
      case DevicePlatform.android:
        return '📱';
      case DevicePlatform.windows:
        return '💻';
      case DevicePlatform.macos:
        return '🖥️';
      case DevicePlatform.linux:
        return '🐧';
      default:
        return '📟';
    }
  }

  /// Check if device is still active (seen within last 10 seconds)
  bool isActive() {
    return DateTime.now().difference(lastSeen).inSeconds < 10;
  }

  @override
  String toString() {
    return 'Device(name: $name, ip: $ipAddress, platform: $platform)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
