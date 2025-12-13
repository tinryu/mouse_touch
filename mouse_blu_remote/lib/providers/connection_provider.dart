import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/bluetooth_service.dart';
import '../services/websocket_service.dart';
import '../models/mouse_event.dart';

enum ConnectionMode {
  bluetooth,
  websocket,
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class ConnectionProvider extends ChangeNotifier {
  final BluetoothService _bluetoothService = BluetoothService();
  final WebSocketService _webSocketService = WebSocketService();

  ConnectionMode _mode = ConnectionMode.bluetooth;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _errorMessage;

  // Bluetooth
  List<BluetoothDevice> _bondedDevices = [];
  BluetoothDevice? _selectedDevice;

  // WebSocket
  String _serverHost = '192.168.1.100';
  int _serverPort = 9090;
  List<String> _recentConnections = [];

  // Settings
  double _sensitivity = 1.0;
  double _scrollSpeed = 1.0;
  bool _hapticFeedback = true;

  // Getters
  ConnectionMode get mode => _mode;
  ConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<BluetoothDevice> get bondedDevices => _bondedDevices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  String get serverHost => _serverHost;
  int get serverPort => _serverPort;
  List<String> get recentConnections => _recentConnections;
  double get sensitivity => _sensitivity;
  double get scrollSpeed => _scrollSpeed;
  bool get hapticFeedback => _hapticFeedback;

  ConnectionProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadSettings();
    _setupListeners();
  }

  void _setupListeners() {
    _bluetoothService.statusStream.listen((btStatus) {
      switch (btStatus) {
        case BluetoothConnectionStatus.disconnected:
          _setStatus(ConnectionStatus.disconnected);
          break;
        case BluetoothConnectionStatus.connecting:
          _setStatus(ConnectionStatus.connecting);
          break;
        case BluetoothConnectionStatus.connected:
          _setStatus(ConnectionStatus.connected);
          break;
        case BluetoothConnectionStatus.error:
          _setStatus(ConnectionStatus.error);
          break;
      }
    });

    _bluetoothService.errorStream.listen((error) {
      _setError(error);
    });

    _webSocketService.statusStream.listen((wsStatus) {
      switch (wsStatus) {
        case WebSocketConnectionStatus.disconnected:
          _setStatus(ConnectionStatus.disconnected);
          break;
        case WebSocketConnectionStatus.connecting:
          _setStatus(ConnectionStatus.connecting);
          break;
        case WebSocketConnectionStatus.connected:
          _setStatus(ConnectionStatus.connected);
          break;
        case WebSocketConnectionStatus.error:
          _setStatus(ConnectionStatus.error);
          break;
      }
    });

    _webSocketService.errorStream.listen((error) {
      _setError(error);
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverHost = prefs.getString('server_host') ?? '192.168.1.100';
      _serverPort = prefs.getInt('server_port') ?? 9090;
      _recentConnections = prefs.getStringList('recent_connections') ?? [];
      _sensitivity = prefs.getDouble('sensitivity') ?? 1.0;
      _scrollSpeed = prefs.getDouble('scroll_speed') ?? 1.0;
      _hapticFeedback = prefs.getBool('haptic_feedback') ?? true;
      final modeIndex = prefs.getInt('connection_mode') ?? 0;
      _mode = ConnectionMode.values[modeIndex];
      notifyListeners();
    } catch (e) {
      print('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_host', _serverHost);
      await prefs.setInt('server_port', _serverPort);
      await prefs.setStringList('recent_connections', _recentConnections);
      await prefs.setDouble('sensitivity', _sensitivity);
      await prefs.setDouble('scroll_speed', _scrollSpeed);
      await prefs.setBool('haptic_feedback', _hapticFeedback);
      await prefs.setInt('connection_mode', _mode.index);
    } catch (e) {
      print('Failed to save settings: $e');
    }
  }

  void setMode(ConnectionMode mode) {
    _mode = mode;
    _saveSettings();
    notifyListeners();
  }

  void setServerHost(String host) {
    _serverHost = host;
    _saveSettings();
    notifyListeners();
  }

  void setServerPort(int port) {
    _serverPort = port;
    _saveSettings();
    notifyListeners();
  }

  void setSensitivity(double value) {
    _sensitivity = value;
    _saveSettings();
    notifyListeners();
  }

  void setScrollSpeed(double value) {
    _scrollSpeed = value;
    _saveSettings();
    notifyListeners();
  }

  void setHapticFeedback(bool value) {
    _hapticFeedback = value;
    _saveSettings();
    notifyListeners();
  }

  Future<void> scanBluetoothDevices() async {
    try {
      final isEnabled = await _bluetoothService.isBluetoothEnabled();
      if (!isEnabled) {
        final enabled = await _bluetoothService.requestEnable();
        if (!enabled) {
          _setError('Bluetooth is not enabled');
          return;
        }
      }

      _bondedDevices = await _bluetoothService.getBondedDevices();
      notifyListeners();
    } catch (e) {
      _setError('Failed to scan devices: $e');
    }
  }

  void selectDevice(BluetoothDevice device) {
    _selectedDevice = device;
    notifyListeners();
  }

  Future<bool> connect() async {
    if (_mode == ConnectionMode.bluetooth) {
      if (_selectedDevice == null) {
        _setError('No device selected');
        return false;
      }
      return await _bluetoothService.connect(_selectedDevice!);
    } else {
      final success = await _webSocketService.connect(_serverHost, _serverPort);
      if (success) {
        _addRecentConnection('$_serverHost:$_serverPort');
      }
      return success;
    }
  }

  Future<void> disconnect() async {
    if (_mode == ConnectionMode.bluetooth) {
      await _bluetoothService.disconnect();
    } else {
      await _webSocketService.disconnect();
    }
  }

  Future<bool> sendMouseEvent(MouseEvent event) async {
    if (_mode == ConnectionMode.bluetooth) {
      return await _bluetoothService.sendMouseEvent(event);
    } else {
      return await _webSocketService.sendMouseEvent(event);
    }
  }

  void _addRecentConnection(String connection) {
    _recentConnections.remove(connection);
    _recentConnections.insert(0, connection);
    if (_recentConnections.length > 5) {
      _recentConnections = _recentConnections.sublist(0, 5);
    }
    _saveSettings();
    notifyListeners();
  }

  void _setStatus(ConnectionStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _status = ConnectionStatus.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    _webSocketService.dispose();
    super.dispose();
  }
}
