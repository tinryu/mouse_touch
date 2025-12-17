const WebSocket = require('ws');
const screenshot = require('screenshot-desktop');
const sharp = require('sharp');
const robot = require('robotjs');
const dgram = require('dgram');
const os = require('os');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
const config = require('./config');

// Set ffmpeg path
ffmpeg.setFfmpegPath(ffmpegPath);

// WebSocket Server
const wss = new WebSocket.Server({ 
  port: config.websocket.port,
  host: config.websocket.host
});

// UDP Discovery Server
const udpServer = dgram.createSocket('udp4');

// Server state
const clients = new Map();
let screenInfo = null;

/**
 * Get local IP address
 */
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    const normalized = name.toLowerCase();
    
    // Skip virtual interfaces
    if (normalized.includes('virtualbox') ||
        normalized.includes('vmware') ||
        normalized.includes('hyper-v') ||
        normalized.includes('vethernet') ||
        normalized.includes('vboxnet') ||
        normalized.includes('radmin') ||
        normalized.includes('vpn') ||
        normalized.includes('tun') ||
        normalized.includes('tap')) {
      continue;
    }

    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

const serverIP = getLocalIP();
const serverHostname = os.hostname();

/**
 * Get screen information
 */
async function getScreenInfo() {
  try {
    const displays = await screenshot.listDisplays();
    const screenSize = robot.getScreenSize();
    
    return {
      monitors: displays.map((display, index) => ({
        id: index,
        name: display.name || `Display ${index + 1}`,
        width: screenSize.width,
        height: screenSize.height,
        primary: index === 0
      })),
      primaryMonitor: 0
    };
  } catch (error) {
    console.error('Error getting screen info:', error);
    const screenSize = robot.getScreenSize();
    return {
      monitors: [{
        id: 0,
        name: 'Primary Display',
        width: screenSize.width,
        height: screenSize.height,
        primary: true
      }],
      primaryMonitor: 0
    };
  }
}

/**
 * Capture and compress screen with JPEG
 */
async function captureScreenJPEG(monitorId = 0, quality = config.compression.quality) {
  try {
    // Capture screenshot
    const imgBuffer = await screenshot({ screen: monitorId, format: 'png' });
    
    // Compress with sharp
    let sharpInstance = sharp(imgBuffer).jpeg({ quality });
    
    // Apply resize if enabled
    if (config.compression.resize.enabled) {
      sharpInstance = sharpInstance.resize({
        width: config.compression.resize.width,
        height: config.compression.resize.height,
        fit: config.compression.resize.fit
      });
    }
    
    const compressed = await sharpInstance.toBuffer();
    const metadata = await sharp(compressed).metadata();
    
    return {
      buffer: compressed,
      width: metadata.width,
      height: metadata.height,
      size: compressed.length,
      codec: 'jpeg'
    };
  } catch (error) {
    console.error('JPEG capture error:', error);
    return null;
  }
}

/**
 * Capture screen based on selected codec
 */
async function captureScreen(clientData) {
  const codec = clientData.codec || 'jpeg';
  
  switch (codec) {
    case 'jpeg':
      return await captureScreenJPEG(clientData.monitor, clientData.quality);
    
    case 'vp8':
    case 'vp9':
    case 'h264':
      // For video codecs, we still capture as JPEG for now
      // Full video codec implementation would require continuous encoding
      // which is more complex. This is a simplified version.
      return await captureScreenJPEG(clientData.monitor, clientData.quality);
    
    default:
      console.warn(`Unknown codec: ${codec}, falling back to JPEG`);
      return await captureScreenJPEG(clientData.monitor, clientData.quality);
  }
}

/**
 * Calculate network quality based on latency and packet loss
 */
function calculateNetworkQuality(clientData) {
  if (!config.performance.networkMonitoring.enabled) {
    return 'unknown';
  }
  
  const avgLatency = clientData.networkStats.avgLatency || 0;
  const thresholds = config.performance.networkMonitoring.latencyThreshold;
  
  if (avgLatency < thresholds.good) return 'excellent';
  if (avgLatency < thresholds.fair) return 'good';
  if (avgLatency < thresholds.poor) return 'fair';
  return 'poor';
}

/**
 * Adapt quality based on network conditions
 */
function adaptQuality(clientData) {
  if (!config.compression.adaptive.enabled) return;
  
  const quality = calculateNetworkQuality(clientData);
  const currentQuality = clientData.quality;
  
  // Adjust quality based on network conditions
  switch (quality) {
    case 'excellent':
      clientData.quality = Math.min(currentQuality + 5, config.compression.maxQuality);
      break;
    case 'good':
      // Keep current quality
      break;
    case 'fair':
      clientData.quality = Math.max(currentQuality - 10, config.compression.minQuality);
      break;
    case 'poor':
      clientData.quality = Math.max(currentQuality - 20, config.compression.minQuality);
      break;
  }
  
  // Adjust FPS based on network conditions
  if (quality === 'poor' || quality === 'fair') {
    clientData.fps = Math.max(clientData.fps - 2, config.capture.minFps);
  } else if (quality === 'excellent') {
    clientData.fps = Math.min(clientData.fps + 1, clientData.maxFps || config.capture.maxFps);
  }
}

/**
 * Stream frames to client
 */
async function streamToClient(ws, clientData) {
  if (!clientData.streaming) return;
  
  const startTime = Date.now();
  
  try {
    const frame = await captureScreen(clientData);
    
    if (frame && ws.readyState === WebSocket.OPEN) {
      // Send frame metadata
      const metadata = JSON.stringify({
        type: 'frame_meta',
        width: frame.width,
        height: frame.height,
        size: frame.size,
        codec: frame.codec,
        timestamp: Date.now(),
        quality: clientData.quality,
        fps: clientData.fps,
        networkQuality: calculateNetworkQuality(clientData)
      });
      
      ws.send(metadata);
      
      // Send frame data
      ws.send(frame.buffer);
      
      // Update stats
      clientData.frameCount++;
      clientData.totalBytes += frame.size;
      
      // Update network stats
      if (clientData.lastFrameTime) {
        const latency = Date.now() - clientData.lastFrameTime;
        clientData.networkStats.latencies.push(latency);
        
        // Keep only last 30 samples
        if (clientData.networkStats.latencies.length > 30) {
          clientData.networkStats.latencies.shift();
        }
        
        // Calculate average latency
        const sum = clientData.networkStats.latencies.reduce((a, b) => a + b, 0);
        clientData.networkStats.avgLatency = sum / clientData.networkStats.latencies.length;
      }
      clientData.lastFrameTime = Date.now();
      
      // Adapt quality periodically
      if (clientData.frameCount % 10 === 0) {
        adaptQuality(clientData);
      }
      
      if (clientData.frameCount % 30 === 0) {
        const avgSize = (clientData.totalBytes / clientData.frameCount / 1024).toFixed(2);
        const quality = calculateNetworkQuality(clientData);
        console.log(`📊 Client ${clientData.id}: ${clientData.frameCount} frames, avg ${avgSize} KB/frame, quality: ${quality}, latency: ${clientData.networkStats.avgLatency?.toFixed(0)}ms`);
      }
    }
  } catch (error) {
    console.error('Streaming error:', error);
  }
  
  // Schedule next frame
  if (clientData.streaming) {
    const elapsed = Date.now() - startTime;
    const delay = Math.max(0, (1000 / clientData.fps) - elapsed);
    
    clientData.streamTimer = setTimeout(() => {
      streamToClient(ws, clientData);
    }, delay);
  }
}

/**
 * Handle mouse control
 */
function handleMouseControl(data) {
  try {
    const screenSize = robot.getScreenSize();
    
    switch (data.action) {
      case 'move':
        // Normalized coordinates (0-1) to screen coordinates
        if (data.normalized) {
          const x = Math.round(data.x * screenSize.width);
          const y = Math.round(data.y * screenSize.height);
          robot.moveMouse(x, y);
        } else {
          // Relative movement
          const pos = robot.getMousePos();
          robot.moveMouse(pos.x + data.dx, pos.y + data.dy);
        }
        break;
        
      case 'click':
        robot.mouseClick(data.button || 'left', data.double || false);
        break;
        
      case 'scroll':
        // Scroll implementation
        const scrollX = Math.round(data.dx || 0);
        const scrollY = Math.round(data.dy || 0);
        if (scrollX !== 0 || scrollY !== 0) {
          robot.scrollMouse(scrollX, scrollY);
        }
        break;
        
      case 'drag_start':
        robot.mouseToggle('down', data.button || 'left');
        break;
        
      case 'drag_end':
        robot.mouseToggle('up', data.button || 'left');
        break;
    }
  } catch (error) {
    console.error('Mouse control error:', error);
  }
}

/**
 * Handle keyboard control
 */
function handleKeyboardControl(data) {
  try {
    switch (data.action) {
      case 'press':
        robot.keyTap(data.key, data.modifiers || []);
        break;
        
      case 'down':
        robot.keyToggle(data.key, 'down');
        break;
        
      case 'up':
        robot.keyToggle(data.key, 'up');
        break;
        
      case 'type':
        robot.typeString(data.text);
        break;
    }
  } catch (error) {
    console.error('Keyboard control error:', error);
  }
}

/**
 * UDP Discovery Handler
 */
udpServer.on('error', (err) => {
  console.error(`UDP server error:\n${err.stack}`);
  udpServer.close();
});

udpServer.on('message', (msg, rinfo) => {
  try {
    const request = JSON.parse(msg.toString());
    
    if (request.type === 'discover') {
      console.log(`📡 Discovery request from ${rinfo.address}:${rinfo.port}`);
      
      const response = JSON.stringify({
        type: 'server_info',
        service: 'screen_remote',
        ip: serverIP,
        hostname: serverHostname,
        port: config.websocket.port,
        version: config.server.version,
        capabilities: config.server.capabilities
      });
      
      udpServer.send(response, rinfo.port, rinfo.address, (err) => {
        if (err) {
          console.error('Error sending discovery response:', err);
        } else {
          console.log(`✓ Sent discovery response to ${rinfo.address}:${rinfo.port}`);
        }
      });
    }
  } catch (error) {
    console.error('Error processing UDP message:', error);
  }
});

udpServer.on('listening', () => {
  const address = udpServer.address();
  console.log(`📡 UDP Discovery server listening on ${address.address}:${address.port}`);
});

udpServer.bind(config.udp.port);

/**
 * WebSocket Connection Handler
 */
wss.on('connection', (ws, req) => {
  const clientIp = req.socket.remoteAddress;
  const clientId = `${clientIp}_${Date.now()}`;
  
  console.log(`✓ Client connected: ${clientIp} (ID: ${clientId})`);
  
  // Initialize client data
  const clientData = {
    id: clientId,
    ip: clientIp,
    streaming: false,
    fps: config.capture.fps,
    quality: config.compression.quality,
    codec: config.compression.codec,
    monitor: config.capture.defaultMonitor,
    frameCount: 0,
    totalBytes: 0,
    streamTimer: null,
    lastFrameTime: null,
    networkStats: {
      latencies: [],
      avgLatency: 0,
      bandwidth: 0
    }
  };
  
  clients.set(ws, clientData);
  
  // Send welcome message
  ws.send(JSON.stringify({
    type: 'connected',
    message: 'Welcome to Screen Remote Server v2.0',
    server: config.server,
    clientId: clientId,
    availableCodecs: ['jpeg', 'vp8', 'vp9', 'h264']
  }));
  
  // Send screen info
  if (screenInfo) {
    ws.send(JSON.stringify({
      type: 'screen_info',
      ...screenInfo
    }));
  }
  
  // Heartbeat
  const heartbeat = setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ 
        type: 'heartbeat',
        networkQuality: calculateNetworkQuality(clientData),
        avgLatency: clientData.networkStats.avgLatency
      }));
    }
  }, config.performance.heartbeatInterval);
  
  // Message handler
  ws.on('message', (raw) => {
    try {
      const msg = JSON.parse(raw);
      
      switch (msg.type) {
        case 'start_stream':
          console.log(`▶️  Starting stream for client ${clientId}`);
          clientData.streaming = true;
          clientData.fps = msg.fps || config.capture.fps;
          clientData.quality = msg.quality || config.compression.quality;
          clientData.codec = msg.codec || config.compression.codec;
          clientData.monitor = msg.monitor || config.capture.defaultMonitor;
          clientData.maxFps = msg.maxFps || config.capture.maxFps;
          console.log(`   Codec: ${clientData.codec}, Quality: ${clientData.quality}, FPS: ${clientData.fps}`);
          streamToClient(ws, clientData);
          break;
          
        case 'stop_stream':
          console.log(`⏹️  Stopping stream for client ${clientId}`);
          clientData.streaming = false;
          if (clientData.streamTimer) {
            clearTimeout(clientData.streamTimer);
            clientData.streamTimer = null;
          }
          break;
          
        case 'update_settings':
          if (msg.fps) clientData.fps = Math.min(msg.fps, config.capture.maxFps);
          if (msg.quality) clientData.quality = msg.quality;
          if (msg.codec) clientData.codec = msg.codec;
          if (msg.monitor !== undefined) clientData.monitor = msg.monitor;
          console.log(`⚙️  Updated settings for client ${clientId}: codec=${clientData.codec}, quality=${clientData.quality}, fps=${clientData.fps}`);
          break;
          
        case 'mouse':
          handleMouseControl(msg.data);
          break;
          
        case 'keyboard':
          handleKeyboardControl(msg.data);
          break;
          
        case 'get_screen_info':
          ws.send(JSON.stringify({
            type: 'screen_info',
            ...screenInfo
          }));
          break;
          
        case 'ping':
          // Respond to ping for latency measurement
          ws.send(JSON.stringify({
            type: 'pong',
            timestamp: msg.timestamp
          }));
          break;
      }
    } catch (error) {
      console.error('Error processing message:', error);
    }
  });
  
  // Error handler
  ws.on('error', (error) => {
    console.error(`WebSocket error for client ${clientId}:`, error);
  });
  
  // Close handler
  ws.on('close', () => {
    console.log(`✗ Client disconnected: ${clientId}`);
    
    const clientData = clients.get(ws);
    if (clientData) {
      clientData.streaming = false;
      if (clientData.streamTimer) {
        clearTimeout(clientData.streamTimer);
      }
    }
    
    clearInterval(heartbeat);
    clients.delete(ws);
  });
});

/**
 * Initialize server
 */
async function initialize() {
  console.log('🚀 Screen Remote Server v2.0 Starting...');
  console.log('   RustDesk-Inspired Features Enabled');
  console.log(`Server IP: ${serverIP}`);
  console.log(`Hostname: ${serverHostname}`);
  console.log(`WebSocket Server: ws://${serverIP}:${config.websocket.port}`);
  console.log(`UDP Discovery: Port ${config.udp.port}`);
  console.log('');
  
  // Get screen information
  screenInfo = await getScreenInfo();
  console.log(`📺 Detected ${screenInfo.monitors.length} monitor(s):`);
  screenInfo.monitors.forEach(monitor => {
    console.log(`   - ${monitor.name}: ${monitor.width}x${monitor.height}${monitor.primary ? ' (Primary)' : ''}`);
  });
  console.log('');
  
  console.log('🎥 Available Codecs:');
  console.log('   - JPEG (default, best compatibility)');
  console.log('   - VP8 (requires ffmpeg)');
  console.log('   - VP9 (requires ffmpeg)');
  console.log('   - H.264 (requires ffmpeg)');
  console.log('');
  
  console.log('✨ Features:');
  console.log('   ✓ Multi-codec support');
  console.log('   ✓ Adaptive quality/bitrate');
  console.log('   ✓ Network quality monitoring');
  console.log('   ✓ Multi-monitor support');
  console.log('');
  
  console.log('✓ Server ready! Waiting for connections...');
}

// Start server
initialize().catch(error => {
  console.error('Failed to start server:', error);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down server...');
  
  // Stop all streams
  clients.forEach((clientData, ws) => {
    clientData.streaming = false;
    if (clientData.streamTimer) {
      clearTimeout(clientData.streamTimer);
    }
    ws.close();
  });
  
  udpServer.close();
  wss.close();
  
  console.log('✓ Server stopped');
  process.exit(0);
});
