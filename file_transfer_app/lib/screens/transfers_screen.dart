import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/transfer_progress_card.dart';

/// Screen showing all transfers (active, completed, failed)
class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transfers'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active', icon: Icon(Icons.sync)),
              Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
              Tab(text: 'Failed', icon: Icon(Icons.error)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActiveTransfersTab(),
            _CompletedTransfersTab(),
            _FailedTransfersTab(),
          ],
        ),
      ),
    );
  }
}

class _ActiveTransfersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final activeTransfers = provider.activeTransfers;

        if (activeTransfers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No active transfers',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: activeTransfers.length,
          itemBuilder: (context, index) {
            final transfer = activeTransfers[index];
            return TransferProgressCard(
              transfer: transfer,
              onCancel: () {
                provider.cancelTransfer(transfer.id);
              },
            );
          },
        );
      },
    );
  }
}

class _CompletedTransfersTab extends StatefulWidget {
  @override
  State<_CompletedTransfersTab> createState() => _CompletedTransfersTabState();
}

class _CompletedTransfersTabState extends State<_CompletedTransfersTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return FutureBuilder(
          future: provider.getCompletedTransfers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final transfers = snapshot.data ?? [];

            if (transfers.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No completed transfers',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: transfers.length,
              itemBuilder: (context, index) {
                return TransferProgressCard(transfer: transfers[index]);
              },
            );
          },
        );
      },
    );
  }
}

class _FailedTransfersTab extends StatefulWidget {
  @override
  State<_FailedTransfersTab> createState() => _FailedTransfersTabState();
}

class _FailedTransfersTabState extends State<_FailedTransfersTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return FutureBuilder(
          future: provider.getFailedTransfers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final transfers = snapshot.data ?? [];

            if (transfers.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sentiment_satisfied,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No failed transfers',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: transfers.length,
              itemBuilder: (context, index) {
                return TransferProgressCard(transfer: transfers[index]);
              },
            );
          },
        );
      },
    );
  }
}
