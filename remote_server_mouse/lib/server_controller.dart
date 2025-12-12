import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'config.dart';
import 'screen_capture.dart';
import 'udp_discovery.dart';
import 'websocket_handler.dart';

/// Controller that manages the remote server lifecycle and shares runtime data
/// with both the CLI entrypoint and the Flutter desktop UI.
class RemoteServerController {
  RemoteServerController({void Function(String message)? onLog})
    : _externalLogger = onLog;

  HttpServer? _server;
  bool _isRunning = false;
  String _serverIp = '0.0.0.0';
  String _hostname = '';
  Map<String, dynamic>? _screenInfo;

  final void Function(String message)? _externalLogger;
  final StreamController<String> _logStreamController =
      StreamController<String>.broadcast();

  /// Listen to log updates.
  Stream<String> get logStream => _logStreamController.stream;

  bool get isRunning => _isRunning;
  String get serverIp => _serverIp;
  String get hostname => _hostname;
  int get websocketPort => Config.websocketPort;
  int get udpPort => Config.udpPort;
  List<String> get capabilities => Config.capabilities;
  List<String> get availableCodecs => Config.availableCodecs;
  Map<String, dynamic>? get screenInfo => _screenInfo;

  /// Current connected clients as reported by the WebSocket handler.
  int get activeClients => WebSocketHandler.activeClients;

  Future<void> initialize() async {
    _log('🚀 Initializing ${Config.serverName} v${Config.serverVersion}');
    _hostname = Platform.localHostname;
    _serverIp = await _getLocalIP();
    await WebSocketHandler.initialize();
    _screenInfo = await ScreenCapture.getScreenInfo();

    if (_screenInfo != null) {
      final monitors = _screenInfo!['monitors'] as List<dynamic>? ?? [];
      _log('📺 Detected ${monitors.length} monitor(s)');
      for (final monitor in monitors) {
        _log(
          '   - ${monitor['name']}: '
          '${monitor['width']}x${monitor['height']}'
          '${monitor['primary'] == true ? ' (Primary)' : ''}',
        );
      }
    }

    _log(
      '🎥 Available codecs: ${availableCodecs.map((c) => c.toUpperCase()).join(', ')}',
    );
    _log('✨ Features:');
    for (final capability in Config.capabilities) {
      _log('   ✓ ${capability.replaceAll('_', ' ')}');
    }
  }

  /// Start the WebSocket and UDP discovery servers.
  Future<void> start() async {
    if (_isRunning) {
      _log('⚠️  Server already running.');
      return;
    }

    _log('⏳ Starting server on ws://$_serverIp:${Config.websocketPort}');

    await UdpDiscovery.start();

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(WebSocketHandler.createHandler());

    _server = await shelf_io.serve(
      handler,
      Config.websocketHost,
      Config.websocketPort,
    );

    _isRunning = true;
    _log('✓ Server ready! Listening for connections...');
  }

  /// Stop the WebSocket server and UDP discovery.
  Future<void> stop() async {
    if (!_isRunning) {
      _log('⚠️  Server is not running.');
      return;
    }

    _log('🛑 Stopping server...');
    UdpDiscovery.stop();
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _log('✓ Server stopped.');
  }

  /// Refreshes the cached network information.
  Future<void> refreshNetworkInfo() async {
    _hostname = Platform.localHostname;
    _serverIp = await _getLocalIP();
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await stop();
    await _logStreamController.close();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(
      11,
      19,
    ); // HH:MM:SS
    final formatted = '[$timestamp] $message';
    _externalLogger?.call(formatted);
    _logStreamController.add(formatted);
    // Mirror to stdout for CLI usage as well.
    stdout.writeln(formatted);
  }

  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String fallback = '127.0.0.1';

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (_isVirtualInterface(name)) continue;

        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;
            if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
              return ip;
            }
            fallback = ip;
          }
        }
      }

      return fallback;
    } catch (e) {
      _log('Error determining local IP: $e');
      return '127.0.0.1';
    }
  }

  bool _isVirtualInterface(String name) {
    return name.contains('virtualbox') ||
        name.contains('vmware') ||
        name.contains('hyper-v') ||
        name.contains('vethernet') ||
        name.contains('vboxnet') ||
        name.contains('radmin') ||
        name.contains('vpn') ||
        name.contains('docker') ||
        name.contains('tun') ||
        name.contains('tap');
  }
}
