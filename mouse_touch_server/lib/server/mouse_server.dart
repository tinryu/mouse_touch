import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'win32_mouse_controller.dart';

class MouseServer {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  Timer? _heartbeatTimer;
  final Function(String)? onLog;

  MouseServer({this.onLog});

  Future<void> start({String host = '0.0.0.0', int port = 8989}) async {
    try {
      _server = await HttpServer.bind(host, port);
      _log('✓ Server started on $host:$port');

      // Start heartbeat timer
      _startHeartbeat();

      // Listen for connections
      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((WebSocket socket) {
            _handleClient(socket);
          });
        } else {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..write('WebSocket connections only')
            ..close();
        }
      });
    } catch (e) {
      _log('✗ Server error: $e');
      rethrow;
    }
  }

  void _handleClient(WebSocket socket) {
    _clients.add(socket);
    final clientId = socket.hashCode;
    _log('✓ Client connected: $clientId (Total: ${_clients.length})');

    // Send welcome message
    _sendToClient(socket, {
      'type': 'welcome',
      'message': 'Welcome to Touchpad Server',
    });

    // Listen to client messages
    socket.listen(
      (dynamic message) {
        try {
          final data = jsonDecode(message as String);
          _handleMessage(socket, data);
        } catch (e) {
          _log('✗ Error parsing message: $e');
        }
      },
      onDone: () {
        _clients.remove(socket);
        _log('✗ Client disconnected: $clientId (Total: ${_clients.length})');
      },
      onError: (error) {
        _log('✗ Client error: $error');
        _clients.remove(socket);
      },
    );
  }

  void _handleMessage(WebSocket socket, Map<String, dynamic> data) {
    final type = data['type'];
    _log('← Received: $type');

    switch (type) {
      case 'move':
        final dx = (data['dx'] as num).toDouble();
        final dy = (data['dy'] as num).toDouble();
        Win32MouseController.moveMouse(dx, dy);
        break;

      case 'click':
        final button = data['button'] as String;
        Win32MouseController.click(button);
        break;

      case 'scroll':
        final dx = (data['dx'] as num?)?.toDouble() ?? 0;
        final dy = (data['dy'] as num?)?.toDouble() ?? 0;
        Win32MouseController.scroll(dx, dy);
        break;

      case 'zoom':
        final delta = (data['delta'] as num).toDouble();
        Win32MouseController.zoom(delta);
        break;

      case 'ping':
        _sendToClient(socket, {'type': 'pong'});
        break;

      default:
        _log('⚠ Unknown message type: $type');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _broadcast({'type': 'heartbeat'});
    });
  }

  void _sendToClient(WebSocket socket, Map<String, dynamic> data) {
    try {
      socket.add(jsonEncode(data));
    } catch (e) {
      _log('✗ Error sending to client: $e');
    }
  }

  void _broadcast(Map<String, dynamic> data) {
    final message = jsonEncode(data);
    for (final client in List.from(_clients)) {
      try {
        client.add(message);
      } catch (e) {
        _log('✗ Error broadcasting: $e');
        _clients.remove(client);
      }
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[Server] $message');
    }
    onLog?.call(message);
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    await _server?.close();
    _log('✓ Server stopped');
  }

  int get clientCount => _clients.length;
  bool get isRunning => _server != null;
}
