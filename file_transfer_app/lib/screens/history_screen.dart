import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/file_utils.dart';

/// Screen showing transfer history
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showClearHistoryDialog,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Card
          _buildStatisticsCard(),

          // Search Bar
          _buildSearchBar(),

          // History List
          Expanded(child: _buildHistoryList()),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final stats = provider.statistics;
        final total = stats['total'] ?? 0;
        final completed = stats['completed'] ?? 0;
        final failed = stats['failed'] ?? 0;
        final totalBytes = stats['totalBytes'] ?? 0;
        final successRate = stats['successRate'] ?? 0.0;

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', total.toString(), Icons.sync_alt),
                    _buildStatItem(
                      'Success',
                      completed.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                    _buildStatItem(
                      'Failed',
                      failed.toString(),
                      Icons.error,
                      Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Transferred',
                      FileUtils.formatFileSize(totalBytes),
                      Icons.cloud_upload,
                    ),
                    _buildStatItem(
                      'Success Rate',
                      '${successRate.toStringAsFixed(1)}%',
                      Icons.trending_up,
                      successRate > 90 ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search files...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (_searchQuery.isNotEmpty) {
          return FutureBuilder(
            future: provider.searchTransfers(_searchQuery),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final transfers = snapshot.data ?? [];
              return _buildList(transfers);
            },
          );
        }

        final transfers = provider.transferHistory;
        return _buildList(transfers);
      },
    );
  }

  Widget _buildList(List transfers) {
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No transfer history' : 'No results found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: Text(
              FileUtils.getFileIcon(transfer.fileName),
              style: const TextStyle(fontSize: 32),
            ),
            title: Text(
              transfer.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${FileUtils.formatFileSize(transfer.fileSize)} • ${FileUtils.formatDateTime(transfer.startTime)}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (transfer.sender != null || transfer.receiver != null)
                  Text(
                    transfer.sender != null
                        ? 'From: ${transfer.sender?.name}'
                        : 'To: ${transfer.receiver?.name}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            trailing: _buildStatusBadge(transfer.status.name),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'failed':
      case 'cancelled':
        color = Colors.red;
        icon = Icons.error;
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
    }

    return Icon(icon, color: color, size: 24);
  }

  Future<void> _showClearHistoryDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear all transfer history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AppProvider>().clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
