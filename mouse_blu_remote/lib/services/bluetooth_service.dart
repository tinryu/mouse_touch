import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/mouse_event.dart';

enum BluetoothConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class BluetoothService {
  BluetoothConnection? _connection;
  BluetoothConnectionStatus _status = BluetoothConnectionStatus.disconnected;
  String? _errorMessage;

  final _statusController = StreamController<BluetoothConnectionStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<BluetoothConnectionStatus> get statusStream => _statusController.stream;
  Stream<String> get errorStream => _errorController.stream;
  BluetoothConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// Get list of bonded (paired) Bluetooth devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices;
    } catch (e) {
      _setError('Failed to get bonded devices: $e');
      return [];
    }
  }

  /// Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      return isEnabled ?? false;
    } catch (e) {
      _setError('Failed to check Bluetooth status: $e');
      return false;
    }
  }

  /// Request to enable Bluetooth
  Future<bool> requestEnable() async {
    try {
      final result = await FlutterBluetoothSerial.instance.requestEnable();
      return result ?? false;
    } catch (e) {
      _setError('Failed to enable Bluetooth: $e');
      return false;
    }
  }

  /// Connect to a Bluetooth device
  Future<bool> connect(BluetoothDevice device) async {
    if (_status == BluetoothConnectionStatus.connected) {
      await disconnect();
    }

    _setStatus(BluetoothConnectionStatus.connecting);

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _setStatus(BluetoothConnectionStatus.connected);

      // Listen for disconnection
      _connection!.input!.listen(
        (Uint8List data) {
          // Handle incoming data if needed (server responses)
          try {
            final message = utf8.decode(data);
            print('Received from server: $message');
          } catch (e) {
            print('Failed to decode message: $e');
          }
        },
        onDone: () {
          _setStatus(BluetoothConnectionStatus.disconnected);
        },
        onError: (error) {
          _setError('Connection error: $error');
          _setStatus(BluetoothConnectionStatus.error);
        },
      );

      return true;
    } catch (e) {
      _setError('Failed to connect: $e');
      _setStatus(BluetoothConnectionStatus.error);
      return false;
    }
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    try {
      await _connection?.close();
      _connection = null;
      _setStatus(BluetoothConnectionStatus.disconnected);
    } catch (e) {
      _setError('Failed to disconnect: $e');
    }
  }

  /// Send a mouse event to the connected device
  Future<bool> sendMouseEvent(MouseEvent event) async {
    if (_connection == null || !_connection!.isConnected) {
      _setError('Not connected to any device');
      return false;
    }

    try {
      final jsonString = event.toJsonString();
      final data = utf8.encode(jsonString + '\n'); // Add newline for message delimiter
      _connection!.output.add(Uint8List.fromList(data));
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      _setError('Failed to send event: $e');
      return false;
    }
  }

  void _setStatus(BluetoothConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void _setError(String error) {
    _errorMessage = error;
    _errorController.add(error);
    print('BluetoothService Error: $error');
  }

  void dispose() {
    _connection?.dispose();
    _statusController.close();
    _errorController.close();
  }
}
