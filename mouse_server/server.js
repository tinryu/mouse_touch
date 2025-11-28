const WebSocket = require('ws');
const robot = require('robotjs');
const dgram = require('dgram');
const os = require('os');

const wss = new WebSocket.Server({ port: 8989 });
const udpServer = dgram.createSocket('udp4');

// Get local IP address
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    const normalized  = name.toLowerCase();
    if(normalized.includes('virtualbox') ||
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
      // Skip internal and non-IPv4 addresses
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

const serverIP = getLocalIP();
const serverHostname = os.hostname();

// UDP Discovery Server (Port 8988)
udpServer.on('error', (err) => {
  console.error(`UDP server error:\n${err.stack}`);
  udpServer.close();
});

udpServer.on('message', (msg, rinfo) => {
  try {
    const request = JSON.parse(msg.toString());
    
    if (request.type === 'discover') {
      console.log(`📡 Discovery request from ${rinfo.address}:${rinfo.port}`);
      
      // Send server information back to the client
      const response = JSON.stringify({
        type: 'server_info',
        ip: serverIP,
        hostname: serverHostname,
        port: 8989,
        version: '1.0.0'
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

udpServer.bind(8988);

console.log("Touchpad server running ws://0.0.0.0:8989");
console.log(`Server IP: ${serverIP}`);
console.log(`Hostname: ${serverHostname}`);
console.log("Waiting for connections...");

wss.on('connection', (ws, req) => {
  const clientIp = req.socket.remoteAddress;
  console.log(`✓ Phone connected from ${clientIp}`);

  // Send welcome message to confirm connection
  ws.send(JSON.stringify({ type: "connected", message: "Welcome to Touchpad Server" }));

  // Send heartbeat every 30 seconds to keep connection alive
  const heartbeat = setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: "heartbeat" }));
    }
  }, 30000);

  ws.on('message', raw => {
    try {
      const msg = JSON.parse(raw);
      if (msg.type === "click") {
        robot.mouseClick(msg.button);
      }
      if (msg.type === "move") {
        const pos = robot.getMousePos();
        robot.moveMouseSmooth(pos.x + msg.dx, pos.y + msg.dy, 0.1);
      }

      if (msg.type === "scroll") {
        // Real touchpad-like scrolling using Windows API
        if (!ws.scrollAccumX) ws.scrollAccumX = 0;
        if (!ws.scrollAccumY) ws.scrollAccumY = 0;
        
        // Sensitivity multiplier (adjust for scroll speed)
        const sensitivity = 30; // Windows WHEEL_DELTA is 120, so we scale up
        
        // Accumulate scroll deltas
        ws.scrollAccumX += msg.dx * sensitivity;
        ws.scrollAccumY += -msg.dy * sensitivity; // Negative for natural scroll
        
        // Windows expects scroll in multiples of WHEEL_DELTA (120)
        // We'll send scroll events when accumulated value is significant
        const threshold = 30; // Lower = more sensitive
        
        // Vertical scrolling
        if (Math.abs(ws.scrollAccumY) >= threshold) {
          const scrollAmount = Math.round(ws.scrollAccumY);
          
          // Use PowerShell to call Windows API for native mouse wheel
          const { exec } = require('child_process');
          exec(`powershell -ExecutionPolicy Bypass -File "${__dirname}/scroll.ps1" -delta ${scrollAmount}`, 
            (error) => {
              if (error) {
                console.error('Scroll error:', error.message);
              }
            }
          );
          
          ws.scrollAccumY = 0; // Reset after sending
        }
        
        // Horizontal scrolling (if needed in future)
        if (Math.abs(ws.scrollAccumX) >= threshold) {
          ws.scrollAccumX = 0; // Reset for now
        }
      }

      if (msg.type === "zoom") {
        // 3-finger zoom like real touchpad
        // Use Ctrl + Mouse Wheel for zoom (standard Windows zoom)
        if (!ws.zoomAccum) ws.zoomAccum = 0;
        
        // Accumulate zoom delta
        const zoomSensitivity = 200; // Adjust for zoom speed
        ws.zoomAccum += msg.delta * zoomSensitivity;
        
        const zoomThreshold = 50;
        
        if (Math.abs(ws.zoomAccum) >= zoomThreshold) {
          const zoomAmount = Math.round(ws.zoomAccum);
          
          // Simulate Ctrl + Mouse Wheel for zoom
          robot.keyToggle('control', 'down');
          
          // Use PowerShell for smooth zoom
          const { exec } = require('child_process');
          exec(`powershell -ExecutionPolicy Bypass -File "${__dirname}/scroll.ps1" -delta ${zoomAmount}`, 
            (error) => {
              if (error) {
                console.error('Zoom error:', error.message);
              }
              // Release Ctrl key after zoom
              robot.keyToggle('control', 'up');
            }
          );
          
          ws.zoomAccum = 0;
          console.log(`Zoom: ${zoomAmount > 0 ? 'in' : 'out'}`);
        }
      }
    } catch (error) {
      console.error("Error parsing message:", error);
    }
  });

  ws.on('error', (error) => {
    console.error("WebSocket error:", error);
  });

  ws.on('close', () => {
    console.log(`✗ Phone disconnected from ${clientIp}`);
    clearInterval(heartbeat);
  });
});
