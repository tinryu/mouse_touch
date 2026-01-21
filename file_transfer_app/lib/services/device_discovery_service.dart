import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/device_model.dart';
import '../utils/constants.dart';
import '../utils/network_utils.dart';

/// Service for discovering devices on local network using UDP broadcast
class DeviceDiscoveryService {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  final List<Device> _discoveredDevices = [];
  final StreamController<List<Device>> _devicesController =
      StreamController<List<Device>>.broadcast();

  Device? _ownDevice;
  bool _isRunning = false;

  /// Stream of discovered devices
  Stream<List<Device>> get devicesStream => _devicesController.stream;

  /// List of current discovered devices
  List<Device> get devices => List.unmodifiable(_discoveredDevices);

  /// Own device information
  Device? get ownDevice => _ownDevice;

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Start discovery service
  Future<void> startDiscovery() async {
    if (_isRunning) {
      print('Discovery already running');
      return;
    }

    try {
      // Initialize own device info
      await _initializeOwnDevice();

      if (_ownDevice == null) {
        throw Exception('Failed to initialize own device');
      }

      // Bind UDP socket
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.udpDiscoveryPort,
      );

      _socket!.broadcastEnabled = true;

      print(
        'Discovery service started on port ${AppConstants.udpDiscoveryPort}',
      );
      print('Own device: ${_ownDevice!.name} (${_ownDevice!.ipAddress})');

      // Listen for incoming discovery messages
      _socket!.listen(_handleIncomingData);

      // Start broadcasting own presence
      _startBroadcasting();

      // Add debug devices for Emulator <-> Host testing
      _addDebugDevices();

      _isRunning = true;
    } catch (e) {
      print('Error starting discovery: $e');
      await stopDiscovery();
      rethrow;
    }
  }

  /// Add hardcoded devices for debugging (Emulator/Simulator)
  void _addDebugDevices() {
    if (!kDebugMode) return;

    if (Platform.isAndroid) {
      // Android Emulator -> Host PC
      // 10.0.2.2 is the special alias to your host loopback interface
      _updateDevice(
        Device(
          id: 'host_pc_debug',
          name: 'Host PC (Debug)',
          ipAddress: '10.0.2.2',
          port: AppConstants.httpPort,
          platform: DevicePlatform.windows, // Assumption
          lastSeen: DateTime.now(),
        ),
      );
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Host PC -> Android Emulator
      // Requires: adb forward tcp:8080 tcp:8080
      _updateDevice(
        Device(
          id: 'emulator_debug',
          name: 'Android Emulator (Debug)',
          ipAddress: '127.0.0.1',
          port: AppConstants.httpPort,
          platform: DevicePlatform.android, // Assumption
          lastSeen: DateTime.now(),
        ),
      );
    }
  }

  /// Stop discovery service
  Future<void> stopDiscovery() async {
    _isRunning = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    _socket?.close();
    _socket = null;

    _discoveredDevices.clear();
    _devicesController.add([]);

    print('Discovery service stopped');
  }

  /// Initialize own device information
  Future<void> _initializeOwnDevice() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final uuid = const Uuid();

      String deviceId = uuid.v4();
      String deviceName = 'Unknown Device';
      DevicePlatform platform = DevicePlatform.unknown;

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceName = info.model;
        platform = DevicePlatform.android;
        deviceId = info.id;
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        deviceName = info.computerName;
        platform = DevicePlatform.windows;
        deviceId = info.deviceId;
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        deviceName = info.computerName;
        platform = DevicePlatform.macos;
        deviceId = info.systemGUID ?? deviceId;
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        deviceName = info.name;
        platform = DevicePlatform.linux;
        deviceId = info.machineId ?? deviceId;
      }

      final ipAddress = await NetworkUtils.getLocalIPAddress();

      if (ipAddress == null) {
        throw Exception('Could not get local IP address');
      }

      _ownDevice = Device(
        id: deviceId,
        name: deviceName,
        ipAddress: ipAddress,
        port: AppConstants.httpPort,
        platform: platform,
        lastSeen: DateTime.now(),
      );
    } catch (e) {
      print('Error initializing device: $e');
      rethrow;
    }
  }

  /// Start broadcasting own device info
  void _startBroadcasting() {
    _broadcastTimer?.cancel();

    // Broadcast immediately
    _broadcastOwnDevice();

    // Then broadcast periodically
    _broadcastTimer = Timer.periodic(AppConstants.discoveryInterval, (_) {
      _broadcastOwnDevice();
      _cleanupStaleDevices();
    });
  }

  /// Broadcast own device information
  void _broadcastOwnDevice() {
    if (_socket == null || _ownDevice == null) return;

    try {
      final message = {
        'type': AppConstants.discoveryMessage,
        'device': _ownDevice!.toJson(),
      };

      final data = utf8.encode(jsonEncode(message));
      final broadcastAddress = NetworkUtils.getBroadcastAddress(
        _ownDevice!.ipAddress,
      );

      if (broadcastAddress != null) {
        _socket!.send(
          data,
          InternetAddress(broadcastAddress),
          AppConstants.udpDiscoveryPort,
        );
      }
    } catch (e) {
      print('Error broadcasting: $e');
    }
  }

  /// Handle incoming UDP data
  void _handleIncomingData(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _socket == null) return;

    try {
      final datagram = _socket!.receive();
      if (datagram == null) return;

      final message = utf8.decode(datagram.data);
      final data = jsonDecode(message) as Map<String, dynamic>;

      // Check message type
      if (data['type'] != AppConstants.discoveryMessage) return;

      // Parse device info
      final deviceData = data['device'] as Map<String, dynamic>;
      final device = Device.fromJson(deviceData);

      // Ignore own device
      if (_ownDevice != null && device.id == _ownDevice!.id) return;

      // Update or add device
      _updateDevice(device);
    } catch (e) {
      print('Error handling incoming data: $e');
    }
  }

  /// Update device in the list
  void _updateDevice(Device device) {
    final index = _discoveredDevices.indexWhere((d) => d.id == device.id);

    if (index != -1) {
      // Update existing device
      _discoveredDevices[index] = device.copyWith(lastSeen: DateTime.now());
    } else {
      // Add new device
      _discoveredDevices.add(device.copyWith(lastSeen: DateTime.now()));
      print('Discovered device: ${device.name} (${device.ipAddress})');
    }

    // Notify listeners
    _devicesController.add(List.from(_discoveredDevices));
  }

  /// Remove stale devices (not seen in 10 seconds)
  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final initialCount = _discoveredDevices.length;

    _discoveredDevices.removeWhere((device) {
      // Keep debug devices
      if (device.id == 'host_pc_debug' || device.id == 'emulator_debug') {
        return false;
      }

      final isStale = now.difference(device.lastSeen).inSeconds > 10;
      if (isStale) {
        print('Removed stale device: ${device.name}');
      }
      return isStale;
    });

    if (_discoveredDevices.length != initialCount) {
      _devicesController.add(List.from(_discoveredDevices));
    }
  }

  /// Refresh device list (force cleanup)
  void refresh() {
    _cleanupStaleDevices();
  }

  /// Dispose the service
  void dispose() {
    stopDiscovery();
    _devicesController.close();
  }
}
