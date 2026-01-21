import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../utils/constants.dart';
import '../utils/file_utils.dart';

class RelayService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final StreamController<List<Device>> _devicesController =
      StreamController<List<Device>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Transfer> _transferController =
      StreamController<Transfer>.broadcast();

  Device? _ownDevice;
  Timer? _pingTimer;

  // Active download sessions
  final Map<String, _RelayDownloadSession> _downloadSessions = {};

  // Getters
  Stream<List<Device>> get devicesStream => _devicesController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Transfer> get transferStream => _transferController.stream;
  bool get isConnected => _isConnected;

  // Connect to relay server
  Future<void> connect(String url, Device ownDevice) async {
    _ownDevice = ownDevice;

    try {
      print('Connecting to relay server: $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (data) => _handleData(data),
        onDone: () {
          print('Relay connection closed');
          _handleDisconnect();
        },
        onError: (error) {
          print('Relay connection error: $error');
          _handleDisconnect();
        },
      );

      _isConnected = true;
      _register();
      _startPing();
    } catch (e) {
      print('Failed to connect to relay: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _devicesController.add([]);

    // Clean up sessions
    for (var session in _downloadSessions.values) {
      session.fileSync.close();
    }
    _downloadSessions.clear();
  }

  void _register() {
    if (_ownDevice == null) return;

    _send({'type': 'register', 'device': _ownDevice!.toJson()});

    // Request device list immediately
    _send({'type': 'list_devices'});
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        _send({'type': 'ping'});
        // Refresh list periodically
        _send({'type': 'list_devices'});
      }
    });
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void sendMessage(String targetId, Map<String, dynamic> payload) {
    _send({'type': 'relay', 'targetId': targetId, 'payload': payload});
  }

  void _handleData(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'devices_list':
          _handleDevicesList(message);
          break;

        case 'relayed_message':
          _handleRelayedMessage(message);
          break;

        case 'ack_register':
          print('Relay registration acknowledged');
          break;

        case 'pong':
          // keep-alive
          break;

        case 'error':
          print('Relay error: ${message['message']}');
          break;
      }
    } catch (e) {
      print('Error parsing relay message: $e');
    }
  }

  void _handleRelayedMessage(Map<String, dynamic> message) {
    if (message['payload'] == null) return;

    final payload = message['payload'] as Map<String, dynamic>;
    final senderId = message['senderId'] as String?;
    final type = payload['type'] as String?;

    // Inject senderId
    payload['_senderId'] = senderId;

    if (type == 'file_chunk') {
      _handleFileChunk(payload);
    } else if (type == 'file_complete') {
      _handleFileComplete(payload);
    } else if (type == 'file_start') {
      _handleFileStart(payload, senderId);
    } else {
      // Pass other messages (like handshake) to main stream
      _messageController.add(payload);
    }
  }

  Future<void> _handleFileStart(
    Map<String, dynamic> payload,
    String? senderId,
  ) async {
    try {
      final transferId = payload['transferId'];
      final fileName = payload['fileName'];
      final fileSize = payload['fileSize'] as int;

      final appDir = await getApplicationDocumentsDirectory();
      final receiveDir = Directory(
        '${appDir.path}/${AppConstants.receivedFilesFolder}',
      );
      if (!await receiveDir.exists()) {
        await receiveDir.create(recursive: true);
      }

      final safeName = FileUtils.getSafeFileName(fileName);
      final uniqueName = await FileUtils.getUniqueFileName(
        receiveDir.path,
        safeName,
      );
      final filePath = '${receiveDir.path}/$uniqueName';

      final file = File(filePath);
      final sink = file.openWrite();

      final session = _RelayDownloadSession(
        transferId: transferId,
        fileName: uniqueName,
        fileSize: fileSize,
        filePath: filePath,
        fileSync: sink,
        startTime: DateTime.now(),
        senderId: senderId,
      );

      _downloadSessions[transferId] = session;

      // Create transfer object
      final transfer = Transfer(
        id: transferId,
        fileName: uniqueName,
        fileSize: fileSize,
        filePath: filePath,
        status: TransferStatus.active,
        startTime: DateTime.now(),
        // We lack full sender device info here unless we look it up or passed it
      );

      _transferController.add(transfer);

      // Ack start if needed
      if (senderId != null) {
        sendMessage(senderId, {
          'type': 'ack_file_start',
          'transferId': transferId,
          'accepted': true,
        });
      }
    } catch (e) {
      print('Error starting relay file receive: $e');
    }
  }

  void _handleFileChunk(Map<String, dynamic> payload) {
    final transferId = payload['transferId'];
    final chunkData = base64Decode(payload['data']);

    final session = _downloadSessions[transferId];
    if (session != null) {
      session.fileSync.add(chunkData);
      session.bytesReceived += chunkData.length;

      // Progress update
      final elapsed =
          DateTime.now().difference(session.startTime).inMilliseconds / 1000;
      final speed = elapsed > 0 ? session.bytesReceived / elapsed : 0.0;

      final transfer = Transfer(
        id: transferId,
        fileName: session.fileName,
        fileSize: session.fileSize,
        filePath: session.filePath,
        status: TransferStatus.active,
        bytesTransferred: session.bytesReceived,
        speed: speed,
        startTime: session.startTime,
      );

      _transferController.add(transfer);
    }
  }

  Future<void> _handleFileComplete(Map<String, dynamic> payload) async {
    final transferId = payload['transferId'];
    final session = _downloadSessions[transferId];

    if (session != null) {
      await session.fileSync.close();

      final transfer = Transfer(
        id: transferId,
        fileName: session.fileName,
        fileSize: session.fileSize,
        filePath: session.filePath,
        status: TransferStatus.completed,
        bytesTransferred: session.bytesReceived,
        startTime: session.startTime,
        endTime: DateTime.now(),
      );

      _transferController.add(transfer);
      _downloadSessions.remove(transferId);

      print('Relay download completed: ${session.fileName}');

      if (session.senderId != null) {
        sendMessage(session.senderId!, {
          'type': 'ack_file_complete',
          'transferId': transferId,
          'success': true,
        });
      }
    }
  }

  void _handleDevicesList(Map<String, dynamic> message) {
    final list = message['devices'] as List;
    final devices = list.map((d) {
      return Device.fromJson({
        'id': d['id'],
        'name': d['name'],
        'platform': d['platform'],
        'ipAddress': 'relay', // Mark as relay
        'port': 0,
        'lastSeen': d['lastSeen'],
      });
    }).toList();

    // Filter out own device
    if (_ownDevice != null) {
      devices.removeWhere((d) => d.id == _ownDevice!.id);
    }

    _devicesController.add(devices);
  }

  void dispose() {
    disconnect();
    _devicesController.close();
    _messageController.close();
    _transferController.close();
  }
}

class _RelayDownloadSession {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String filePath;
  final IOSink fileSync;
  final DateTime startTime;
  final String? senderId;
  int bytesReceived = 0;

  _RelayDownloadSession({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    required this.fileSync,
    required this.startTime,
    this.senderId,
  });
}
