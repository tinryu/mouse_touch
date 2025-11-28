import 'dart:io';
import 'dart:async';

class Helper {
  static Future<String> getLocalIPv4() async {
    try {
      // List all network interfaces
      List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, // Filter for IPv4 only
        includeLoopback: false, // Exclude 127.0.0.1
        includeLinkLocal: false, // Exclude link-local addresses
      );

      // Iterate through interfaces and find the first valid IPv4
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        // Skip virtual adapters (VirtualBox, VMware, Hyper-V, etc.)
        if (name.contains('virtualbox') ||
            name.contains('vmware') ||
            name.contains('hyper-v') ||
            name.contains('vethernet') ||
            name.contains('vboxnet') ||
            name.contains('radmin') ||
            name.contains('vpn') ||
            name.contains('docker')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address; // e.g., "192.168.1.100"
          }
        }
      }
      throw Exception('No IPv4 found');
    } catch (e) {
      throw Exception('Error getting IP: $e');
    }
  }
}
