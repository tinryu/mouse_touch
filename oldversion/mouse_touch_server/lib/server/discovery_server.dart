import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';

class DiscoveryServer {
  RawDatagramSocket? _socket;
  final String serverIP;
  final int serverPort;
  final Function(String)? onLog;

  DiscoveryServer({
    required this.serverIP,
    required this.serverPort,
    this.onLog,
  });

  Future<void> start({int discoveryPort = 8988}) async {
    try {
      // Bind to the discovery port
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );

      _log('✓ Discovery server started on port $discoveryPort');

      // Enable broadcast
      _socket!.broadcastEnabled = true;

      // Listen for discovery requests
      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleDiscoveryRequest(datagram);
          }
        }
      });
    } catch (e) {
      _log('✗ Discovery server error: $e');
      rethrow;
    }
  }

  void _handleDiscoveryRequest(Datagram datagram) {
    try {
      final message = String.fromCharCodes(datagram.data);
      final data = jsonDecode(message);

      if (data['type'] == 'discover') {
        _log('📡 Discovery request from ${datagram.address.address}');

        // Get hostname
        final hostname = Platform.localHostname;

        // Send response back to the requester
        final response = jsonEncode({
          'type': 'server_info',
          'ip': serverIP,
          'port': serverPort,
          'hostname': hostname,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        _socket!.send(response.codeUnits, datagram.address, datagram.port);

        _log(
          '📡 Sent server info to ${datagram.address.address}:${datagram.port}',
        );
      }
    } catch (e) {
      _log('✗ Error handling discovery request: $e');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[Discovery] $message');
    }
    onLog?.call(message);
  }

  Future<void> stop() async {
    _socket?.close();
    _log('✓ Discovery server stopped');
  }

  bool get isRunning => _socket != null;
}
