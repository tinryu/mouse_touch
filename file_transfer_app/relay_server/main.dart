import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

// Device connection class
class DeviceConnection {
  final String id;
  final WebSocket socket;
  final DateTime connectedAt;
  String? name;
  String? platform;

  DeviceConnection({
    required this.id,
    required this.socket,
    required this.connectedAt,
  });
}

void main(List<String> args) async {
  final port = 8081; // distinct from HTTP server port 8080
  final connections = <String, DeviceConnection>{};

  try {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('Relay Server running on port $port');

    await for (HttpRequest request in server) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        _handleWebSocketInfo(request, connections);
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('File Transfer Relay Server Running')
          ..close();
      }
    }
  } catch (e) {
    print('Error starting server: $e');
  }
}

Future<void> _handleWebSocketInfo(
    HttpRequest request, Map<String, DeviceConnection> connections) async {
  try {
    final socket = await WebSocketTransformer.upgrade(request);
    print(
        'New connection from ${request.connectionInfo?.remoteAddress.address}');

    // UUID for temporary ID until registration
    String deviceId = const Uuid().v4();

    socket.listen(
      (data) {
        _handleMessage(
            socket, data, connections, deviceId, (newId) => deviceId = newId);
      },
      onDone: () {
        print('Connection closed: $deviceId');
        if (connections.containsKey(deviceId) &&
            connections[deviceId]!.socket == socket) {
          connections.remove(deviceId);
        }
      },
      onError: (error) {
        print('Error on socket $deviceId: $error');
        if (connections.containsKey(deviceId)) {
          connections.remove(deviceId);
        }
      },
    );
  } catch (e) {
    print('WebSocket upgrade error: $e');
  }
}

void _handleMessage(
  WebSocket socket,
  dynamic data,
  Map<String, DeviceConnection> connections,
  String currentDeviceId,
  Function(String) updateDeviceId,
) {
  try {
    final message = jsonDecode(data as String) as Map<String, dynamic>;
    final type = message['type'] as String?;

    if (type == null) return;

    switch (type) {
      case 'register':
        _handleRegister(
            socket, message, connections, currentDeviceId, updateDeviceId);
        break;

      case 'list_devices':
        _handleListDevices(socket, connections);
        break;

      case 'relay':
        _handleRelay(socket, message, connections, currentDeviceId);
        break;

      case 'ping':
        socket.add(jsonEncode({'type': 'pong'}));
        break;

      default:
        print('Unknown message type: $type');
    }
  } catch (e) {
    print('Error handling message: $e');
  }
}

void _handleRegister(
  WebSocket socket,
  Map<String, dynamic> message,
  Map<String, DeviceConnection> connections,
  String currentDeviceId,
  Function(String) updateDeviceId,
) {
  final deviceData = message['device'] as Map<String, dynamic>;
  final newDeviceId = deviceData['id'] as String;

  // Update socket mapping
  if (connections.containsKey(currentDeviceId) &&
      currentDeviceId != newDeviceId) {
    connections.remove(currentDeviceId);
  }

  final connection = DeviceConnection(
    id: newDeviceId,
    socket: socket,
    connectedAt: DateTime.now(),
  );
  connection.name = deviceData['name'];
  connection.platform = deviceData['platform'];

  connections[newDeviceId] = connection;
  updateDeviceId(newDeviceId);

  print('Registered device: ${connection.name} ($newDeviceId)');

  socket.add(jsonEncode({
    'type': 'ack_register',
    'success': true,
    'message': 'Registered successfully'
  }));
}

void _handleListDevices(
    WebSocket socket, Map<String, DeviceConnection> connections) {
  final devicesList = connections.values
      .map((conn) => {
            'id': conn.id,
            'name': conn.name,
            'platform': conn.platform,
            'lastSeen': conn.connectedAt.toIso8601String(),
            // We don't send IP/Port since relay handles routing, but client expects this structure
            // We can add a flag 'isRelayed': true
            'isRelayed': true,
          })
      .toList();

  socket.add(jsonEncode({
    'type': 'devices_list',
    'devices': devicesList,
  }));
}

void _handleRelay(
  WebSocket socket,
  Map<String, dynamic> message,
  Map<String, DeviceConnection> connections,
  String senderId,
) {
  final targetId = message['targetId'] as String;
  final payload = message['payload'];

  if (connections.containsKey(targetId)) {
    final targetSocket = connections[targetId]!.socket;

    targetSocket.add(jsonEncode({
      'type': 'relayed_message',
      'senderId': senderId,
      'payload': payload,
    }));
  } else {
    socket.add(jsonEncode({
      'type': 'error',
      'message': 'Target device not found',
      'targetId': targetId,
    }));
  }
}
