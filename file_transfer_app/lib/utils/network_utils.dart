import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

/// Network utility functions
class NetworkUtils {
  /// Get the local IP address, prioritizing WiFi/Ethernet over VPN
  static Future<String?> getLocalIPAddress() async {
    try {
      final info = NetworkInfo();

      // Try to get WiFi IP first
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '0.0.0.0') {
        return wifiIP;
      }

      // Fallback: Get all network interfaces and prioritize physical adapters
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Prioritize non-virtual interfaces
      for (var interface in interfaces) {
        // Skip loopback, docker, virtual, VPN interfaces
        final name = interface.name.toLowerCase();
        if (name.contains('lo') ||
            name.contains('docker') ||
            name.contains('veth') ||
            name.contains('vmnet') ||
            name.contains('virtualbox')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254.')) {
            // Skip link-local
            return addr.address;
          }
        }
      }

      // Last resort: return any IPv4 address
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return null;
  }

  /// Check if network is available
  static Future<bool> isNetworkAvailable() async {
    try {
      final ip = await getLocalIPAddress();
      return ip != null;
    } catch (e) {
      return false;
    }
  }

  /// Validate IP address format
  static bool isValidIPAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (var part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  /// Get broadcast address for the local network
  static String? getBroadcastAddress(String? ipAddress) {
    if (ipAddress == null || !isValidIPAddress(ipAddress)) return null;

    final parts = ipAddress.split('.');
    // Assume /24 subnet (255.255.255.0)
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }

  /// Check if port is available
  static Future<bool> isPortAvailable(int port) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await server.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
