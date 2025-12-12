import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'mouse_controller.dart';
import 'screen_capture.dart';

/// Client data
class ClientData {
  final String id;
  final String ip;
  bool streaming = false;
  int fps = Config.defaultFps;
  int quality = Config.defaultQuality;
  String codec = Config.defaultCodec;
  int monitor = Config.defaultMonitor;
  int frameCount = 0;
  int totalBytes = 0;
  Timer? streamTimer;
  DateTime? lastFrameTime;
  List<int> latencies = [];
  double avgLatency = 0.0;

  ClientData({required this.id, required this.ip});
}

/// WebSocket handler
class WebSocketHandler {
  static final Map<WebSocketChannel, ClientData> _clients = {};
  static Map<String, dynamic>? _screenInfo;

  /// Initialize screen info
  static Future<void> initialize() async {
    _screenInfo = await ScreenCapture.getScreenInfo();
  }

  /// Create WebSocket handler
  static Handler createHandler() {
    return webSocketHandler((WebSocketChannel webSocket) {
      final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}';
      final clientData = ClientData(id: clientId, ip: 'unknown');

      _clients[webSocket] = clientData;
      print('✓ Client connected: $clientId');

      // Send welcome message
      webSocket.sink.add(
        jsonEncode({
          'type': 'connected',
          'message':
              'Welcome to Screen Remote Server (Dart) v${Config.serverVersion}',
          'server': {
            'name': Config.serverName,
            'version': Config.serverVersion,
            'capabilities': Config.capabilities,
          },
          'clientId': clientId,
          'availableCodecs': Config.availableCodecs,
        }),
      );

      // Send screen info
      if (_screenInfo != null) {
        webSocket.sink.add(
          jsonEncode({'type': 'screen_info', ..._screenInfo!}),
        );
      }

      // Heartbeat timer
      final heartbeat = Timer.periodic(
        Duration(milliseconds: Config.heartbeatInterval),
        (_) {
          if (!webSocket.closeCode!.isNaN) return;
          webSocket.sink.add(
            jsonEncode({
              'type': 'heartbeat',
              'networkQuality': _calculateNetworkQuality(clientData),
              'avgLatency': clientData.avgLatency,
            }),
          );
        },
      );

      // Message handler
      webSocket.stream.listen(
        (message) => _handleMessage(webSocket, clientData, message),
        onDone: () => _handleDisconnect(webSocket, clientData, heartbeat),
        onError: (error) => print('WebSocket error for $clientId: $error'),
      );
    });
  }

  /// Handle incoming messages
  static void _handleMessage(
    WebSocketChannel webSocket,
    ClientData clientData,
    dynamic message,
  ) {
    try {
      final msg = jsonDecode(message as String);

      switch (msg['type']) {
        case 'start_stream':
          _startStream(webSocket, clientData, msg);
          break;

        case 'stop_stream':
          _stopStream(clientData);
          break;

        case 'update_settings':
          _updateSettings(clientData, msg);
          break;

        case 'mouse':
          MouseController.handleMouseControl(msg['data']);
          break;

        case 'keyboard':
          MouseController.handleKeyboardControl(msg['data']);
          break;

        case 'get_screen_info':
          if (_screenInfo != null) {
            webSocket.sink.add(
              jsonEncode({'type': 'screen_info', ..._screenInfo!}),
            );
          }
          break;

        case 'ping':
          webSocket.sink.add(
            jsonEncode({'type': 'pong', 'timestamp': msg['timestamp']}),
          );
          break;
      }
    } catch (e) {
      print('Error processing message: $e');
    }
  }

  /// Start streaming
  static void _startStream(
    WebSocketChannel webSocket,
    ClientData clientData,
    Map<String, dynamic> msg,
  ) {
    print('▶️  Starting stream for client ${clientData.id}');
    clientData.streaming = true;
    clientData.fps = msg['fps'] ?? Config.defaultFps;
    clientData.quality = msg['quality'] ?? Config.defaultQuality;
    clientData.codec = msg['codec'] ?? Config.defaultCodec;
    clientData.monitor = msg['monitor'] ?? Config.defaultMonitor;

    print(
      '   Codec: ${clientData.codec}, Quality: ${clientData.quality}, FPS: ${clientData.fps}',
    );

    _streamToClient(webSocket, clientData);
  }

  /// Stop streaming
  static void _stopStream(ClientData clientData) {
    print('⏹️  Stopping stream for client ${clientData.id}');
    clientData.streaming = false;
    clientData.streamTimer?.cancel();
    clientData.streamTimer = null;
  }

  /// Update settings
  static void _updateSettings(ClientData clientData, Map<String, dynamic> msg) {
    if (msg['fps'] != null) {
      clientData.fps = (msg['fps'] as int).clamp(Config.minFps, Config.maxFps);
    }
    if (msg['quality'] != null) {
      clientData.quality = msg['quality'];
    }
    if (msg['codec'] != null) {
      clientData.codec = msg['codec'];
    }
    if (msg['monitor'] != null) {
      clientData.monitor = msg['monitor'];
    }
    print('⚙️  Updated settings for client ${clientData.id}');
  }

  /// Stream frames to client
  static void _streamToClient(
    WebSocketChannel webSocket,
    ClientData clientData,
  ) async {
    if (!clientData.streaming) return;

    final startTime = DateTime.now();

    try {
      final frame = await ScreenCapture.captureScreen(
        monitorId: clientData.monitor,
        quality: clientData.quality,
      );

      if (frame != null) {
        // Send frame metadata
        final metadata = jsonEncode({
          'type': 'frame_meta',
          'width': frame['width'],
          'height': frame['height'],
          'size': frame['size'],
          'codec': frame['codec'],
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'quality': clientData.quality,
          'fps': clientData.fps,
          'networkQuality': _calculateNetworkQuality(clientData),
        });

        webSocket.sink.add(metadata);

        // Send frame data
        webSocket.sink.add(frame['buffer']);

        // Update stats
        clientData.frameCount++;
        clientData.totalBytes += frame['size'] as int;

        // Update network stats
        if (clientData.lastFrameTime != null) {
          final latency = DateTime.now()
              .difference(clientData.lastFrameTime!)
              .inMilliseconds;
          clientData.latencies.add(latency);

          // Keep only last 30 samples
          if (clientData.latencies.length > 30) {
            clientData.latencies.removeAt(0);
          }

          // Calculate average latency
          clientData.avgLatency =
              clientData.latencies.reduce((a, b) => a + b) /
              clientData.latencies.length;
        }
        clientData.lastFrameTime = DateTime.now();

        // Log stats periodically
        if (clientData.frameCount % 30 == 0) {
          final avgSize = (clientData.totalBytes / clientData.frameCount / 1024)
              .toStringAsFixed(2);
          final quality = _calculateNetworkQuality(clientData);
          print(
            '📊 Client ${clientData.id}: ${clientData.frameCount} frames, avg $avgSize KB/frame, quality: $quality, latency: ${clientData.avgLatency.toStringAsFixed(0)}ms',
          );
        }
      }
    } catch (e) {
      print('Streaming error: $e');
    }

    // Schedule next frame
    if (clientData.streaming) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final delay = ((1000 / clientData.fps) - elapsed).clamp(0, 1000).toInt();

      clientData.streamTimer = Timer(Duration(milliseconds: delay), () {
        _streamToClient(webSocket, clientData);
      });
    }
  }

  /// Calculate network quality
  static String _calculateNetworkQuality(ClientData clientData) {
    if (!Config.networkMonitoringEnabled) return 'unknown';

    final avgLatency = clientData.avgLatency;

    if (avgLatency < Config.latencyThresholdGood) return 'excellent';
    if (avgLatency < Config.latencyThresholdFair) return 'good';
    if (avgLatency < Config.latencyThresholdPoor) return 'fair';
    return 'poor';
  }

  /// Handle client disconnect
  static void _handleDisconnect(
    WebSocketChannel webSocket,
    ClientData clientData,
    Timer heartbeat,
  ) {
    print('✗ Client disconnected: ${clientData.id}');

    clientData.streaming = false;
    clientData.streamTimer?.cancel();
    heartbeat.cancel();
    _clients.remove(webSocket);
  }

  /// Get active clients count
  static int get activeClients => _clients.length;
}
