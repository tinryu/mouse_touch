/**
 * Configuration for Screen Remote Server
 */

module.exports = {
  // Server Ports
  websocket: {
    port: 9090,
    host: '0.0.0.0'
  },
  
  udp: {
    port: 9091,
    broadcastPort: 9091
  },

  // Screen Capture Settings
  capture: {
    fps: 10,                    // Frames per second (default)
    minFps: 5,                  // Minimum FPS
    maxFps: 30,                 // Maximum FPS
    defaultMonitor: 0,          // Primary monitor
    captureAll: false           // Capture all monitors or single
  },

  // Image/Video Compression & Codecs
  compression: {
    codec: 'jpeg',              // Codec: 'jpeg', 'vp8', 'vp9', 'h264'
    format: 'jpeg',             // Legacy support
    quality: 70,                // Quality (1-100)
    minQuality: 40,             // Minimum quality for adaptive mode
    maxQuality: 90,             // Maximum quality
    
    // Codec-specific settings
    codecs: {
      jpeg: {
        quality: 70,
        chromaSubsampling: '4:2:0'
      },
      vp8: {
        bitrate: '1M',          // Target bitrate
        quality: 'good',        // 'best', 'good', 'realtime'
        deadline: 'realtime'
      },
      vp9: {
        bitrate: '800k',
        quality: 'good',
        deadline: 'realtime'
      },
      h264: {
        bitrate: '1M',
        preset: 'ultrafast',    // 'ultrafast', 'superfast', 'veryfast', 'faster', 'fast'
        tune: 'zerolatency'
      }
    },
    
    resize: {
      enabled: false,           // Enable resolution scaling
      width: 1280,              // Target width
      height: 720,              // Target height
      fit: 'inside'             // Scaling mode
    },
    
    // Adaptive streaming
    adaptive: {
      enabled: true,            // Enable adaptive quality/bitrate
      targetLatency: 100,       // Target latency in ms
      minBitrate: '500k',       // Minimum bitrate
      maxBitrate: '3M',         // Maximum bitrate
      adjustInterval: 2000      // How often to adjust (ms)
    }
  },

  // Performance & Network
  performance: {
    adaptiveQuality: true,      // Enable adaptive quality
    maxClients: 5,              // Maximum concurrent clients
    heartbeatInterval: 30000,   // Heartbeat interval (ms)
    connectionTimeout: 5000,    // Connection timeout (ms)
    
    // Network quality monitoring
    networkMonitoring: {
      enabled: true,            // Monitor network quality
      sampleInterval: 1000,     // Sample interval (ms)
      latencyThreshold: {
        good: 50,               // < 50ms = excellent
        fair: 150,              // < 150ms = good
        poor: 300               // < 300ms = fair, else poor
      },
      bandwidthTracking: true   // Track bandwidth usage
    },
    
    // Frame buffer settings
    frameBuffer: {
      enabled: true,            // Enable frame buffering
      maxSize: 3,               // Maximum frames to buffer
      dropOnOverflow: true      // Drop old frames if buffer full
    }
  },

  // Server Info
  server: {
    name: 'Screen Remote Server',
    version: '2.0.0',
    capabilities: [
      'screen_capture',
      'mouse_control',
      'keyboard_control',
      'multi_monitor',
      'multi_codec',          // NEW: Multiple codec support
      'adaptive_streaming',   // NEW: Adaptive quality/bitrate
      'network_monitoring'    // NEW: Network quality tracking
    ]
  }
};
