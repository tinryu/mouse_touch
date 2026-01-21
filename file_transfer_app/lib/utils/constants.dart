/// Application-wide constants
class AppConstants {
  // Network Configuration
  static const int httpPort = 8080;
  static const int udpDiscoveryPort = 8988;
  static const String discoveryMessage = 'FILE_TRANSFER_DISCOVERY';
  static const String discoveryResponse = 'FILE_TRANSFER_RESPONSE';

  // Transfer Configuration
  static const int chunkSize = 10 * 1024 * 1024; // 10MB chunks
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration transferTimeout = Duration(minutes: 5);
  static const Duration discoveryInterval = Duration(seconds: 2);
  static const Duration discoveryTimeout = Duration(seconds: 1);

  // Database
  static const String dbName = 'file_transfer.db';
  static const int dbVersion = 1;

  // Encryption
  static const int rsaKeySize = 2048;
  static const String aesMode = 'AES/CBC/PKCS7';

  // Storage
  static const String receivedFilesFolder = 'FileTransfer/Received';
  static const String tempFolder = 'FileTransfer/Temp';

  // UI
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const int maxDeviceNameLength = 30;
}

/// HTTP API endpoints
class ApiEndpoints {
  static const String ping = '/ping';
  static const String handshake = '/handshake';
  static const String upload = '/upload';
  static const String uploadChunk = '/upload-chunk';
  static const String uploadComplete = '/upload-complete';
}

/// Transfer statuses
enum TransferStatus {
  pending,
  connecting,
  active,
  paused,
  completed,
  failed,
  cancelled,
}

/// Connection modes
enum ConnectionMode { localNetwork, internet, auto }

/// Device platforms
enum DevicePlatform { android, windows, macos, linux, unknown }
