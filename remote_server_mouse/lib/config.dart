/// Configuration for the remote server
class Config {
  // Server Ports
  static const int websocketPort = 9090;
  static const String websocketHost = '0.0.0.0';

  static const int udpPort = 8988;
  static const int udpBroadcastPort = 8988;

  // Screen Capture Settings
  static const int defaultFps = 10;
  static const int minFps = 5;
  static const int maxFps = 30;
  static const int defaultMonitor = 0;
  static const bool captureAll = false;

  // Image Compression
  static const String defaultCodec = 'jpeg';
  static const int defaultQuality = 70;
  static const int minQuality = 40;
  static const int maxQuality = 90;

  // Codec-specific settings
  static const Map<String, dynamic> codecSettings = {
    'jpeg': {'quality': 70},
    'vp8': {'bitrate': '1M', 'quality': 'good'},
    'vp9': {'bitrate': '800k', 'quality': 'good'},
    'h264': {'bitrate': '1M', 'preset': 'ultrafast'},
  };

  // Performance
  static const bool adaptiveQuality = true;
  static const int maxClients = 5;
  static const int heartbeatInterval = 30000; // ms
  static const int connectionTimeout = 5000; // ms

  // Network monitoring
  static const bool networkMonitoringEnabled = true;
  static const int sampleInterval = 1000; // ms
  static const int latencyThresholdGood = 50; // ms
  static const int latencyThresholdFair = 150; // ms
  static const int latencyThresholdPoor = 300; // ms

  // Server Info
  static const String serverName = 'Screen Remote Server (Dart)';
  static const String serverVersion = '2.0.0';
  static const List<String> capabilities = [
    'screen_capture',
    'mouse_control',
    'keyboard_control',
    'multi_monitor',
    'multi_codec',
    'adaptive_streaming',
    'network_monitoring',
  ];

  static const List<String> availableCodecs = [
    'jpeg',
    // Video codecs would require additional implementation
    // 'vp8',
    // 'vp9',
    // 'h264',
  ];
}
