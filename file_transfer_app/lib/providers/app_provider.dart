import 'package:flutter/foundation.dart';
import '../services/device_discovery_service.dart';
import '../services/http_server_service.dart';
import '../services/transfer_service.dart';
import '../services/database_service.dart';
import '../services/relay_service.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../utils/constants.dart';

/// Main application provider managing all services
class AppProvider with ChangeNotifier {
  // Services
  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();
  final HttpServerService _httpServerService = HttpServerService();
  final TransferService _transferService = TransferService();
  final DatabaseService _databaseService = DatabaseService();
  final RelayService _relayService = RelayService();

  // State
  List<Device> _devices = [];
  final List<Transfer> _activeTransfers = [];
  List<Transfer> _transferHistory = [];
  Map<String, dynamic> _statistics = {};
  bool _isInitialized = false;
  ConnectionMode _connectionMode = ConnectionMode.localNetwork;

  // Relay settings (should be in preferences)
  String _relayUrl =
      'ws://192.168.1.5:8081'; // Default for testing on local network

  // Getters
  List<Device> get devices => _devices;
  Device? get ownDevice => _discoveryService.ownDevice;
  List<Transfer> get activeTransfers => _activeTransfers;
  List<Transfer> get transferHistory => _transferHistory;
  Map<String, dynamic> get statistics => _statistics;
  bool get isInitialized => _isInitialized;
  ConnectionMode get connectionMode => _connectionMode;
  bool get isServerRunning => _httpServerService.isRunning;
  bool get isDiscoveryRunning => _discoveryService.isRunning;
  bool get isRelayConnected => _relayService.isConnected;

  /// Initialize the app
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        print('Initializing app...');
      }

      // Start HTTP server
      await _httpServerService.startServer();

      // Start local device discovery
      await _discoveryService.startDiscovery();

      // Listen to local device updates
      _discoveryService.devicesStream.listen((devices) {
        if (_connectionMode == ConnectionMode.localNetwork) {
          _devices = devices;
          notifyListeners();
        }
      });

      // Listen to relayed device updates
      _relayService.devicesStream.listen((devices) {
        if (_connectionMode == ConnectionMode.internet) {
          _devices = devices;
          notifyListeners();
        }
      });

      // Listen to transfer updates (from local receiving)
      _httpServerService.transferStream.listen((transfer) {
        _handleTransferUpdate(transfer);
      });

      // Listen to transfer updates (from relay receiving)
      _relayService.transferStream.listen((transfer) {
        _handleTransferUpdate(transfer);
      });

      // Listen to transfer updates (from sending)
      _transferService.transferStream.listen((transfer) {
        _handleTransferUpdate(transfer);
      });

      // Load transfer history
      await _loadTransferHistory();

      // Load statistics
      await _loadStatistics();

      _isInitialized = true;
      notifyListeners();

      if (kDebugMode) {
        print('App initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing app: $e');
      }
      rethrow;
    }
  }

  /// Handle transfer update
  void _handleTransferUpdate(Transfer transfer) async {
    // Update active transfers
    final index = _activeTransfers.indexWhere((t) => t.id == transfer.id);
    if (index != -1) {
      _activeTransfers[index] = transfer;
    } else {
      _activeTransfers.add(transfer);
    }

    // Save to database when transfer completes or fails
    if (transfer.isComplete || transfer.isFailed) {
      await _databaseService.insertTransfer(transfer);

      // Remove from active transfers
      _activeTransfers.removeWhere((t) => t.id == transfer.id);

      // Reload history and statistics
      await _loadTransferHistory();
      await _loadStatistics();
    } else if (transfer.isActive) {
      // Update database with progress
      await _databaseService.updateTransfer(transfer);
    }

    notifyListeners();
  }

  /// Send file to device
  Future<Transfer> sendFile({
    required String filePath,
    required Device receiver,
  }) async {
    // Determine transport
    RelayService? relayToUse;
    if (receiver.ipAddress == 'relay' ||
        _connectionMode == ConnectionMode.internet) {
      relayToUse = _relayService;
    }

    final transfer = await _transferService.sendFile(
      filePath: filePath,
      receiver: receiver,
      sender: ownDevice,
      relayService: relayToUse,
    );

    // Save to database
    await _databaseService.insertTransfer(transfer);

    return transfer;
  }

  /// Cancel transfer
  Future<void> cancelTransfer(String transferId) async {
    await _transferService.cancelTransfer(transferId);
  }

  /// Refresh device list
  void refreshDevices() {
    if (_connectionMode == ConnectionMode.localNetwork) {
      _discoveryService.refresh();
    } else {
      // Relay refresh logic if needed
    }
  }

  /// Load transfer history
  Future<void> _loadTransferHistory() async {
    _transferHistory = await _databaseService.getAllTransfers(limit: 100);
    notifyListeners();
  }

  /// Load statistics
  Future<void> _loadStatistics() async {
    _statistics = await _databaseService.getStatistics();
    notifyListeners();
  }

  /// Get completed transfers
  Future<List<Transfer>> getCompletedTransfers() async {
    return await _databaseService.getCompletedTransfers();
  }

  /// Get failed transfers
  Future<List<Transfer>> getFailedTransfers() async {
    return await _databaseService.getFailedTransfers();
  }

  /// Search transfers
  Future<List<Transfer>> searchTransfers(String query) async {
    return await _databaseService.searchTransfers(query);
  }

  /// Clear transfer history
  Future<void> clearHistory() async {
    await _databaseService.clearHistory();
    await _loadTransferHistory();
    await _loadStatistics();
  }

  /// Set connection mode
  Future<void> setConnectionMode(ConnectionMode mode) async {
    _connectionMode = mode;

    if (mode == ConnectionMode.internet) {
      // Connect to relay if not connected
      if (!_relayService.isConnected && ownDevice != null) {
        try {
          await _relayService.connect(_relayUrl, ownDevice!);
        } catch (e) {
          if (kDebugMode) {
            print('Error connecting to relay: $e');
          }
          // Maybe revert mode or show error?
        }
      }
      // Clear current devices list to show only relayed ones
      _devices = [];
    } else {
      // Switch back to local discovery
      _devices = _discoveryService.devices;
      _discoveryService.refresh();
    }

    notifyListeners();
  }

  /// Update Relay URL
  void setRelayUrl(String url) {
    _relayUrl = url;
    if (_connectionMode == ConnectionMode.internet) {
      // Reconnect
      _relayService.disconnect();
      setConnectionMode(ConnectionMode.internet);
    }
  }

  /// Ping device
  Future<bool> pingDevice(Device device) async {
    if (device.ipAddress == 'relay') {
      return _relayService.isConnected; // Simple check for now
    }
    return await _transferService.pingDevice(device);
  }

  /// Dispose resources
  @override
  void dispose() {
    _discoveryService.dispose();
    _httpServerService.dispose();
    _transferService.dispose();
    _relayService.dispose();
    super.dispose();
  }
}
