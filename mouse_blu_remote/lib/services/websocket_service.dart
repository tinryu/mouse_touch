import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/mouse_event.dart';

enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class WebSocketService {
  WebSocketChannel? _channel;
  WebSocketConnectionStatus _status = WebSocketConnectionStatus.disconnected;
  String? _errorMessage;

  final _statusController = StreamController<WebSocketConnectionStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  Stream<WebSocketConnectionStatus> get statusStream => _statusController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<String> get messageStream => _messageController.stream;
  WebSocketConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// Connect to WebSocket server
  Future<bool> connect(String host, int port) async {
    if (_status == WebSocketConnectionStatus.connected) {
      await disconnect();
    }

    _setStatus(WebSocketConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://$host:$port');
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to establish
      await _channel!.ready;
      _setStatus(WebSocketConnectionStatus.connected);

      // Listen for messages from server
      _channel!.stream.listen(
        (message) {
          try {
            final data = message is String ? message : utf8.decode(message as List<int>);
            _messageController.add(data);
            print('Received from server: $data');
          } catch (e) {
            print('Failed to decode message: $e');
          }
        },
        onDone: () {
          _setStatus(WebSocketConnectionStatus.disconnected);
        },
        onError: (error) {
          _setError('WebSocket error: $error');
          _setStatus(WebSocketConnectionStatus.error);
        },
        cancelOnError: true,
      );

      return true;
    } catch (e) {
      _setError('Failed to connect: $e');
      _setStatus(WebSocketConnectionStatus.error);
      return false;
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
      _channel = null;
      _setStatus(WebSocketConnectionStatus.disconnected);
    } catch (e) {
      _setError('Failed to disconnect: $e');
    }
  }

  /// Send a mouse event to the server
  Future<bool> sendMouseEvent(MouseEvent event) async {
    if (_channel == null) {
      _setError('Not connected to server');
      return false;
    }

    try {
      final jsonString = event.toJsonString();
      _channel!.sink.add(jsonString);
      return true;
    } catch (e) {
      _setError('Failed to send event: $e');
      return false;
    }
  }

  void _setStatus(WebSocketConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void _setError(String error) {
    _errorMessage = error;
    _errorController.add(error);
    print('WebSocketService Error: $error');
  }

  void dispose() {
    _channel?.sink.close();
    _statusController.close();
    _errorController.close();
    _messageController.close();
  }
}
