# Screen Remote Server

A Node.js server that captures the desktop screen and streams it to remote clients via WebSocket. Includes remote mouse and keyboard control capabilities.

## Features

- 📺 Real-time screen capture and streaming
- 🖱️ Remote mouse control (move, click, scroll)
- ⌨️ Remote keyboard control
- 🔍 UDP server discovery
- 📊 Adaptive quality and frame rate
- 🖥️ Multi-monitor support
- 🔄 Auto-reconnection support

## Requirements

- Node.js 14.x or higher
- Windows, macOS, or Linux

## Installation

```bash
cd remote_server
npm install
```

## Usage

### Start the server

```bash
npm start
```

The server will:
- Start WebSocket server on port **9090**
- Start UDP discovery service on port **9091**
- Display server IP and screen information

### Configuration

Edit `config.js` to customize:
- Frame rate (FPS)
- Image quality
- Resolution scaling
- Port numbers
- Performance settings

## Protocol

### Client → Server Messages

**Start Streaming:**
```json
{
  "type": "start_stream",
  "fps": 10,
  "quality": 70,
  "monitor": 0
}
```

**Stop Streaming:**
```json
{
  "type": "stop_stream"
}
```

**Mouse Control:**
```json
{
  "type": "mouse",
  "data": {
    "action": "move",
    "x": 0.5,
    "y": 0.5,
    "normalized": true
  }
}
```

**Keyboard Control:**
```json
{
  "type": "keyboard",
  "data": {
    "action": "press",
    "key": "a",
    "modifiers": ["ctrl"]
  }
}
```

### Server → Client Messages

**Frame Metadata:**
```json
{
  "type": "frame_meta",
  "width": 1920,
  "height": 1080,
  "size": 102400,
  "timestamp": 1234567890
}
```

**Frame Data:**
Binary JPEG image data (sent immediately after metadata)

**Screen Info:**
```json
{
  "type": "screen_info",
  "monitors": [
    {
      "id": 0,
      "name": "Primary Display",
      "width": 1920,
      "height": 1080,
      "primary": true
    }
  ]
}
```

## Performance Tips

- **Low bandwidth**: Set FPS to 5-8, quality to 50-60
- **Balanced**: Set FPS to 10-15, quality to 70-80
- **High quality**: Set FPS to 20-30, quality to 80-90

## Troubleshooting

### Server won't start
- Check if ports 9090/9091 are available
- Ensure Node.js is installed correctly
- Run `npm install` to install dependencies

### Screen capture fails
- On Linux, may need X11 permissions
- On macOS, grant screen recording permissions
- Check `screenshot-desktop` compatibility

### High CPU usage
- Reduce frame rate (FPS)
- Lower image quality
- Enable resolution scaling in config

## License

MIT
