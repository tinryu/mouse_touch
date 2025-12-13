import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'config.dart';

/// UDP discovery server
class UdpDiscovery {
  static RawDatagramSocket? _socket;

  /// Start UDP discovery server
  static Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        Config.udpPort,
      );

      print('📡 UDP Discovery server listening on 0.0.0.0:${Config.udpPort}');

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleMessage(datagram);
          }
        }
      });
    } catch (e) {
      print('UDP server error: $e');
    }
  }

  /// Handle incoming UDP messages
  static Future<void> _handleMessage(Datagram datagram) async {
    try {
      final message = utf8.decode(datagram.data);
      final request = jsonDecode(message);

      if (request['type'] == 'discover') {
        print(
          '📡 Discovery request from ${datagram.address.address}:${datagram.port}',
        );

        final ip = await _getLocalIP();

        final response = jsonEncode({
          'type': 'server_info',
          'service': 'screen_remote',
          'ip': ip,
          'hostname': Platform.localHostname,
          'port': Config.websocketPort,
          'version': Config.serverVersion,
          'capabilities': Config.capabilities,
        });

        _socket!.send(utf8.encode(response), datagram.address, datagram.port);

        print(
          '✓ Sent discovery response to ${datagram.address.address}:${datagram.port}',
        );
      }
    } catch (e) {
      print('Error processing UDP message: $e');
    }
  }

  /// Get local IP address
  static Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      // 1. Prioritize Physical Interfaces (Wi-Fi, Ethernet) vs Virtual/VPN
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        // Ignore known virtual/VPN adapters
        if (name.contains('virtual') ||
            name.contains('vpn') ||
            name.contains('radmin') ||
            name.contains('vmware') ||
            name.contains('wsl') ||
            name.contains('hyper-v') ||
            name.contains('pseudo')) {
          continue;
        }

        // Prioritize Wi-Fi or Ethernet explicitly
        if (name.contains('wi-fi') ||
            name.contains('ethernet') ||
            name.contains('wlan') ||
            name.contains('eth')) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback) {
              print('  - Found candidate IP: ${addr.address} on $name');
              return addr.address;
            }
          }
        }
      }

      // 2. Fallback: Accept any non-virtual if specifically named ones weren't found
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('virtual') ||
            name.contains('vpn') ||
            name.contains('radmin') ||
            name.contains('vmware')) {
          continue;
        }
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }

      // 3. Last Resort: Just take the first valid one we found originally (skipping loopback)
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return '127.0.0.1';
  }

  /// Stop UDP server
  static void stop() {
    _socket?.close();
    print('UDP Discovery server stopped');
  }
}
