import 'package:flutter/material.dart';
import '../models/transfer_model.dart';
import '../utils/file_utils.dart';
import '../utils/constants.dart';

/// Widget to display transfer progress
class TransferProgressCard extends StatelessWidget {
  final Transfer transfer;
  final VoidCallback? onCancel;

  const TransferProgressCard({
    super.key,
    required this.transfer,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info row
            Row(
              children: [
                Text(
                  FileUtils.getFileIcon(transfer.fileName),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FileUtils.formatFileSize(transfer.fileSize),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            if (transfer.isActive) ...[
              LinearProgressIndicator(
                value: transfer.progressPercentage / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),

              // Progress details
              Row(
                children: [
                  Text(
                    '${transfer.progressPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    FileUtils.formatSpeed(transfer.speed),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  if (transfer.speed > 0)
                    Text(
                      'ETA: ${FileUtils.formatETA(transfer.remainingBytes, transfer.speed)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],

            // Device info
            if (transfer.sender != null || transfer.receiver != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (transfer.sender != null) ...[
                    Icon(Icons.upload, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'From: ${transfer.sender!.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (transfer.receiver != null) ...[
                    if (transfer.sender != null) const SizedBox(width: 12),
                    Icon(Icons.download, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'To: ${transfer.receiver!.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Error message
            if (transfer.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${transfer.errorMessage}',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],

            // Cancel button for active transfers
            if (transfer.isActive && onCancel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (transfer.status) {
      case TransferStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 32);
      case TransferStatus.failed:
      case TransferStatus.cancelled:
        return const Icon(Icons.error, color: Colors.red, size: 32);
      case TransferStatus.active:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default:
        return const Icon(Icons.pending, color: Colors.orange, size: 32);
    }
  }
}
