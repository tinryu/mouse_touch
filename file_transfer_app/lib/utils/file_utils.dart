import 'dart:io';
import 'package:intl/intl.dart';

/// File utility functions
class FileUtils {
  /// Format file size in human-readable format
  static String formatFileSize(int bytes) {
    if (bytes < 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;

    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }

    if (suffixIndex == 0) {
      return '${size.toInt()} ${suffixes[suffixIndex]}';
    }

    return '${size.toStringAsFixed(2)} ${suffixes[suffixIndex]}';
  }

  /// Format transfer speed
  static String formatSpeed(double bytesPerSecond) {
    return '${formatFileSize(bytesPerSecond.toInt())}/s';
  }

  /// Calculate ETA in human-readable format
  static String formatETA(int remainingBytes, double bytesPerSecond) {
    if (bytesPerSecond <= 0) return 'Calculating...';

    final seconds = (remainingBytes / bytesPerSecond).ceil();

    if (seconds < 60) {
      return '$seconds sec';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).ceil();
      return '$minutes min';
    } else {
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).ceil();
      return '${hours}h ${minutes}m';
    }
  }

  /// Get file extension
  static String getFileExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1 || lastDot == fileName.length - 1) {
      return '';
    }
    return fileName.substring(lastDot + 1).toLowerCase();
  }

  /// Get file icon based on extension
  static String getFileIcon(String fileName) {
    final ext = getFileExtension(fileName);

    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(ext)) {
      return '🖼️';
    }
    // Videos
    if (['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm'].contains(ext)) {
      return '🎬';
    }
    // Audio
    if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(ext)) {
      return '🎵';
    }
    // Documents
    if (['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt'].contains(ext)) {
      return '📄';
    }
    // Spreadsheets
    if (['xls', 'xlsx', 'csv', 'ods'].contains(ext)) {
      return '📊';
    }
    // Archives
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].contains(ext)) {
      return '📦';
    }
    // Code
    if ([
      'dart',
      'java',
      'py',
      'js',
      'cpp',
      'c',
      'h',
      'html',
      'css',
    ].contains(ext)) {
      return '💻';
    }
    // APK
    if (ext == 'apk') {
      return '📱';
    }

    return '📎'; // Default
  }

  /// Create safe filename (remove invalid characters)
  static String getSafeFileName(String fileName) {
    // Remove invalid characters for Windows/Unix filesystems
    var safe = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    // Remove leading/trailing spaces and dots
    safe = safe.trim().replaceAll(RegExp(r'^\.+|\.+$'), '');

    // Limit length
    if (safe.length > 255) {
      final ext = getFileExtension(safe);
      final nameWithoutExt = safe.substring(0, safe.length - ext.length - 1);
      safe = '${nameWithoutExt.substring(0, 250)}.$ext';
    }

    return safe.isEmpty ? 'unnamed_file' : safe;
  }

  /// Check if file exists and get unique name if needed
  static Future<String> getUniqueFileName(
    String directoryPath,
    String fileName,
  ) async {
    var file = File('$directoryPath/$fileName');

    if (!await file.exists()) {
      return fileName;
    }

    // File exists, add counter
    final ext = getFileExtension(fileName);
    final nameWithoutExt = ext.isEmpty
        ? fileName
        : fileName.substring(0, fileName.length - ext.length - 1);

    var counter = 1;
    while (await file.exists()) {
      fileName = ext.isEmpty
          ? '${nameWithoutExt}_$counter'
          : '${nameWithoutExt}_$counter.$ext';
      file = File('$directoryPath/$fileName');
      counter++;
    }

    return fileName;
  }

  /// Format date/time
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today
      return 'Today ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      // This week
      return DateFormat('EEEE HH:mm').format(dateTime);
    } else {
      // Older
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    }
  }

  /// Delete file safely
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
}
