import 'package:flutter/material.dart';
import '../models/device_model.dart';

/// Widget to display a discovered device
class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final bool showLastSeen;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.showLastSeen = true,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = device.isActive();

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? Colors.green.shade100
              : Colors.grey.shade300,
          child: Text(
            device.getPlatformIcon(),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.wifi, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  device.ipAddress,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (showLastSeen)
              Text(
                isActive ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.green : Colors.grey,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.send,
          color: isActive ? Theme.of(context).primaryColor : Colors.grey,
        ),
        onTap: isActive ? onTap : null,
      ),
    );
  }
}
