import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import '../widgets/device_card.dart';
import '../widgets/transfer_progress_card.dart';
import 'transfers_screen.dart';
import 'history_screen.dart';

/// Home screen showing discovered devices and active transfers
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Transfer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AppProvider>().refreshDevices();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              provider.refreshDevices();
              await Future.delayed(const Duration(seconds: 1));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Own device info
                  _buildOwnDeviceCard(provider),

                  // Connection Mode
                  _buildConnectionModeSelector(context, provider),
                  const SizedBox(height: 16),

                  // Active transfers
                  if (provider.activeTransfers.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Active Transfers',
                      onViewAll: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TransfersScreen(),
                          ),
                        );
                      },
                    ),
                    ...provider.activeTransfers.map((transfer) {
                      return TransferProgressCard(
                        transfer: transfer,
                        onCancel: () {
                          provider.cancelTransfer(transfer.id);
                        },
                      );
                    }),
                  ],

                  // Discovered devices
                  _buildSectionHeader('Nearby Devices'),
                  if (provider.devices.isEmpty)
                    _buildEmptyState()
                  else
                    ...provider.devices.map((device) {
                      return DeviceCard(
                        device: device,
                        onTap: () => _handleSendFile(context, device),
                      );
                    }),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleBroadcastFile(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Send File'),
      ),
    );
  }

  Widget _buildOwnDeviceCard(AppProvider provider) {
    final ownDevice = provider.ownDevice;
    if (ownDevice == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              radius: 30,
              child: Text(
                ownDevice.getPlatformIcon(),
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This Device',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ownDevice.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.wifi, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        ownDevice.ipAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ONLINE',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (onViewAll != null) ...[
            const Spacer(),
            TextButton(onPressed: onViewAll, child: const Text('View All')),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.devices, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure other devices are on the same WiFi network',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendFile(BuildContext context, device) async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;

      try {
        await context.read<AppProvider>().sendFile(
          filePath: filePath,
          receiver: device,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sending ${result.files.single.name} to ${device.name}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildConnectionModeSelector(
    BuildContext context,
    AppProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<ConnectionMode>(
        segments: const [
          ButtonSegment<ConnectionMode>(
            value: ConnectionMode.localNetwork,
            label: Text('Local'),
            icon: Icon(Icons.wifi),
          ),
          ButtonSegment<ConnectionMode>(
            value: ConnectionMode.internet,
            label: Text('Internet'),
            icon: Icon(Icons.cloud),
          ),
        ],
        selected: {provider.connectionMode},
        onSelectionChanged: (Set<ConnectionMode> newSelection) {
          final mode = newSelection.first;
          provider.setConnectionMode(mode);

          if (mode == ConnectionMode.internet && !provider.isRelayConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connecting to relay server...')),
            );
          }
        },
      ),
    );
  }

  Future<void> _handleBroadcastFile(BuildContext context) async {
    final devices = context.read<AppProvider>().devices;

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No devices available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show device selection dialog
    final selectedDevice = await showDialog<dynamic>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Device'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: Text(
                  device.getPlatformIcon(),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(device.name),
                subtitle: Text(device.ipAddress),
                onTap: () => Navigator.pop(context, device),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedDevice != null) {
      await _handleSendFile(context, selectedDevice);
    }
  }
}
